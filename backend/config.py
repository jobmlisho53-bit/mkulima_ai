"""
Mkulima AI Configuration Settings
"""

import os
from datetime import timedelta

# Base directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Flask Configuration
DEBUG = True
SECRET_KEY = os.environ.get('SECRET_KEY', 'mkulima-ai-secret-key-dev-2024')

# Database Configuration
SQLALCHEMY_DATABASE_URI = os.environ.get(
    'DATABASE_URL',
    f'sqlite:///{os.path.join(BASE_DIR, "mkulima_ai.db")}'
)
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_ECHO = DEBUG

# File Upload Configuration
MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max file size
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')

# ML Model Configuration
MODEL_PATH = os.path.join(BASE_DIR, '../ml_model/models/plant_disease_model.tflite')
LABELS_PATH = os.path.join(BASE_DIR, '../ml_model/models/labels.txt')

# API Configuration
API_PREFIX = '/api'
API_VERSION = 'v1'

# CORS Configuration
CORS_ORIGINS = [
    'http://localhost:3000',
    'http://localhost:5000',
    'capacitor://localhost',
    'ionic://localhost'
]

# JWT Configuration (if implementing authentication)
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-mkulima-ai')
JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=24)
JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

# Redis Configuration (for caching)
REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
CACHE_TIMEOUT = 300  # 5 minutes

# External API Keys
WEATHER_API_KEY = os.environ.get('WEATHER_API_KEY', '')
GOOGLE_MAPS_API_KEY = os.environ.get('GOOGLE_MAPS_API_KEY', '')

# Logging Configuration
LOG_LEVEL = 'DEBUG' if DEBUG else 'INFO'
LOG_FILE = os.path.join(BASE_DIR, 'logs/mkulima_ai.log')

# Email Configuration
MAIL_SERVER = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
MAIL_PORT = int(os.environ.get('MAIL_PORT', 587))
MAIL_USE_TLS = os.environ.get('MAIL_USE_TLS', 'True').lower() == 'true'
MAIL_USERNAME = os.environ.get('MAIL_USERNAME', '')
MAIL_PASSWORD = os.environ.get('MAIL_PASSWORD', '')
MAIL_DEFAULT_SENDER = os.environ.get('MAIL_DEFAULT_SENDER', 'noreply@mkulima-ai.ke')

# Monitoring
ENABLE_METRICS = True
METRICS_PORT = 9090

# Feature Flags
ENABLE_OFFLINE_MODE = True
ENABLE_VOICE_OUTPUT = True
ENABLE_SEVERITY_ESTIMATION = True
