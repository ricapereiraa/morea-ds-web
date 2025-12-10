#!/bin/sh
set -e

# If a .env file exists, ensure dotenv is used by settings.py (project already loads dotenv)

# Ensure static, staticfiles and media directories exist and have correct permissions
echo "Setting up directories..."
mkdir -p /app/static /app/staticfiles /app/media
chmod -R 755 /app/static /app/staticfiles /app/media 2>/dev/null || true

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
# Collect static files - this is critical for the frontend to work
python manage.py collectstatic --noinput --clear || {
    echo "ERROR: collectstatic failed! Frontend may not render correctly."
    echo "Attempting to continue anyway..."
}

echo "Starting Gunicorn..."
exec gunicorn morea_ds.wsgi:application --bind 0.0.0.0:8000 --workers 3
