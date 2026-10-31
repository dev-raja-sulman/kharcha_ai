#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status
set -o errexit

echo "Installing production dependencies from requirements.txt..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Running Alembic migrations against target database..."
alembic upgrade head

echo "Build and migrations completed successfully!"
