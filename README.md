# Safe Her Travel 🛡️

A modern women's safety application featuring SOS alerts, safe accommodation discovery, AI-powered safety companion, and community-driven travel reviews — focused on Tamil Nadu, India.

[![CI](https://github.com/YOUR_USERNAME/SAFEHER/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/SAFEHER/actions/workflows/ci.yml)

## 🏗️ Architecture

| Component | Technology | Directory |
|-----------|-----------|-----------|
| Mobile App | Flutter (Dart) | `mobile/` |
| Web App | Next.js 15 + React 19 | `src/` |
| Backend API | Flask + Supabase PostgreSQL | `backend/` |

---

## 🚀 Getting Started

### Prerequisites
- Python 3.10+ & pip
- Node.js 18+ & npm
- Flutter SDK 3.0+
- (Optional) Docker & Docker Compose

### 1. Backend Setup

```bash
cd backend

# Create a virtual environment (recommended)
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
cp .env.example .env
# Edit .env with your actual Supabase URL, API keys, etc.

# Initialize the database (run schema.sql in the Supabase SQL Editor)

# Start the server
python app.py
```

> 💡 **Supabase Auto-Wake**: On the free tier, Supabase pauses after inactivity. The backend now **automatically wakes** your Supabase project on startup. Set `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` in your `.env` to enable this.

### 2. Mobile App Setup

```bash
cd mobile

# Find your computer's IP
ipconfig                     # Windows
# ifconfig | grep inet       # macOS/Linux

# Run the app
flutter run --dart-define=API_URL=http://YOUR_IP:5000/api
```

### 3. Web App Setup

```bash
# From project root
npm install
npm run dev
```

---

## 🐳 Docker

```bash
# Start the backend in a container
docker compose up --build

# Stop
docker compose down

# View logs
docker compose logs -f backend
```

---

## 🧪 Testing

```bash
cd backend

# Run all tests
python -m pytest tests/ -v

# Run with coverage report
python -m pytest tests/ -v --cov=. --cov-report=term-missing

# Run linting
flake8 . --max-line-length=120 --exclude=__pycache__,venv,.venv
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `backend/app.py` | Flask app entry point with auto-wake |
| `backend/database/db.py` | Supabase PostgreSQL connection |
| `backend/database/schema.sql` | Database schema (run in Supabase SQL Editor) |
| `backend/services/supabase_wake.py` | Auto-wakes paused Supabase projects |
| `backend/.env.example` | Environment variable template |
| `mobile/lib/main.dart` | Flutter app entry point |
| `.github/workflows/ci.yml` | CI pipeline (lint → test → Docker build) |

---

## 🔐 Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in:

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | ✅ | Supabase PostgreSQL connection string |
| `SECRET_KEY` | ✅ | Flask secret key |
| `JWT_SECRET_KEY` | ✅ | JWT signing key |
| `GEMINI_API_KEY` | ✅ | Google Gemini AI API key |
| `SUPABASE_ACCESS_TOKEN` | Optional | Enables auto-wake for free tier |
| `SUPABASE_PROJECT_REF` | Optional | Your Supabase project reference ID |
| `TWILIO_ACCOUNT_SID` | Optional | SMS alerts via Twilio |

---

## 📜 License

Licensed under the [Apache License 2.0](LICENSE).
