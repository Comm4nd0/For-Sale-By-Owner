# For Sale By Owner

Sell your property without an estate agent. Django backend with REST API + Flutter mobile app.

**Domain:** for-sale-by-owner.co.uk
**Server:** 178.104.29.66:8002

## Tech Stack

- **Backend:** Django 5.2, Django REST Framework, PostgreSQL
- **Auth:** Djoser (token-based, email login)
- **Mobile:** Flutter (iOS & Android)
- **Deployment:** Docker, Gunicorn, WhiteNoise

## Quick Start (Local Development)

```bash
# Option 1: Using setup script
bash scripts/setup.sh

# Then run:
source venv/bin/activate
USE_SQLITE=True python manage.py runserver

# Option 2: Using Docker
docker compose up --build
```

The site will be at http://localhost:8000

## Server Deployment

```bash
# On the server, clone to /root:
git clone https://github.com/Comm4nd0/For-Sale-By-Owner.git /root/for-sale-by-owner
cd /root/for-sale-by-owner
bash scripts/setup-server.sh

# Create admin user:
docker compose -f docker-compose.prod.yml exec web python manage.py createsuperuser

# Redeploy after changes:
cd /root/for-sale-by-owner && git pull && docker compose -f docker-compose.prod.yml up -d --build
```

## Flutter App

The Flutter app is in `my_app/`. Before first run, generate platform directories:

```bash
cd my_app
flutter create --org com.forsalebyowner .
flutter run
```

Toggle between local and production API in `lib/constants/api_constants.dart`.

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/api/properties/` | List/create properties |
| `/api/properties/{id}/` | Property detail |
| `/auth/token/login/` | Login (returns token) |
| `/auth/token/logout/` | Logout |
| `/auth/users/` | Register |
| `/auth/users/me/` | Current user |
| `/admin/` | Django admin |

## Project Structure

```
├── fsbo_backend/     # Django project config
├── api/              # REST API app (models, views, serializers)
├── templates/        # Web frontend templates
├── my_app/           # Flutter mobile app
├── scripts/          # Setup & deploy scripts
├── Dockerfile        # Multi-stage Docker build
├── docker-compose.yml        # Local dev
└── docker-compose.prod.yml   # Production (port 8002)
```
