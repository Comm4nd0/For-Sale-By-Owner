#!/bin/bash
# Production deployment script for For Sale By Owner
# Run this on the server after cloning the repo
set -e

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_IP="178.104.29.66"

echo "=== For Sale By Owner: Server Deployment ==="
echo "App directory: $APP_DIR"
echo ""

# 1. Check Docker
echo "1. Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "   ERROR: Docker not found. Please install Docker first."
    exit 1
fi
echo "   Docker is available."

# 2. Create .env if missing
echo ""
echo "2. Setting up environment..."
if [ ! -f "$APP_DIR/.env" ]; then
    SECRET_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 50)
    DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

    cat > "$APP_DIR/.env" << EOF
# Django
SECRET_KEY=$SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=$SERVER_IP,localhost,127.0.0.1,for-sale-by-owner.co.uk

# Database
DB_NAME=fsbo_properties
DB_USER=fsbo_user
DB_PASSWORD=$DB_PASSWORD
DB_HOST=db
DB_PORT=5432

# CORS
CORS_ALLOW_ALL_ORIGINS=False
CORS_ALLOWED_ORIGINS=http://$SERVER_IP:8002,https://for-sale-by-owner.co.uk
EOF
    echo "   .env created with generated secrets."
else
    echo "   .env already exists, skipping."
fi

# 3. Build and start
echo ""
echo "3. Building and starting services..."
cd "$APP_DIR"
docker compose -f docker-compose.prod.yml up -d --build

echo "   Waiting for services to start..."
sleep 10

# 4. Verify
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Services:"
docker compose -f docker-compose.prod.yml ps
echo ""
echo "Site: http://$SERVER_IP:8002"
echo "Admin: http://$SERVER_IP:8002/admin/"
echo "API: http://$SERVER_IP:8002/api/"
echo ""
echo "Next steps:"
echo "  1. Create a superuser:"
echo "     cd $APP_DIR"
echo "     docker compose -f docker-compose.prod.yml exec web python manage.py createsuperuser"
echo ""
echo "  2. To redeploy after changes:"
echo "     cd $APP_DIR && git pull && docker compose -f docker-compose.prod.yml up -d --build"
