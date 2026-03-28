#!/bin/bash
# Deploy script for For Sale By Owner
# Usage: ./deploy.sh

set -e

echo "🔄 Pulling latest code..."
git pull

echo "📦 Building Docker image (installs pip dependencies)..."
docker compose -f docker-compose.prod.yml build --no-cache

echo "🚀 Restarting services..."
docker compose -f docker-compose.prod.yml up -d

echo "⏳ Waiting for services to be ready..."
sleep 5

echo "🗄️  Running database migrations..."
docker compose -f docker-compose.prod.yml exec -T web python manage.py migrate --noinput

echo "📋 Verifying installed packages..."
docker compose -f docker-compose.prod.yml exec -T web pip list --format=columns

echo ""
echo "✅ Deploy complete!"
echo ""
docker compose -f docker-compose.prod.yml ps
