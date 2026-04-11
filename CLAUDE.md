# CLAUDE.md

## Project Overview

**For Sale By Owner (FSBO)** - A full-stack platform enabling property sellers to list and sell properties without estate agents.

- **Backend:** Django 5.2 + Django REST Framework, PostgreSQL, Redis, Celery
- **Mobile:** Flutter (Dart) cross-platform app (iOS & Android)
- **Web:** Django templates for server-rendered pages
- **Domain:** for-sale-by-owner.co.uk

## Feature Parity (CRITICAL)

**All features must exist on both the web app and the mobile app.** Any new feature or bug fix must be implemented in both the Django web app (templates/views) and the Flutter mobile app (`my_app/`). Do not ship a change to one platform without the equivalent change on the other — the two clients must stay in lockstep in terms of functionality.

## Repository Structure

```
fsbo_backend/       # Django project config (settings, URLs, WSGI/ASGI, middleware)
api/                # Main Django app (models, views, serializers, admin, tasks, tests)
my_app/             # Flutter mobile app
  lib/
    constants/      # API endpoints, theme, legal text
    models/         # Dart data models
    screens/        # UI screens
    services/       # API and auth services
    utils/          # Utility functions
    widgets/        # Reusable widgets
templates/          # Django HTML templates
scripts/            # Setup and deployment scripts
static/             # Static assets (CSS, JS, images)
```

## Quick Start

### Backend (local dev)
```bash
bash scripts/setup.sh
source venv/bin/activate
USE_SQLITE=True python manage.py migrate
USE_SQLITE=True python manage.py runserver
```

### Docker
```bash
docker compose up --build
# Access at http://localhost:8000
```

### Flutter
```bash
cd my_app
flutter pub get
flutter run
```

## Common Commands

| Task | Command |
|------|---------|
| Run tests | `USE_SQLITE=True python manage.py test api --verbosity=2` |
| Check migrations | `USE_SQLITE=True python manage.py makemigrations --check --dry-run` |
| Create migrations | `USE_SQLITE=True python manage.py makemigrations` |
| Apply migrations | `USE_SQLITE=True python manage.py migrate` |
| Create superuser | `USE_SQLITE=True python manage.py createsuperuser` |
| Seed data | `USE_SQLITE=True python manage.py seed_services` |
| Flutter analyze | `cd my_app && flutter analyze` |
| Flutter build | `cd my_app && flutter build appbundle --release` |

## Testing

- **Framework:** Django's built-in `TestCase` (not pytest)
- **Test files:** `api/tests.py`, `api/tests_comprehensive.py`
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) runs on push to main/master and all PRs
- **CI checks:** Tests with verbosity=2, migration safety (`makemigrations --check --dry-run`)
- **Python version:** 3.11
- **Test helpers:** `make_user()`, `make_property()`, `auth_client()` in test files
- **Celery in tests:** Tasks run synchronously in SQLite mode (eager mode)

Always run tests before pushing:
```bash
USE_SQLITE=True python manage.py test api --verbosity=2
```

## Architecture & Key Patterns

### Authentication
- **Djoser** token-based auth with email login (no username)
- Custom user model with email as `USERNAME_FIELD`
- Endpoints: `/auth/token/login/`, `/auth/users/`, `/auth/users/me/`
- 2FA support (TOTP-based)

### API Design
- REST API via Django REST Framework with `TokenAuthentication`
- ViewSets for standard CRUD, nested ViewSets for related resources
- `@api_view` decorators for custom endpoints
- Pagination: 20 items/page (page number-based)
- Throttling: 1000 req/hr (user), 200 req/hr (anonymous)

### Key API Routes
- `/api/properties/` - Property CRUD
- `/api/properties/{id}/images/`, `/floorplans/`, `/documents/` - Media
- `/api/properties/{id}/viewing-slots/` - Viewings
- `/api/saved/`, `/api/saved-searches/` - Buyer features
- `/api/chat-rooms/` - Messaging
- `/api/offers/` - Formal offers
- `/api/service-providers/`, `/api/service-categories/` - Services
- `/api/subscriptions/`, `/api/stripe/webhook/` - Payments

