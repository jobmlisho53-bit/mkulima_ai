"""
Mkulima AI Flask Backend
AI-Powered Plant Disease Detection System
"""

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import os
from datetime import datetime
import json

# Import custom modules
from services.image_processor import ImageProcessor
from services.disease_predictor import DiseasePredictor
from utils.validators import validate_image_file
from models.database import db, DiseaseReport

app = Flask(__name__)
CORS(app)  # Enable CORS for mobile app

# Configuration
app.config.from_pyfile('config.py')
db.init_app(app)

# Initialize services
image_processor = ImageProcessor()
disease_predictor = DiseasePredictor()

@app.route('/')
def home():
    """API Home endpoint"""
    return jsonify({
        "status": "success",
        "message": "Mkulima AI Backend API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "predict": "/api/predict (POST)",
            "history": "/api/history",
            "treatment": "/api/treatment/<disease_name>"
        }
    })

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "services": {
            "ml_model": disease_predictor.is_ready(),
            "database": True,
            "image_processing": True
        }
    })

@app.route('/api/predict', methods=['POST'])
def predict_disease():
    """
    Predict plant disease from uploaded image
    Expected: multipart/form-data with 'image' file
    """
    try:
        # Validate request
        if 'image' not in request.files:
            return jsonify({"error": "No image file provided"}), 400
        
        image_file = request.files['image']
        
        # Validate image
        validation_result = validate_image_file(image_file)
        if not validation_result['valid']:
            return jsonify({"error": validation_result['message']}), 400
        
        # Optional parameters
        crop_type = request.form.get('crop_type', 'general')
        location = request.form.get('location', '')
        farmer_id = request.form.get('farmer_id', '')
        
        # Process image
        processed_image = image_processor.preprocess(image_file)
        
        # Predict disease
        prediction = disease_predictor.predict(processed_image)
        
        # Save to database if farmer_id provided
        if farmer_id:
            report = DiseaseReport(
                farmer_id=farmer_id,
                crop_type=crop_type,
                location=location,
                prediction=prediction,
                confidence=prediction['confidence'],
                image_path=f"uploads/{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.jpg"
            )
            db.session.add(report)
            db.session.commit()
            prediction['report_id'] = report.id
        
        return jsonify({
            "status": "success",
            "prediction": prediction,
            "timestamp": datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/treatment/<disease_name>', methods=['GET'])
def get_treatment(disease_name):
    """Get treatment recommendations for a specific disease"""
    try:
        treatment_info = disease_predictor.get_treatment_info(disease_name)
        
        if not treatment_info:
            return jsonify({"error": "Treatment information not found"}), 404
        
        return jsonify({
            "status": "success",
            "disease": disease_name,
            "treatment": treatment_info
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/history', methods=['GET'])
def get_history():
    """Get prediction history for a farmer"""
    farmer_id = request.args.get('farmer_id')
    if not farmer_id:
        return jsonify({"error": "farmer_id parameter required"}), 400
    
    try:
        reports = DiseaseReport.query.filter_by(farmer_id=farmer_id)\
            .order_by(DiseaseReport.created_at.desc())\
            .limit(20)\
            .all()
        
        history = [{
            "id": report.id,
            "crop_type": report.crop_type,
            "disease": report.prediction.get('disease_name'),
            "confidence": report.confidence,
            "location": report.location,
            "timestamp": report.created_at.isoformat(),
            "recommendations": report.prediction.get('recommendations', [])
        } for report in reports]
        
        return jsonify({
            "status": "success",
            "farmer_id": farmer_id,
            "history": history,
            "count": len(history)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/analytics/outbreaks', methods=['GET'])
def outbreak_analytics():
    """Get disease outbreak analytics for monitoring"""
    try:
        # This would typically connect to a data analytics service
        outbreaks = {
            "timestamp": datetime.utcnow().isoformat(),
            "alerts": [
                {"region": "Central", "disease": "Late Blight", "severity": "high", "cases": 45},
                {"region": "Rift Valley", "disease": "Maize Lethal Necrosis", "severity": "medium", "cases": 28},
                {"region": "Western", "disease": "Coffee Berry Disease", "severity": "low", "cases": 12}
            ],
            "trends": {
                "total_cases": 385,
                "most_common_disease": "Tomato Yellow Leaf Curl Virus",
                "emerging_threat": "Fall Armyworm"
            }
        }
        
        return jsonify({
            "status": "success",
            "analytics": outbreaks
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Create uploads directory if it doesn't exist
    os.makedirs('uploads', exist_ok=True)
    
    # Run the app
    app.run(
        host=app.config.get('HOST', '0.0.0.0'),
        port=app.config.get('PORT', 5000),
        debug=app.config.get('DEBUG', False)
    )
