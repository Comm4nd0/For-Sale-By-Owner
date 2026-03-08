#!/bin/bash
# Deploy script for For Sale By Owner
# Usage: ./deploy.sh

set -e

echo "🔄 Pulling latest code..."
git pull

echo "🔨 Building Docker image..."
docker compose -f docker-compose.prod.yml build

echo "🚀 Restarting services..."
docker compose -f docker-compose.prod.yml up -d

echo "✅ Deploy complete!"
echo ""
docker compose -f docker-compose.prod.yml ps
