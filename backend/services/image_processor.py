"""
Image Processor Service
Handles image preprocessing and enhancement
"""

import cv2
import numpy as np
from PIL import Image, ImageEnhance
import io
from typing import Tuple, Optional
import logging

logger = logging.getLogger(__name__)

class ImageProcessor:
    """Service for image preprocessing and enhancement"""
    
    def __init__(self):
        self.default_size = (224, 224)  # Common input size for MobileNet
    
    def preprocess(self, image_file) -> np.ndarray:
        """
        Preprocess image file for ML model
        
        Args:
            image_file: Uploaded image file
            
        Returns:
            Preprocessed image array
        """
        try:
            # Read image
            image_bytes = image_file.read()
            
            # Convert to numpy array
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if image is None:
                raise ValueError("Could not decode image")
            
            # Convert BGR to RGB
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            # Enhance image quality
            enhanced = self.enhance_image(image)
            
            # Remove background (optional)
            # segmented = self.remove_background(enhanced)
            
            return enhanced
            
        except Exception as e:
            logger.error(f"Image preprocessing failed: {str(e)}")
            raise
    
    def enhance_image(self, image: np.ndarray) -> np.ndarray:
        """
        Enhance image quality for better prediction
        
        Args:
            image: Input image array
            
        Returns:
            Enhanced image array
        """
        # Convert to PIL Image for enhancement
        pil_image = Image.fromarray(image)
        
        # Enhance contrast
        enhancer = ImageEnhance.Contrast(pil_image)
        enhanced = enhancer.enhance(1.2)
        
        # Enhance sharpness
        enhancer = ImageEnhance.Sharpness(enhanced)
        enhanced = enhancer.enhance(1.1)
        
        # Convert back to numpy
        enhanced_array = np.array(enhanced)
        
        return enhanced_array
    
    def remove_background(self, image: np.ndarray) -> np.ndarray:
        """
        Remove background from leaf image
        
        Args:
            image: Input image array
            
        Returns:
            Image with background removed
        """
        # Convert to HSV
        hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)
        
        # Define green color range for leaves
        lower_green = np.array([35, 40, 40])
        upper_green = np.array([85, 255, 255])
        
        # Create mask
        mask = cv2.inRange(hsv, lower_green, upper_green)
        
        # Apply morphological operations
        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        
        # Apply mask
        result = cv2.bitwise_and(image, image, mask=mask)
        
        # Create white background
        white_bg = np.ones_like(image) * 255
        white_bg = cv2.bitwise_and(white_bg, white_bg, mask=cv2.bitwise_not(mask))
        
        # Combine
        final = cv2.add(result, white_bg)
        
        return final
    
    def resize_image(self, image: np.ndarray, size: Tuple[int, int] = None) -> np.ndarray:
        """
        Resize image to specified dimensions
        
        Args:
            image: Input image array
            size: Target size (width, height)
            
        Returns:
            Resized image array
        """
        if size is None:
            size = self.default_size
        
        resized = cv2.resize(image, size, interpolation=cv2.INTER_AREA)
        return resized
    
    def detect_leaf_edges(self, image: np.ndarray) -> np.ndarray:
        """
        Detect leaf edges for shape analysis
        
        Args:
            image: Input image array
            
        Returns:
            Image with edges highlighted
        """
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        
        # Apply Gaussian blur
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # Detect edges using Canny
        edges = cv2.Canny(blurred, 50, 150)
        
        return edges
    
    def calculate_symmetry(self, image: np.ndarray) -> float:
        """
        Calculate leaf symmetry (for health assessment)
        
        Args:
            image: Input image array
            
        Returns:
            Symmetry score (0-1)
        """
        # This is a simplified implementation
        # In practice, you'd use more sophisticated methods
        
        edges = self.detect_leaf_edges(image)
        
        # Calculate moments
        moments = cv2.moments(edges)
        
        if moments['m00'] == 0:
            return 0.5  # Default symmetry
        
        # Calculate centroid
        cx = int(moments['m10'] / moments['m00'])
        cy = int(moments['m01'] / moments['m00'])
        
        # Split image and compare halves
        height, width = edges.shape
        left_half = edges[:, :cx]
        right_half = edges[:, cx:]
        
        # Flip right half and compare
        right_flipped = cv2.flip(right_half, 1)
        
        # Resize to same dimensions
        min_width = min(left_half.shape[1], right_flipped.shape[1])
        left_resized = left_half[:, :min_width]
        right_resized = right_flipped[:, :min_width]
        
        # Calculate similarity
        similarity = np.sum(left_resized == right_resized) / left_resized.size
        
        return similarity
    
    def extract_color_features(self, image: np.ndarray) -> Dict:
        """
        Extract color features from leaf image
        
        Args:
            image: Input image array
            
        Returns:
            Dictionary of color features
        """
        # Convert to HSV
        hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)
        
        # Calculate color histograms
        h_hist = cv2.calcHist([hsv], [0], None, [180], [0, 180])
        s_hist = cv2.calcHist([hsv], [1], None, [256], [0, 256])
        v_hist = cv2.calcHist([hsv], [2], None, [256], [0, 256])
        
        # Normalize histograms
        h_hist = cv2.normalize(h_hist, h_hist).flatten()
        s_hist = cv2.normalize(s_hist, s_hist).flatten()
        v_hist = cv2.normalize(v_hist, v_hist).flatten()
        
        # Calculate color moments
        mean_h = np.mean(hsv[:,:,0])
        std_h = np.std(hsv[:,:,0])
        
        mean_s = np.mean(hsv[:,:,1])
        std_s = np.std(hsv[:,:,1])
        
        mean_v = np.mean(hsv[:,:,2])
        std_v = np.std(hsv[:,:,2])
        
        return {
            'histograms': {
                'hue': h_hist.tolist(),
                'saturation': s_hist.tolist(),
                'value': v_hist.tolist()
            },
            'moments': {
                'hue_mean': float(mean_h),
                'hue_std': float(std_h),
                'saturation_mean': float(mean_s),
                'saturation_std': float(std_s),
                'value_mean': float(mean_v),
                'value_std': float(std_v)
            }
        }
