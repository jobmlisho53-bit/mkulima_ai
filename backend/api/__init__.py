"""
Mkulima AI API Package
Contains all API endpoints organized by functionality
"""

from flask import Blueprint
from flask_restx import Api

# Create blueprint for API
api_bp = Blueprint('api', __name__, url_prefix='/api')

# Initialize API with documentation
api = Api(
    api_bp,
    version='1.0',
    title='Mkulima AI API',
    description='AI-Powered Plant Disease Detection API',
    doc='/docs',
    authorizations={
        'Bearer Auth': {
            'type': 'apiKey',
            'in': 'header',
            'name': 'Authorization',
            'description': 'Type in the value field: Bearer {your JWT token}'
        }
    },
    security='Bearer Auth'
)

# Import namespaces (will be created in separate files)
# from .disease_ns import disease_ns
# from .farmer_ns import farmer_ns
# from .analytics_ns import analytics_ns

# Register namespaces
# api.add_namespace(disease_ns, path='/disease')
# api.add_namespace(farmer_ns, path='/farmer')
# api.add_namespace(analytics_ns, path='/analytics')

__all__ = ['api_bp', 'api']
