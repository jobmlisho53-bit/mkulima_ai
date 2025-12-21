#!/bin/bash

# Mkulima AI Backend Server Runner
# This script starts the Flask backend server with proper configuration

set -e

echo "========================================="
echo "Mkulima AI Backend Server"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -d "backend" ]]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check if virtual environment exists
if [[ ! -d "venv" ]]; then
    print_warning "Virtual environment not found. Creating one..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r backend/requirements.txt
else
    source venv/bin/activate
fi

# Check if requirements are installed
print_message "Checking dependencies..."
pip install -r backend/requirements.txt

# Create necessary directories
print_message "Creating necessary directories..."
mkdir -p backend/uploads
mkdir -p backend/logs
mkdir -p backend/static
mkdir -p backend/templates

# Check if database exists, create if not
print_message "Checking database..."
cd backend
if [[ ! -f "mkulima_ai.db" ]]; then
    print_message "Creating database..."
    python -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Database created successfully')
"
fi
cd ..

# Set environment variables
print_message "Setting up environment..."
export FLASK_APP=backend/app.py
export FLASK_ENV=development
export PYTHONPATH=$PYTHONPATH:$(pwd)

# Check if .env file exists
if [[ -f "backend/.env" ]]; then
    print_message "Loading environment variables from .env file..."
    export $(grep -v '^#' backend/.env | xargs)
else
    print_warning ".env file not found. Using default configuration."
    print_warning "Create backend/.env file for custom configuration."
fi

# Check if port is already in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        return 0
    else
        return 1
    fi
}

# Find available port
PORT=${PORT:-5000}
MAX_PORT=5010

while check_port $PORT && [ $PORT -le $MAX_PORT ]; do
    print_warning "Port $PORT is already in use. Trying port $((PORT + 1))..."
    PORT=$((PORT + 1))
done

if [ $PORT -gt $MAX_PORT ]; then
    print_error "Could not find an available port between 5000 and $MAX_PORT"
    exit 1
fi

export PORT=$PORT

# Check for model files
print_message "Checking ML model files..."
if [[ ! -f "ml_model/models/plant_disease_model.tflite" ]]; then
    print_warning "ML model not found. Using mock predictions."
    print_warning "To use real predictions, train the model first:"
    print_warning "  cd ml_model && python training_scripts/train_model.py"
    export USE_MOCK_PREDICTIONS=true
else
    export USE_MOCK_PREDICTIONS=false
fi

# Clear old log files
print_message "Clearing old logs..."
> backend/logs/mkulima_ai.log

# Run database migrations if Alembic is set up
if [[ -f "backend/migrations/env.py" ]]; then
    print_message "Running database migrations..."
    cd backend
    flask db upgrade
    cd ..
fi

# Start the server
print_message "Starting Flask server on port $PORT..."
echo "========================================="
echo "Server URL: http://localhost:$PORT"
echo "API Documentation: http://localhost:$PORT/api/docs"
echo "Health Check: http://localhost:$PORT/health"
echo "========================================="
echo ""
print_message "Press Ctrl+C to stop the server"
echo ""

# Run the Flask server
cd backend

# Check if gunicorn is available for production
if [[ "$1" == "--production" ]] && command -v gunicorn &> /dev/null; then
    print_message "Starting production server with gunicorn..."
    gunicorn --bind 0.0.0.0:$PORT \
             --workers 4 \
             --timeout 120 \
             --log-level info \
             --access-logfile logs/access.log \
             --error-logfile logs/error.log \
             app:app
else
    if [[ "$1" == "--production" ]]; then
        print_warning "gunicorn not found. Falling back to development server."
    fi
    
    print_message "Starting development server..."
    python app.py
fi

cd ..
