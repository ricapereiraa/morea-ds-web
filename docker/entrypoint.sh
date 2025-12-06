#!/bin/sh
set -e

# If a .env file exists, ensure dotenv is used by settings.py (project already loads dotenv)

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting Gunicorn..."
exec gunicorn morea_ds.wsgi:application --bind 0.0.0.0:8000 --workers 3
