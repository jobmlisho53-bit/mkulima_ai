"""
Validation utilities for Mkulima AI
"""

import magic
from PIL import Image
import io
import re
from typing import Dict, Tuple
import logging

logger = logging.getLogger(__name__)

# Allowed image formats
ALLOWED_MIME_TYPES = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/bmp',
    'image/webp'
}

ALLOWED_EXTENSIONS = {
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'
}

# Phone number regex for Kenya
KENYA_PHONE_REGEX = r'^(?:\+254|0)[17]\d{8}$'

def validate_image_file(image_file) -> Dict[str, bool]:
    """
    Validate uploaded image file
    
    Args:
        image_file: File object from request
        
    Returns:
        Dictionary with validation result
    """
    try:
        # Check if file exists
        if not image_file or image_file.filename == '':
            return {
                'valid': False,
                'message': 'No image file selected'
            }
        
        # Check file extension
        filename = image_file.filename.lower()
        if not any(filename.endswith(ext) for ext in ALLOWED_EXTENSIONS):
            return {
                'valid': False,
                'message': f'File type not allowed. Allowed types: {", ".join(ALLOWED_EXTENSIONS)}'
            }
        
        # Read file content for MIME type validation
        file_content = image_file.read()
        image_file.seek(0)  # Reset file pointer
        
        # Check MIME type
        mime_type = magic.from_buffer(file_content[:2048], mime=True)
        if mime_type not in ALLOWED_MIME_TYPES:
            return {
                'valid': False,
                'message': f'Invalid file type: {mime_type}'
            }
        
        # Verify it's a valid image by trying to open it
        try:
            image = Image.open(io.BytesIO(file_content))
            image.verify()  # Verify it's a valid image
            
            # Check image dimensions
            width, height = image.size
            if width < 100 or height < 100:
                return {
                    'valid': False,
                    'message': 'Image too small. Minimum size: 100x100 pixels'
                }
            
            if width > 5000 or height > 5000:
                return {
                    'valid': False,
                    'message': 'Image too large. Maximum size: 5000x5000 pixels'
                }
            
            # Check file size (16MB max)
            image_file.seek(0, 2)  # Seek to end
            file_size = image_file.tell()
            image_file.seek(0)  # Reset to beginning
            
            if file_size > 16 * 1024 * 1024:  # 16MB
                return {
                    'valid': False,
                    'message': 'File too large. Maximum size: 16MB'
                }
            
            return {
                'valid': True,
                'message': 'Image file is valid',
                'mime_type': mime_type,
                'dimensions': (width, height),
                'file_size': file_size
            }
            
        except Exception as e:
            return {
                'valid': False,
                'message': f'Invalid image file: {str(e)}'
            }
            
    except Exception as e:
        logger.error(f"Image validation error: {str(e)}")
        return {
            'valid': False,
            'message': f'Validation error: {str(e)}'
        }

