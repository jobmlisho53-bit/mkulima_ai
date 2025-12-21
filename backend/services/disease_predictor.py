"""
Disease Predictor Service
Handles ML model inference for plant disease detection
"""

import tensorflow as tf
import numpy as np
import json
import os
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

class DiseasePredictor:
    """Service for plant disease prediction using TensorFlow Lite"""
    
    def __init__(self, model_path: str = None, labels_path: str = None):
        """
        Initialize the disease predictor
        
        Args:
            model_path: Path to TensorFlow Lite model
            labels_path: Path to labels file
        """
        self.model = None
        self.labels = []
        self.model_path = model_path
        self.labels_path = labels_path
        
        if model_path and labels_path:
            self.load_model(model_path, labels_path)
    
    def load_model(self, model_path: str, labels_path: str):
        """
        Load TensorFlow Lite model and labels
        
        Args:
            model_path: Path to .tflite model file
            labels_path: Path to labels.txt file
        """
        try:
            # Load model
            self.model = tf.lite.Interpreter(model_path=model_path)
            self.model.allocate_tensors()
            
            # Load labels
            with open(labels_path, 'r') as f:
                self.labels = [line.strip() for line in f.readlines()]
            
            # Get model details
            input_details = self.model.get_input_details()
            output_details = self.model.get_output_details()
            
            self.input_shape = input_details[0]['shape']
            self.output_shape = output_details[0]['shape']
            
            logger.info(f"Model loaded successfully: {model_path}")
            logger.info(f"Input shape: {self.input_shape}")
            logger.info(f"Output shape: {self.output_shape}")
            logger.info(f"Labels loaded: {len(self.labels)}")
            
        except Exception as e:
            logger.error(f"Failed to load model: {str(e)}")
            raise
    
    def preprocess_image(self, image: np.ndarray) -> np.ndarray:
        """
        Preprocess image for model input
        
        Args:
            image: Input image array
            
        Returns:
            Preprocessed image array
        """
        # Resize to model input size
        input_height, input_width = self.input_shape[1:3]
        resized = tf.image.resize(image, [input_height, input_width])
        
        # Normalize to [0, 1]
        normalized = resized / 255.0
        
        # Convert to float32
        processed = normalized.astype(np.float32)
        
        # Add batch dimension
        processed = np.expand_dims(processed, axis=0)
        
        return processed
    
    def predict(self, image: np.ndarray) -> Dict:
        """
        Predict disease from image
        
        Args:
            image: Preprocessed image array
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not loaded. Call load_model() first.")
        
        try:
            # Preprocess image
            processed_image = self.preprocess_image(image)
            
            # Set input tensor
            input_details = self.model.get_input_details()
            self.model.set_tensor(input_details[0]['index'], processed_image)
            
            # Run inference
            self.model.invoke()
            
            # Get output tensor
            output_details = self.model.get_output_details()
            predictions = self.model.get_tensor(output_details[0]['index'])
            
            # Get top prediction
            top_index = np.argmax(predictions[0])
            confidence = float(predictions[0][top_index])
            disease_name = self.labels[top_index]
            
            # Get top 3 predictions
            top_indices = np.argsort(predictions[0])[-3:][::-1]
            top_predictions = [
                {
                    'disease': self.labels[i],
                    'confidence': float(predictions[0][i]),
                    'rank': rank + 1
                }
                for rank, i in enumerate(top_indices)
            ]
            
            # Determine severity
            severity = self.estimate_severity(image, disease_name, confidence)
            
            # Get treatment recommendations
            recommendations = self.get_treatment_recommendations(disease_name)
            
            # Get similar images for reference
            similar_cases = self.find_similar_cases(disease_name)
            
            return {
                'disease_name': disease_name,
                'confidence': confidence,
                'severity': severity,
                'top_predictions': top_predictions,
                'recommendations': recommendations,
                'similar_cases': similar_cases,
                'timestamp': tf.timestamp().numpy()
            }
            
        except Exception as e:
            logger.error(f"Prediction failed: {str(e)}")
            raise
    
    def estimate_severity(self, image: np.ndarray, disease: str, confidence: float) -> Dict:
        """
        Estimate disease severity
        
        Args:
            image: Input image
            disease: Disease name
            confidence: Prediction confidence
            
        Returns:
            Severity information
        """
        # This is a simplified version
        # In practice, you might use a segmentation model (U-Net) for this
        
        severity_level = 'low'
        if confidence > 0.8:
            severity_level = 'high'
        elif confidence > 0.6:
            severity_level = 'medium'
        
        # Calculate affected area percentage (simplified)
        # In real implementation, use segmentation
        affected_area = min(confidence * 100, 95)  # Simplified
        
        return {
            'level': severity_level,
            'affected_area_percentage': affected_area,
            'description': self.get_severity_description(severity_level),
            'action_required': severity_level in ['medium', 'high']
        }
    
    def get_severity_description(self, level: str) -> str:
        """Get description for severity level"""
        descriptions = {
            'low': 'Early stage infection. Monitor regularly.',
            'medium': 'Moderate infection. Treatment recommended.',
            'high': 'Severe infection. Immediate treatment required.'
        }
        return descriptions.get(level, 'Unknown severity level.')
    
    def get_treatment_recommendations(self, disease: str) -> List[Dict]:
        """
        Get treatment recommendations for a disease
        
        Args:
            disease: Disease name
            
        Returns:
            List of treatment recommendations
        """
        # This would typically come from a database or external API
        # For now, return sample data
        
        treatments_db = {
            'tomato_early_blight': [
                {
                    'type': 'chemical',
                    'name': 'Chlorothalonil',
                    'dosage': 'Apply 1-2 lbs per acre',
                    'frequency': 'Every 7-10 days',
                    'safety': 'Wear protective equipment',
                    'organic_alternative': 'Copper-based fungicides'
                },
                {
                    'type': 'cultural',
                    'name': 'Crop rotation',
                    'description': 'Rotate with non-solanaceous crops',
                    'effectiveness': 'High'
                }
            ],
            'maize_rust': [
                {
                    'type': 'chemical',
                    'name': 'Triazole fungicides',
                    'dosage': 'Apply as per manufacturer instructions',
                    'frequency': 'At first sign of disease',
                    'safety': 'Follow label instructions'
                }
            ]
        }
        
        # Return treatments for the disease or general advice
        if disease in treatments_db:
            return treatments_db[disease]
        else:
            return [{
                'type': 'general',
                'name': 'Consult agricultural expert',
                'description': f'No specific treatment found for {disease}. Please consult local agricultural extension officer.',
                'contact': 'Call 0111-222-333 for expert advice'
            }]
    
    def find_similar_cases(self, disease: str, limit: int = 5) -> List[Dict]:
        """
        Find similar historical cases
        
        Args:
            disease: Disease name
            limit: Maximum number of cases to return
            
        Returns:
            List of similar cases
        """
        # In production, this would query a database
        # For now, return sample data
        return [
            {
                'case_id': 'case_001',
                'location': 'Central Province',
                'date': '2023-10-15',
                'severity': 'medium',
                'treatment_applied': 'Copper fungicide',
                'outcome': 'Recovered'
            },
            {
                'case_id': 'case_002',
                'location': 'Rift Valley',
                'date': '2023-09-22',
                'severity': 'high',
                'treatment_applied': 'Systemic fungicide',
                'outcome': 'Partial recovery'
            }
        ]
    
    def is_ready(self) -> bool:
        """Check if model is loaded and ready"""
        return self.model is not None and len(self.labels) > 0
