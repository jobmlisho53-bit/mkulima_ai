"""
Mkulima AI Utilities Package
Contains helper functions and utilities
"""

from .validators import (
    validate_image_file,
    validate_farmer_data,
    validate_location,
    validate_prediction_data
)

from .formatters import (
    format_prediction_response,
    format_treatment_plan,
    format_voice_message,
    format_date
)

from .security import (
    encrypt_data,
    decrypt_data,
    generate_api_key,
    validate_api_key,
    hash_password,
    verify_password
)

from .geo_utils import (
    get_location_from_coords,
    calculate_distance,
    get_nearest_extension_officer,
    get_weather_for_location
)

from .file_utils import (
    save_image,
    delete_image,
    compress_image,
    generate_image_hash,
    create_thumbnail
)

__all__ = [
    # Validators
    'validate_image_file',
    'validate_farmer_data',
    'validate_location',
    'validate_prediction_data',
    
    # Formatters
    'format_prediction_response',
    'format_treatment_plan',
    'format_voice_message',
    'format_date',
    
    # Security
    'encrypt_data',
    'decrypt_data',
    'generate_api_key',
    'validate_api_key',
    'hash_password',
    'verify_password',
    
    # Geo utilities
    'get_location_from_coords',
    'calculate_distance',
    'get_nearest_extension_officer',
    'get_weather_for_location',
    
    # File utilities
    'save_image',
    'delete_image',
    'compress_image',
    'generate_image_hash',
    'create_thumbnail'
]