def validate_farmer_data(farmer_data: Dict) -> Tuple[bool, str]:
    """
    Validate farmer registration/update data
    
    Args:
        farmer_data: Dictionary containing farmer information
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        # Check required fields
        required_fields = ['name', 'phone_number', 'county']
        for field in required_fields:
            if field not in farmer_data or not farmer_data[field]:
                return False, f'Missing required field: {field}'
        
        # Validate phone number
        phone = str(farmer_data['phone_number']).strip()
        if not re.match(KENYA_PHONE_REGEX, phone):
            return False, 'Invalid Kenyan phone number format. Use format: +2547XXXXXXXX or 07XXXXXXXX'
        
        # Validate email if provided
        if 'email' in farmer_data and farmer_data['email']:
            email = farmer_data['email'].strip()
            if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
                return False, 'Invalid email address format'
        
        # Validate location data
        if 'location' in farmer_data:
            location = farmer_data['location']
            if not isinstance(location, dict):
                return False, 'Location must be a dictionary'
            
            if 'county' not in location:
                return False, 'Location must include county'
        
        # Validate crop types
        if 'crops' in farmer_data:
            crops = farmer_data['crops']
            if not isinstance(crops, list):
                return False, 'Crops must be a list'
            
            # Check each crop has required fields
            for crop in crops:
                if not isinstance(crop, dict):
                    return False, 'Each crop must be a dictionary'
                if 'name' not in crop:
                    return False, 'Crop must have a name'
        
        return True, 'Farmer data is valid'
        
    except Exception as e:
        logger.error(f"Farmer data validation error: {str(e)}")
        return False, f'Validation error: {str(e)}'

def validate_location(location_data: Dict) -> Tuple[bool, str]:
    """
    Validate location data
    
    Args:
        location_data: Dictionary containing location information
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        # Check required fields
        if 'latitude' not in location_data or 'longitude' not in location_data:
            return False, 'Location must include latitude and longitude'
        
        lat = location_data['latitude']
        lon = location_data['longitude']
        
        # Validate latitude range (-90 to 90)
        if not isinstance(lat, (int, float)) or lat < -90 or lat > 90:
            return False, 'Latitude must be between -90 and 90'
        
        # Validate longitude range (-180 to 180)
        if not isinstance(lon, (int, float)) or lon < -180 or lon > 180:
            return False, 'Longitude must be between -180 and 180'
        
        # Validate county if provided
        if 'county' in location_data and location_data['county']:
            county = str(location_data['county']).strip()
            if len(county) < 2:
                return False, 'County name too short'
        
        return True, 'Location data is valid'
        
    except Exception as e:
        logger.error(f"Location validation error: {str(e)}")
        return False, f'Validation error: {str(e)}'

def validate_prediction_data(prediction_data: Dict) -> Tuple[bool, str]:
    """
    Validate prediction data
    
    Args:
        prediction_data: Dictionary containing prediction information
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        # Check required fields
        required_fields = ['disease_name', 'confidence', 'crop_type']
        for field in required_fields:
            if field not in prediction_data:
                return False, f'Missing required field: {field}'
        
        # Validate confidence (0-1)
        confidence = prediction_data['confidence']
        if not isinstance(confidence, (int, float)) or confidence < 0 or confidence > 1:
            return False, 'Confidence must be a number between 0 and 1'
        
        # Validate crop type
        crop_type = prediction_data['crop_type']
        if not isinstance(crop_type, str) or len(crop_type.strip()) < 2:
            return False, 'Crop type must be a valid string'
        
        # Validate disease name
        disease_name = prediction_data['disease_name']
        if not isinstance(disease_name, str) or len(disease_name.strip()) < 2:
            return False, 'Disease name must be a valid string'
        
        # Validate severity if provided
        if 'severity' in prediction_data:
            severity = prediction_data['severity']
            valid_severity_levels = ['low', 'medium', 'high', 'critical']
            if severity not in valid_severity_levels:
                return False, f'Severity must be one of: {", ".join(valid_severity_levels)}'
        
        return True, 'Prediction data is valid'
        
    except Exception as e:
        logger.error(f"Prediction data validation error: {str(e)}")
        return False, f'Validation error: {str(e)}'

def validate_phone_number(phone: str) -> bool:
    """
    Validate Kenyan phone number
    
    Args:
        phone: Phone number string
        
    Returns:
        True if valid, False otherwise
    """
    if not isinstance(phone, str):
        return False
    
    phone = phone.strip()
    
    # Remove any spaces or dashes
    phone = re.sub(r'[\s\-]', '', phone)
    
    # Check if matches Kenyan phone pattern
    return bool(re.match(KENYA_PHONE_REGEX, phone))

def validate_email(email: str) -> bool:
    """
    Validate email address
    
    Args:
        email: Email address string
        
    Returns:
        True if valid, False otherwise
    """
    if not isinstance(email, str):
        return False
    
    email = email.strip()
    
    # Simple email validation regex
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))

def validate_crop_name(crop_name: str) -> Tuple[bool, str]:
    """
    Validate crop name
    
    Args:
        crop_name: Crop name string
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    if not isinstance(crop_name, str):
        return False, 'Crop name must be a string'
    
    crop_name = crop_name.strip()
    
    if len(crop_name) < 2:
        return False, 'Crop name too short'
    
    if len(crop_name) > 100:
        return False, 'Crop name too long'
    
    # Check for invalid characters
    if re.search(r'[^\w\s\-]', crop_name):
        return False, 'Crop name contains invalid characters'
    
    return True, 'Crop name is valid'

