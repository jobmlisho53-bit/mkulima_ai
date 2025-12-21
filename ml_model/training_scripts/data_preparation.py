"""
Data Preparation Script for Mkulima AI
Prepares and augments plant disease image datasets
"""

import os
import numpy as np
import pandas as pd
import cv2
from PIL import Image
import albumentations as A
from sklearn.model_selection import train_test_split
import shutil
from tqdm import tqdm
import json

class DataPreparer:
    """Prepares and augments plant disease image data"""
    
    def __init__(self, source_dir, target_dir):
        """
        Initialize data preparer
        
        Args:
            source_dir: Source directory with raw images
            target_dir: Target directory for processed images
        """
        self.source_dir = source_dir
        self.target_dir = target_dir
        
        # Create target directories
        self.train_dir = os.path.join(target_dir, 'train')
        self.val_dir = os.path.join(target_dir, 'val')
        self.test_dir = os.path.join(target_dir, 'test')
        
        for dir_path in [self.train_dir, self.val_dir, self.test_dir]:
            os.makedirs(dir_path, exist_ok=True)
        
        # Define augmentation pipeline
        self.augmentation_pipeline = A.Compose([
            A.RandomRotate90(p=0.5),
            A.Flip(p=0.5),
            A.Transpose(p=0.5),
            A.OneOf([
                A.IAAAdditiveGaussianNoise(),
                A.GaussNoise(),
            ], p=0.2),
            A.OneOf([
                A.MotionBlur(p=0.2),
                A.MedianBlur(blur_limit=3, p=0.1),
                A.Blur(blur_limit=3, p=0.1),
            ], p=0.2),
            A.ShiftScaleRotate(shift_limit=0.0625, scale_limit=0.2, 
                              rotate_limit=45, p=0.2),
            A.OneOf([
                A.OpticalDistortion(p=0.3),
                A.GridDistortion(p=0.1),
                A.IAAPiecewiseAffine(p=0.3),
            ], p=0.2),
            A.OneOf([
                A.CLAHE(clip_limit=2),
                A.IAASharpen(),
                A.IAAEmboss(),
                A.RandomBrightnessContrast(),
            ], p=0.3),
            A.HueSaturationValue(p=0.3),
        ])
    
    def get_class_distribution(self):
        """Get distribution of classes in dataset"""
        class_counts = {}
        
        for class_name in os.listdir(self.source_dir):
            class_dir = os.path.join(self.source_dir, class_name)
            if os.path.isdir(class_dir):
                num_images = len([f for f in os.listdir(class_dir) 
                                if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
                class_counts[class_name] = num_images
        
        return class_counts
    
    def balance_dataset(self, target_samples_per_class=1000):
        """
        Balance dataset by augmenting minority classes
        
        Args:
            target_samples_per_class: Target number of samples per class
        """
        print("Balancing dataset...")
        
        class_counts = self.get_class_distribution()
        
        for class_name, count in class_counts.items():
            print(f"{class_name}: {count} samples")
            
            if count < target_samples_per_class:
                print(f"  Augmenting {class_name} to reach {target_samples_per_class} samples...")
                self.augment_class(class_name, target_samples_per_class - count)
    
    def augment_class(self, class_name, num_augmentations):
        """
        Augment images for a specific class
        
        Args:
            class_name: Name of the class to augment
            num_augmentations: Number of augmented images to create
        """
        class_dir = os.path.join(self.source_dir, class_name)
        image_files = [f for f in os.listdir(class_dir) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        
        if not image_files:
            print(f"  No images found for class {class_name}")
            return
        
        # Calculate how many augmentations per original image
        aug_per_image = max(1, num_augmentations // len(image_files))
        
        augmented_count = 0
        for image_file in tqdm(image_files, desc=f"Augmenting {class_name}"):
            if augmented_count >= num_augmentations:
                break
            
            image_path = os.path.join(class_dir, image_file)
            image = cv2.imread(image_path)
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            for i in range(aug_per_image):
                if augmented_count >= num_augmentations:
                    break
                
                # Apply augmentations
                augmented = self.augmentation_pipeline(image=image)
                aug_image = augmented['image']
                
                # Save augmented image
                aug_filename = f"aug_{augmented_count}_{image_file}"
                aug_path = os.path.join(class_dir, aug_filename)
                
                aug_image_rgb = cv2.cvtColor(aug_image, cv2.COLOR_RGB2BGR)
                cv2.imwrite(aug_path, aug_image_rgb)
                
                augmented_count += 1
        
        print(f"  Created {augmented_count} augmented images for {class_name}")
    
    def prepare_train_val_test_split(self, val_ratio=0.15, test_ratio=0.15):
        """
        Split data into train, validation, and test sets
        
        Args:
            val_ratio: Validation set ratio
            test_ratio: Test set ratio
        """
        print("Splitting dataset...")
        
        all_images = []
        all_labels = []
        
        # Collect all images and labels
        for class_idx, class_name in enumerate(os.listdir(self.source_dir)):
            class_dir = os.path.join(self.source_dir, class_name)
            if not os.path.isdir(class_dir):
                continue
            
            image_files = [f for f in os.listdir(class_dir) 
                          if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
            
            for image_file in image_files:
                all_images.append(os.path.join(class_name, image_file))
                all_labels.append(class_idx)
        
        print(f"Total images: {len(all_images)}")
        
        # Split into train+val and test
        train_val_images, test_images, train_val_labels, test_labels = train_test_split(
            all_images, all_labels, test_size=test_ratio, stratify=all_labels, random_state=42
        )
        
        # Split train+val into train and val
        train_images, val_images, train_labels, val_labels = train_test_split(
            train_val_images, train_val_labels, 
            test_size=val_ratio/(1-test_ratio),  # Adjust ratio
            stratify=train_val_labels, 
            random_state=42
        )
        
        print(f"Train set: {len(train_images)} images")
        print(f"Validation set: {len(val_images)} images")
        print(f"Test set: {len(test_images)} images")
        
        # Copy images to respective directories
        self.copy_images_to_split(train_images, 'train')
        self.copy_images_to_split(val_images, 'val')
        self.copy_images_to_split(test_images, 'test')
        
        # Save split information
        self.save_split_info(train_images, val_images, test_images)
    
    def copy_images_to_split(self, image_paths, split_name):
        """
        Copy images to split directory
        
        Args:
            image_paths: List of image paths
            split_name: 'train', 'val', or 'test'
        """
        split_dir = getattr(self, f'{split_name}_dir')
        
        for rel_path in tqdm(image_paths, desc=f"Copying {split_name} images"):
            class_name, image_file = os.path.split(rel_path)
            
            # Create class directory in split
            class_split_dir = os.path.join(split_dir, class_name)
            os.makedirs(class_split_dir, exist_ok=True)
            
            # Source and destination paths
            src_path = os.path.join(self.source_dir, rel_path)
            dst_path = os.path.join(class_split_dir, image_file)
            
            # Copy image
            shutil.copy2(src_path, dst_path)
    
    def save_split_info(self, train_images, val_images, test_images):
        """Save information about the split"""
        split_info = {
            'train_count': len(train_images),
            'val_count': len(val_images),
            'test_count': len(test_images),
            'total_count': len(train_images) + len(val_images) + len(test_images),
            'class_mapping': self.get_class_mapping(),
            'train_samples': train_images[:100],  # Save first 100 for reference
            'val_samples': val_images[:50],
            'test_samples': test_images[:50]
        }
        
        info_path = os.path.join(self.target_dir, 'split_info.json')
        with open(info_path, 'w') as f:
            json.dump(split_info, f, indent=2)
        
        print(f"Split information saved to {info_path}")
    
    def get_class_mapping(self):
        """Get mapping from class names to indices"""
        class_mapping = {}
        
        for idx, class_name in enumerate(sorted(os.listdir(self.source_dir))):
            class_dir = os.path.join(self.source_dir, class_name)
            if os.path.isdir(class_dir):
                class_mapping[class_name] = idx
        
        return class_mapping
    
    def resize_images(self, target_size=(224, 224)):
        """
        Resize all images to target size
        
        Args:
            target_size: Target image size (width, height)
        """
        print(f"Resizing images to {target_size}...")
        
        for split_dir in [self.train_dir, self.val_dir, self.test_dir]:
            for class_name in os.listdir(split_dir):
                class_dir = os.path.join(split_dir, class_name)
                if not os.path.isdir(class_dir):
                    continue
                
                for image_file in tqdm(os.listdir(class_dir), 
                                     desc=f"Resizing {os.path.basename(split_dir)}/{class_name}"):
                    if not image_file.lower().endswith(('.png', '.jpg', '.jpeg')):
                        continue
                    
                    image_path = os.path.join(class_dir, image_file)
                    
                    # Open and resize image
                    image = Image.open(image_path)
                    image = image.resize(target_size, Image.Resampling.LANCZOS)
                    
                    # Save back (overwrite)
                    image.save(image_path)
    
    def run(self, balance=True, resize=True):
        """Run complete data preparation pipeline"""
        print("=" * 50)
        print("Mkulima AI Data Preparation")
        print("=" * 50)
        
        # Balance dataset if requested
        if balance:
            self.balance_dataset(target_samples_per_class=1000)
        
        # Split data
        self.prepare_train_val_test_split(val_ratio=0.15, test_ratio=0.15)
        
        # Resize images if requested
        if resize:
            self.resize_images(target_size=(224, 224))
        
        print("\nData preparation completed successfully!")
        
        # Print summary
        self.print_summary()
    
    def print_summary(self):
        """Print dataset summary"""
        print("\nDataset Summary:")
        print("-" * 30)
        
        total_train = 0
        total_val = 0
        total_test = 0
        
        for split_name, split_dir in [('Train', self.train_dir), 
                                     ('Validation', self.val_dir), 
                                     ('Test', self.test_dir)]:
            print(f"\n{split_name} Set:")
            
            for class_name in sorted(os.listdir(split_dir)):
                class_dir = os.path.join(split_dir, class_name)
                if os.path.isdir(class_dir):
                    num_images = len([f for f in os.listdir(class_dir) 
                                    if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
                    
                    print(f"  {class_name}: {num_images} images")
                    
                    if split_name == 'Train':
                        total_train += num_images
                    elif split_name == 'Validation':
                        total_val += num_images
                    elif split_name == 'Test':
                        total_test += num_images
        
        print(f"\nTotal Train Images: {total_train}")
        print(f"Total Validation Images: {total_val}")
        print(f"Total Test Images: {total_test}")
        print(f"Total Dataset Size: {total_train + total_val + total_test}")

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Prepare plant disease dataset')
    parser.add_argument('--source', type=str, required=True,
                       help='Source directory with raw images')
    parser.add_argument('--target', type=str, required=True,
                       help='Target directory for processed images')
    parser.add_argument('--balance', action='store_true',
                       help='Balance dataset by augmenting minority classes')
    parser.add_argument('--no-resize', action='store_false', dest='resize',
                       help='Do not resize images')
    
    args = parser.parse_args()
    
    # Initialize and run data preparer
    preparer = DataPreparer(args.source, args.target)
    preparer.run(balance=args.balance, resize=args.resize)

if __name__ == '__main__':
    main()

