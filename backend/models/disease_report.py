"""
Disease Report Model
Stores predictions made by the AI system
"""

from .database import BaseModel, db
import json

class DiseaseReport(BaseModel):
    """Model for storing disease prediction reports"""
    __tablename__ = 'disease_reports'
    
    farmer_id = db.Column(db.String(100), nullable=False, index=True)
    crop_type = db.Column(db.String(50), nullable=False)
    location = db.Column(db.String(200))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    
    # Prediction results
    prediction = db.Column(db.Text, nullable=False)  # JSON string
    confidence = db.Column(db.Float, nullable=False)
    severity_level = db.Column(db.String(20))  # low, medium, high
    disease_name = db.Column(db.String(100))
    
    # Image information
    image_path = db.Column(db.String(500))
    image_hash = db.Column(db.String(64), unique=True)  # For duplicate detection
    
    # Treatment
    treatment_applied = db.Column(db.Boolean, default=False)
    treatment_date = db.Column(db.DateTime)
    treatment_notes = db.Column(db.Text)
    
    # Follow-up
    requires_follow_up = db.Column(db.Boolean, default=False)
    follow_up_date = db.Column(db.DateTime)
    follow_up_notes = db.Column(db.Text)
    
    # Metadata
    device_info = db.Column(db.String(200))
    app_version = db.Column(db.String(20))
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if 'prediction' and isinstance(self.prediction, dict):
            self.prediction = json.dumps(self.prediction)
            # Extract disease name from prediction if not provided
            if not self.disease_name and 'disease_name' in self.prediction_dict:
                self.disease_name = self.prediction_dict['disease_name']
    
    @property
    def prediction_dict(self):
        """Get prediction as dictionary"""
        try:
            return json.loads(self.prediction)
        except (json.JSONDecodeError, TypeError):
            return {}
    
    @prediction_dict.setter
    def prediction_dict(self, value):
        """Set prediction from dictionary"""
        self.prediction = json.dumps(value)
    
    def to_dict(self):
        """Convert to dictionary with prediction parsed"""
        data = super().to_dict()
        data['prediction'] = self.prediction_dict
        return data