### Data Models (40+ models in `api/models.py`)
- **Property** with status flow: draft -> pending_review -> active -> under_offer -> sold_stc -> sold
- **Viewing** flow: pending -> confirmed -> completed
- **Offer** flow: submitted -> accepted/rejected/withdrawn -> completed
- Properties support both integer ID and slug-based URLs (auto-generated, unique)

### Real-Time
- Django Channels for WebSocket support (chat/messaging)
- Redis channel layer in production, in-memory in dev

### Background Tasks
- Celery + Redis for async emails, push notifications, saved search alerts
- Runs synchronously in SQLite/test mode

### Payments
- Stripe integration for service provider subscriptions
- Webhook handling for payment events

## Database

- **Production:** PostgreSQL 15
- **Local dev:** SQLite (set `USE_SQLITE=True`)
- **Cache:** Redis in production, in-memory in dev

## Production Server

The app runs on a shared Hetzner server (`178.104.29.66`, hostname `Luma001`) that hosts multiple apps. Caddy reverse-proxies traffic to each app by domain.

```bash
# SSH access
ssh -i ~/.ssh/hetzner_key root@178.104.29.66

# Caddy config: ~/caddy/Caddyfile
# - paws4thoughtdogs.com       → 172.17.0.1:8000 (another app)
# - for-sale-by-owner.co.uk    → 172.17.0.1:8002 (this app)
```

**Important:** This is a shared server. Port 8000 is taken by another app. This app runs on **port 8002**. Be careful not to disrupt other services when deploying or modifying Docker/Caddy config.

## Deployment

### Production (Docker Compose)
```bash
# On server
cd /root/for-sale-by-owner && git pull && bash deploy.sh
# deploy.sh: migrates, collectstatic, restarts docker services (port 8002)
```

Services: web (Gunicorn), db (PostgreSQL), redis, celery, celery-beat

### Static Files
- Served via WhiteNoise (no separate nginx)
- Collected at build: `python manage.py collectstatic`

### CI/CD
- **Backend CI:** GitHub Actions on push/PR - tests + migration check
- **Android deploy:** GitHub Actions on push to `my_app/` on main/development
  - main -> Play Store production, development -> alpha track

## Code Conventions

### Python/Django
- Follow PEP 8 style
- Models in `api/models.py`, views in `api/views.py`, serializers in `api/serializers.py`
- Custom exception handler in `api/exception_handler.py`
- Celery tasks in `api/tasks.py`
- Management commands in `api/management/commands/`
- Use `RelativeImageField` for media URLs (avoids mixed-content behind proxy)
- Timezone: `Europe/London`

### Flutter/Dart
- State management via Provider
- Auth tokens in `flutter_secure_storage`
- Icons: Phosphor Flutter (Duotone style)
- Typography: Google Fonts
- API base URL toggled in `lib/constants/api_constants.dart`

### Git Workflow
- `main` branch: production
- `development` branch: staging/alpha
- Feature branches for new work
- No pre-commit hooks configured

## Version Bumping

The app version must be bumped for every code change. Update the version in `my_app/pubspec.yaml` (e.g. `version: 1.0.8+10` — increment the build number `+N` for every change, bump the semantic version for releases).

## Environment Variables

Key variables (see `.env` file):
- `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS` - Django core
- `USE_SQLITE=True` - Use SQLite instead of PostgreSQL
- `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` - PostgreSQL
- `REDIS_URL`, `CELERY_BROKER_URL` - Redis/Celery
- `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET` - Payments
- `EMAIL_HOST`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` - SMTP
- `FCM_CREDENTIALS_FILE` - Firebase push notifications

## Gotchas

1. **Always prefix local commands with `USE_SQLITE=True`** when not using Docker
2. **www redirect middleware** automatically redirects www to canonical domain
3. **Image processing:** Pillow auto-resizes to 1920x1080 max, thumbnails at 400x300
4. **CSRF:** Cookie must be set on initial page view (via `CSRFTemplateView`)
5. **Channels import:** Guarded with try/except in settings (optional dependency)
6. **Firebase credentials** required for push notifications to function
7. **Flutter API toggle:** Remember to switch endpoints in `api_constants.dart` for local vs production
