#!/bin/bash
# Diagnostic script to check Python package installation inside running container
# Run: docker exec <container_id_or_name> python /tmp/diagnose_imports.py

import sys
import subprocess

print("=" * 60)
print("Python Package Diagnostic Script")
print("=" * 60)
print(f"Python version: {sys.version}")
print(f"Python executable: {sys.executable}")
print()

# List of critical packages to check
critical_packages = [
    'pandas',
    'numpy',
    'plotly',
    'Django',
    'django-extensions',
    'djangorestframework',
    'gunicorn',
    'prometheus_client',
]

print("Checking installed packages...")
print()

# Check if pip list includes them
result = subprocess.run(['pip', 'list'], capture_output=True, text=True)
installed = result.stdout

for pkg in critical_packages:
    if pkg.lower() in installed.lower():
        print(f"✓ {pkg}: INSTALLED")
    else:
        print(f"✗ {pkg}: NOT FOUND in pip list")

print()
print("=" * 60)
print("Attempting imports...")
print("=" * 60)
print()

imports_to_test = {
    'numpy': 'import numpy as np',
    'pandas': 'import pandas as pd',
    'plotly.express': 'import plotly.express as px',
    'Django': 'import django',
    'django_extensions': 'import django_extensions',
    'rest_framework': 'import rest_framework',
    'gunicorn': 'import gunicorn',
    'prometheus_client': 'from prometheus_client import Counter',
}

failed_imports = []

for name, import_stmt in imports_to_test.items():
    try:
        exec(import_stmt)
        print(f"✓ {name}: OK")
    except ImportError as e:
        print(f"✗ {name}: FAILED - {e}")
        failed_imports.append((name, str(e)))
    except Exception as e:
        print(f"⚠ {name}: ERROR - {e}")

print()
print("=" * 60)

if failed_imports:
    print(f"SUMMARY: {len(failed_imports)} import(s) failed:")
    for name, error in failed_imports:
        print(f"  - {name}: {error}")
    print()
    print("RECOMMENDED FIX:")
    print("  1. Check pip list output above")
    print("  2. If package missing, rebuild Docker image with:")
    print("     docker build --no-cache -t your_image:latest .")
    print("  3. Verify requirements.txt has all packages")
    sys.exit(1)
else:
    print("✓ All imports successful!")
    sys.exit(0)
