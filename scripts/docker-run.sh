#!/usr/bin/env bash
set -euo pipefail

echo "--- Starting MuchTodo App with Docker Compose ---"
docker compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 5

echo ""
echo "Container status:"
docker compose ps

echo ""
echo "Application is running!"
echo "  Health check : http://localhost:8080/health"
echo "  Users API    : http://localhost:8080/users"
echo ""
echo "To view logs: docker compose logs -f"
echo "To stop     : docker compose down"
