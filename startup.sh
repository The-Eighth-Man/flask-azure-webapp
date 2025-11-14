#!/bin/bash
# Startup script for Azure App Service

echo "Starting Flask application..."

# Run database migrations if needed
python -c "from app import db; db.create_all()" || true

# Start Gunicorn
gunicorn --bind=0.0.0.0:8000 --timeout 600 --workers 4 app:app
