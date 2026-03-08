#!/bin/bash
# Local development setup for For Sale By Owner
set -e

echo "=== For Sale By Owner: Local Setup ==="
echo ""

# Backend setup
echo "1. Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "2. Installing Python dependencies..."
pip install -r requirements.txt

# Environment file
if [ ! -f .env ]; then
    cp .env.example .env
    echo "3. Created .env from .env.example — update with your settings."
else
    echo "3. .env already exists, skipping."
fi

# Run migrations (using SQLite for local dev)
echo "4. Running database migrations..."
USE_SQLITE=True python manage.py makemigrations
USE_SQLITE=True python manage.py migrate

# Create superuser
echo ""
echo "5. Creating admin superuser..."
USE_SQLITE=True python manage.py createsuperuser

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To start the dev server:"
echo "  source venv/bin/activate"
echo "  USE_SQLITE=True python manage.py runserver"
echo ""
echo "Or use Docker:"
echo "  docker compose up --build"
echo ""
echo "To start the Flutter app:"
echo "  cd my_app && flutter run"
