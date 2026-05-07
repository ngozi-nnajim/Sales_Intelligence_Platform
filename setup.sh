#!/usr/bin/env bash

# ── Setup script ─────────────────────────────────────────────
# Runs schema creation and data loading in one command.
# Usage: bash setup.sh
# ─────────────────────────────────────────────────────────────


# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

echo "Starting setup..."

# Check CSV files exist before proceeding
if [ ! -d "data/oltp" ] || [ ! -d "data/olap" ]; then
    echo "Error: outputs folder not found. Please run the notebook first to generate CSV files."
    exit 1
fi

# Create database schema
echo "Creating schema..."
psql -U $DB_USER -d $DB_NAME -f schema.sql

# Load data into database
echo "Loading data..."
python load_to_db.py

echo "Setup complete."