"""
Mkulima AI Database Models Package
Contains all SQLAlchemy models for the application
"""

from .database import db
from .disease_report import DiseaseReport
from .farmer_profile import FarmerProfile
from .treatment_recommendation import TreatmentRecommendation
from .outbreak_alert import OutbreakAlert

__all__ = [
    'db',
    'DiseaseReport',
    'FarmerProfile',
    'TreatmentRecommendation',
    'OutbreakAlert'
]
