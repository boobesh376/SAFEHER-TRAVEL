"""
Supabase Auto-Wake Service
Automatically restores a paused Supabase project (free-tier) on backend startup.
Uses the Supabase Management API v1.
"""

import os
import time
import logging
import requests as http_requests
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

SUPABASE_MGMT_BASE = "https://api.supabase.com/v1"


def _get_config():
    """Read Supabase Management API config from environment."""
    token = os.getenv("SUPABASE_ACCESS_TOKEN", "").strip()
    ref = os.getenv("SUPABASE_PROJECT_REF", "").strip()
    return token, ref


def _headers(token: str) -> dict:
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def get_project_status(token: str, ref: str) -> str:
    """
    Check the current status of the Supabase project.
    Returns: 'ACTIVE_HEALTHY', 'INACTIVE', 'COMING_UP', etc.
    """
    try:
        resp = http_requests.get(
            f"{SUPABASE_MGMT_BASE}/projects/{ref}",
            headers=_headers(token),
            timeout=15,
        )
        if resp.status_code == 200:
            status = resp.json().get("status", "UNKNOWN")
            return status
        else:
            logger.warning("Supabase status check failed (%s): %s", resp.status_code, resp.text[:200])
            return "UNKNOWN"
    except Exception as e:
        logger.warning("Could not check Supabase status: %s", e)
        return "UNKNOWN"


def restore_project(token: str, ref: str) -> bool:
    """
    Send a restore request to wake up a paused Supabase project.
    Returns True if the request was accepted.
    """
    try:
        resp = http_requests.post(
            f"{SUPABASE_MGMT_BASE}/projects/{ref}/restore",
            headers=_headers(token),
            timeout=30,
        )
        if resp.status_code in (200, 201):
            logger.info("✅ Supabase restore request accepted.")
            return True
        else:
            logger.error("Supabase restore failed (%s): %s", resp.status_code, resp.text[:200])
            return False
    except Exception as e:
        logger.error("Supabase restore request error: %s", e)
        return False


def wait_until_active(token: str, ref: str, timeout_seconds: int = 120) -> bool:
    """
    Poll until the project status becomes ACTIVE_HEALTHY or timeout.
    """
    start = time.time()
    while (time.time() - start) < timeout_seconds:
        status = get_project_status(token, ref)
        if status == "ACTIVE_HEALTHY":
            return True
        logger.info("⏳ Supabase status: %s — waiting...", status)
        time.sleep(5)
    return False


def ensure_supabase_awake():
    """
    Main entry point. Call this on app startup.
    - If Supabase is active → do nothing
    - If paused → auto-restore and wait
    - If credentials are missing → skip silently (manual mode)
    """
    token, ref = _get_config()

    if not token or not ref:
        logger.info(
            "ℹ️  Supabase auto-wake skipped (SUPABASE_ACCESS_TOKEN or SUPABASE_PROJECT_REF not set). "
            "Set them in .env to enable automatic wake-up."
        )
        return True  # Don't block startup

    logger.info("🔍 Checking Supabase project status...")
    status = get_project_status(token, ref)

    if status == "ACTIVE_HEALTHY":
        logger.info("✅ Supabase is already active.")
        return True

    if status in ("INACTIVE", "PAUSED"):
        logger.info("💤 Supabase project is paused. Sending restore request...")
        if not restore_project(token, ref):
            logger.error("❌ Could not restore Supabase. Please wake it manually from the dashboard.")
            return False

        logger.info("⏳ Waiting for Supabase to come online (up to 2 minutes)...")
        if wait_until_active(token, ref):
            logger.info("🚀 Supabase is now active and ready!")
            return True
        else:
            logger.error("❌ Supabase did not come online within 2 minutes. Check dashboard.")
            return False

    # COMING_UP or other transitional states
    if status in ("COMING_UP", "RESTORING"):
        logger.info("⏳ Supabase is already waking up. Waiting...")
        if wait_until_active(token, ref):
            logger.info("🚀 Supabase is now active!")
            return True

    logger.warning("⚠️  Supabase status is '%s'. Proceeding anyway...", status)
    return True
