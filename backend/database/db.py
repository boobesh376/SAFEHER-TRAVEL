"""
Database Module – Supabase PostgreSQL via psycopg2
Uses the Session Pooler URL (permanent, never changes even after pause/wake).

How to get your permanent Pooler URL:
  1. Go to Supabase Dashboard → Project → Settings → Database
  2. Click "Connection Pooling" (Session mode)
  3. Copy the URI — it looks like:
     postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.co:5432/postgres
  4. Paste it as DATABASE_URL in your .env file
  5. You will NEVER need to change this again.
"""

import os
import time
import logging
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Retry settings for when Supabase is waking up
MAX_RETRIES = 3
INITIAL_BACKOFF_SECONDS = 2


def get_db_connection(retries=MAX_RETRIES):
    """
    Open and return a psycopg2 connection to Supabase PostgreSQL.

    Uses the Session Pooler URL which is permanent and stable.
    Includes automatic retry with exponential backoff so the app
    gracefully waits if Supabase is still waking up from a pause.

    Cursor factory is RealDictCursor so rows behave like dicts.
    """
    load_dotenv(override=True)
    db_url = os.getenv('DATABASE_URL')
    if not db_url:
        raise RuntimeError(
            "DATABASE_URL is not set. Add it to your .env file.\n"
            "Use the SESSION POOLER URL (not Direct Connection) from:\n"
            "  Supabase Dashboard → Settings → Database → Connection Pooling → Session mode\n"
            "Example: postgresql://postgres.REF:PASSWORD@aws-0-REGION.pooler.supabase.co:5432/postgres"
        )

    last_error = None
    for attempt in range(1, retries + 1):
        try:
            conn = psycopg2.connect(
                db_url,
                cursor_factory=psycopg2.extras.RealDictCursor,
                connect_timeout=15,
                sslmode='require',
            )
            if attempt > 1:
                logger.info("✅ Database connected on attempt %d", attempt)
            return conn

        except psycopg2.OperationalError as e:
            last_error = e
            if attempt < retries:
                wait = INITIAL_BACKOFF_SECONDS * (2 ** (attempt - 1))  # 2s, 4s, 8s
                logger.warning(
                    "⏳ DB connection attempt %d/%d failed (%s). "
                    "Retrying in %ds (Supabase may be waking up)...",
                    attempt, retries, str(e)[:80], wait,
                )
                time.sleep(wait)
            else:
                logger.error(
                    "❌ All %d DB connection attempts failed. Last error: %s",
                    retries, e,
                )

        except psycopg2.Error as e:
            logger.error("Database connection failed: %s", e)
            raise

    raise psycopg2.OperationalError(
        f"Could not connect after {retries} attempts. "
        f"Last error: {last_error}\n"
        "Tip: Make sure you're using the Session Pooler URL, not the Direct Connection."
    )


def close_connection(conn):
    """Safely close a database connection."""
    try:
        if conn and not conn.closed:
            conn.close()
    except Exception as e:
        logger.warning("Error closing DB connection: %s", e)