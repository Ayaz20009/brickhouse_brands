#!/bin/bash

# Wrapper script to run the Python load test
# This script activates the database virtual environment and runs the load test

cd "$(dirname "$0")"

echo "🚀 Starting Lakebase Load Test..."
echo ""

# Activate the database virtual environment where psycopg2 is installed
source ../database/venv/bin/activate

# Run the load test
python load_test.py

# Deactivate virtual environment
deactivate

