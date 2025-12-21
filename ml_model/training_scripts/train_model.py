"""
Mkulima AI Model Training Script
Trains plant disease detection model using TensorFlow/Keras
"""

import os
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, models, applications
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
import cv2
import json
from datetime import datetime
import mlflow
import mlflow.tensorflow
import argparse

# Set random seeds for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

class PlantDiseaseModel:
    """Plant Disease Detection Model Trainer"""
    
    def __init__(self, config_path='config.yaml'):
        """
        Initialize model trainer
        
        Args:
            config_path: Path to configuration file
        """
        self.config = self.load_config(config_path)
        self.model = None
        self.history = None
        self.class_names = []
        
        # Setup directories
        self.setup_directories()
        
        # Setup MLflow
        if self.config['tracking']['use_mlflow']:
            mlflow.set_tracking_uri(self.config['tracking']['mlflow_uri'])
            mlflow.set_experiment(self.config['experiment_name'])
    
    def load_config(self, config_path):
        """Load configuration from YAML file"""
        # For now, use default config
        # In practice, load from YAML
        return {
            'data': {
                'dataset_path': '../datasets/PlantVillage',
                'image_size': (224, 224),
                'batch_size': 32,
                'validation_split': 0.2,
                'test_split': 0.1
            },
            'model': {
                'base_model': 'MobileNetV2',
                'input_shape': (224, 224, 3),
                'num_classes': 38,  # PlantVillage has 38 classes
                'dropout_rate': 0.5,
                'learning_rate': 0.001
            },
            'training': {
                'epochs': 50,
                'early_stopping_patience': 10,
                'reduce_lr_patience': 5,
                'use_augmentation': True,
                'use_class_weights': True
            },
            'augmentation': {
                'rotation_range': 40,
                'width_shift_range': 0.2,
                'height_shift_range': 0.2,
                'shear_range': 0.2,
                'zoom_range': 0.2,
                'horizontal_flip': True,
                'vertical_flip': False,
                'brightness_range': [0.8, 1.2],
                'fill_mode': 'nearest'
            },
            'tracking': {
                'use_mlflow': True,
                'mlflow_uri': 'http://localhost:5000',
                'save_checkpoints': True,
                'save_best_only': True
            },
            'paths': {
                'models_dir': '../models',
                'logs_dir': '../logs',
                'checkpoints_dir': '../checkpoints'
            },
            'experiment_name': 'mkulima_ai_plant_disease'
        }
    
    def setup_directories(self):
        """Create necessary directories"""
        dirs = [
            self.config['paths']['models_dir'],
            self.config['paths']['logs_dir'],
            self.config['paths']['checkpoints_dir'],
            '../exports',
            '../visualizations'
        ]
        
        for dir_path in dirs:
            os.makedirs(dir_path, exist_ok=True)
    
    def load_dataset(self):
        """
        Load and prepare the dataset
        
        Returns:
            train_ds, val_ds, test_ds: TensorFlow datasets
        """
        print("Loading dataset...")
        
        # This is a simplified version
        # In practice, you'd load from PlantVillage or your own dataset
        
        dataset_path = self.config['data']['dataset_path']
        image_size = self.config['data']['image_size']
        batch_size = self.config['data']['batch_size']
        
        # Create data generators
        if self.config['training']['use_augmentation']:
            train_datagen = keras.preprocessing.image.ImageDataGenerator(
                rescale=1./255,
                rotation_range=self.config['augmentation']['rotation_range'],
                width_shift_range=self.config['augmentation']['width_shift_range'],
                height_shift_range=self.config['augmentation']['height_shift_range'],
                shear_range=self.config['augmentation']['shear_range'],
                zoom_range=self.config['augmentation']['zoom_range'],
                horizontal_flip=self.config['augmentation']['horizontal_flip'],
                vertical_flip=self.config['augmentation']['vertical_flip'],
                brightness_range=self.config['augmentation']['brightness_range'],
                fill_mode=self.config['augmentation']['fill_mode'],
                validation_split=self.config['data']['validation_split']
            )
        else:
            train_datagen = keras.preprocessing.image.ImageDataGenerator(
                rescale=1./255,
                validation_split=self.config['data']['validation_split']
            )
        
        # For validation and test, only rescale
        val_datagen = keras.preprocessing.image.ImageDataGenerator(
            rescale=1./255,
            validation_split=self.config['data']['validation_split']
        )
        
        # Load training data
        train_ds = train_datagen.flow_from_directory(
            dataset_path,
            target_size=image_size,
            batch_size=batch_size,
            class_mode='categorical',
            subset='training',
            seed=42
        )
        
        # Load validation data
        val_ds = val_datagen.flow_from_directory(
            dataset_path,
            target_size=image_size,
            batch_size=batch_size,
            class_mode='categorical',
            subset='validation',
            seed=42
        )
        
        # Get class names
        self.class_names = list(train_ds.class_indices.keys())
        print(f"Found {len(self.class_names)} classes: {self.class_names}")
        print(f"Training samples: {train_ds.samples}")
        print(f"Validation samples: {val_ds.samples}")
        
        # Create test dataset (you might need a separate test directory)
        # For now, we'll use part of validation as test
        total_samples = train_ds.samples + val_ds.samples
        test_split = self.config['data']['test_split']
        test_size = int(total_samples * test_split)
        
        # In practice, you'd have a separate test set
        test_ds = val_ds
        
        return train_ds, val_ds, test_ds
    
    def create_model(self):
        """
        Create the neural network model
        
        Returns:
            Compiled Keras model
        """
        print("Creating model...")
        
        base_model_name = self.config['model']['base_model']
        input_shape = self.config['model']['input_shape']
        num_classes = self.config['model']['num_classes']
        dropout_rate = self.config['model']['dropout_rate']
        
        # Load pre-trained base model
        if base_model_name == 'MobileNetV2':
            base_model = applications.MobileNetV2(
                input_shape=input_shape,
                include_top=False,
                weights='imagenet'
            )
        elif base_model_name == 'EfficientNetB0':
            base_model = applications.EfficientNetB0(
                input_shape=input_shape,
                include_top=False,
                weights='imagenet'
            )
        elif base_model_name == 'ResNet50':
            base_model = applications.ResNet50(
                input_shape=input_shape,
                include_top=False,
                weights='imagenet'
            )
        else:
            raise ValueError(f"Unsupported base model: {base_model_name}")
        
        # Freeze base model layers
        base_model.trainable = False
        
        # Create new model on top
        inputs = keras.Input(shape=input_shape)
        
        # Data augmentation
        x = layers.RandomFlip("horizontal")(inputs)
        x = layers.RandomRotation(0.1)(x)
        x = layers.RandomZoom(0.1)(x)
        
        # Preprocess input according to base model requirements
        if base_model_name in ['MobileNetV2', 'EfficientNetB0']:
            x = applications.mobilenet_v2.preprocess_input(x)
        elif base_model_name == 'ResNet50':
            x = applications.resnet50.preprocess_input(x)
        
        # Base model
        x = base_model(x, training=False)
        
        # Global pooling
        x = layers.GlobalAveragePooling2D()(x)
        
        # Dense layers
        x = layers.Dense(512, activation='relu')(x)
        x = layers.BatchNormalization()(x)
        x = layers.Dropout(dropout_rate)(x)
        
        x = layers.Dense(256, activation='relu')(x)
        x = layers.BatchNormalization()(x)
        x = layers.Dropout(dropout_rate)(x)
        
        # Output layer
        outputs = layers.Dense(num_classes, activation='softmax')(x)
        
        # Create model
        model = keras.Model(inputs, outputs)
        
        return model
    
    def compile_model(self, model):
        """
        Compile the model with optimizer and loss
        
        Args:
            model: Keras model to compile
            
        Returns:
            Compiled model
        """
        print("Compiling model...")
        
        learning_rate = self.config['model']['learning_rate']
        
        optimizer = keras.optimizers.Adam(learning_rate=learning_rate)
        
        model.compile(
            optimizer=optimizer,
            loss='categorical_crossentropy',
            metrics=[
                'accuracy',
                keras.metrics.Precision(name='precision'),
                keras.metrics.Recall(name='recall'),
                keras.metrics.AUC(name='auc')
            ]
        )
        
        model.summary()
        
        return model
    
    def train_model(self, train_ds, val_ds):
        """
        Train the model
        
        Args:
            train_ds: Training dataset
            val_ds: Validation dataset
            
        Returns:
            Training history
        """
        print("Starting training...")
        
        epochs = self.config['training']['epochs']
        
        # Callbacks
        callbacks = []
        
        # Model checkpoint
        checkpoint_path = os.path.join(
            self.config['paths']['checkpoints_dir'],
            'best_model.weights.h5'
        )
        
        checkpoint_cb = keras.callbacks.ModelCheckpoint(
            filepath=checkpoint_path,
            monitor='val_accuracy',
            save_best_only=self.config['tracking']['save_best_only'],
            save_weights_only=True,
            verbose=1
        )
        callbacks.append(checkpoint_cb)
        
        # Early stopping
        early_stopping_cb = keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=self.config['training']['early_stopping_patience'],
            restore_best_weights=True,
            verbose=1
        )
        callbacks.append(early_stopping_cb)
        
        # Reduce learning rate on plateau
        reduce_lr_cb = keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=self.config['training']['reduce_lr_patience'],
            min_lr=1e-6,
            verbose=1
        )
        callbacks.append(reduce_lr_cb)
        
        # TensorBoard
        log_dir = os.path.join(
            self.config['paths']['logs_dir'],
            datetime.now().strftime("%Y%m%d-%H%M%S")
        )
        tensorboard_cb = keras.callbacks.TensorBoard(
            log_dir=log_dir,
            histogram_freq=1
        )
        callbacks.append(tensorboard_cb)
        
        # MLflow callback
        if self.config['tracking']['use_mlflow']:
            mlflow_cb = mlflow.keras.MlflowCallback()
            callbacks.append(mlflow_cb)
        
        # Calculate class weights if needed
        class_weight = None
        if self.config['training']['use_class_weights']:
            # This is simplified - in practice, calculate from your dataset
            class_weight = 'balanced'
        
        # Train the model
        with mlflow.start_run() if self.config['tracking']['use_mlflow'] else None:
            # Log parameters
            if self.config['tracking']['use_mlflow']:
                mlflow.log_params({
                    'base_model': self.config['model']['base_model'],
                    'learning_rate': self.config['model']['learning_rate'],
                    'epochs': epochs,
                    'batch_size': self.config['data']['batch_size'],
                    'image_size': self.config['data']['image_size']
                })
            
            # Train
            history = self.model.fit(
                train_ds,
                epochs=epochs,
                validation_data=val_ds,
                callbacks=callbacks,
                class_weight=class_weight,
                verbose=1
            )
            
            # Log metrics
            if self.config['tracking']['use_mlflow']:
                mlflow.log_metrics({
                    'train_accuracy': history.history['accuracy'][-1],
                    'val_accuracy': history.history['val_accuracy'][-1],
                    'train_loss': history.history['loss'][-1],
                    'val_loss': history.history['val_loss'][-1]
                })
                
                # Log model
                mlflow.tensorflow.log_model(
                    self.model,
                    "model",
                    registered_model_name="plant_disease_detector"
                )
        
        return history
    
    def evaluate_model(self, test_ds):
        """
        Evaluate the trained model
        
        Args:
            test_ds: Test dataset
            
        Returns:
            Evaluation metrics
        """
        print("Evaluating model...")
        
        # Load best weights
        checkpoint_path = os.path.join(
            self.config['paths']['checkpoints_dir'],
            'best_model.weights.h5'
        )
        
        if os.path.exists(checkpoint_path):
            self.model.load_weights(checkpoint_path)
            print("Loaded best model weights from checkpoint")
        
        # Evaluate
        results = self.model.evaluate(test_ds, verbose=1)
        
        metrics = {
            'loss': results[0],
            'accuracy': results[1],
            'precision': results[2],
            'recall': results[3],
            'auc': results[4]
        }
        
        print("\nEvaluation Results:")
        for metric_name, value in metrics.items():
            print(f"{metric_name}: {value:.4f}")
        
        return metrics
    
    def save_model(self, format='both'):
        """
        Save the trained model in different formats
        
        Args:
            format: 'h5', 'tflite', or 'both'
        """
        print("Saving model...")
        
        model_name = f"plant_disease_model_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        models_dir = self.config['paths']['models_dir']
        
        # Save as H5
        if format in ['h5', 'both']:
            h5_path = os.path.join(models_dir, f"{model_name}.h5")
            self.model.save(h5_path)
            print(f"Model saved as H5: {h5_path}")
        
        # Save as TensorFlow Lite
        if format in ['tflite', 'both']:
            # Convert to TFLite
            converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            converter.target_spec.supported_types = [tf.float16]
            
            tflite_model = converter.convert()
            
            # Save TFLite model
            tflite_path = os.path.join(models_dir, f"{model_name}.tflite")
            with open(tflite_path, 'wb') as f:
                f.write(tflite_model)
            print(f"Model saved as TFLite: {tflite_path}")
        
        # Save class labels
        labels_path = os.path.join(models_dir, "labels.txt")
        with open(labels_path, 'w') as f:
            for class_name in self.class_names:
                f.write(f"{class_name}\n")
        print(f"Labels saved: {labels_path}")
        
        # Save model metadata
        metadata = {
            'model_name': model_name,
            'base_model': self.config['model']['base_model'],
            'input_shape': self.config['model']['input_shape'],
            'num_classes': len(self.class_names),
            'classes': self.class_names,
            'created_at': datetime.now().isoformat(),
            'version': '1.0.0'
        }
        
        metadata_path = os.path.join(models_dir, f"{model_name}_metadata.json")
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        print(f"Metadata saved: {metadata_path}")
    
    def plot_training_history(self):
        """Plot training history"""
        if self.history is None:
            print("No training history to plot")
            return
        
        fig, axes = plt.subplots(2, 2, figsize=(12, 8))
        
        # Accuracy
        axes[0, 0].plot(self.history.history['accuracy'], label='Train')
        axes[0, 0].plot(self.history.history['val_accuracy'], label='Validation')
        axes[0, 0].set_title('Model Accuracy')
        axes[0, 0].set_xlabel('Epoch')
        axes[0, 0].set_ylabel('Accuracy')
        axes[0, 0].legend()
        axes[0, 0].grid(True)
        
        # Loss
        axes[0, 1].plot(self.history.history['loss'], label='Train')
        axes[0, 1].plot(self.history.history['val_loss'], label='Validation')
        axes[0, 1].set_title('Model Loss')
        axes[0, 1].set_xlabel('Epoch')
        axes[0, 1].set_ylabel('Loss')
        axes[0, 1].legend()
        axes[0, 1].grid(True)
        
        # Precision
        if 'precision' in self.history.history:
            axes[1, 0].plot(self.history.history['precision'], label='Train')
            axes[1, 0].plot(self.history.history['val_precision'], label='Validation')
            axes[1, 0].set_title('Model Precision')
            axes[1, 0].set_xlabel('Epoch')
            axes[1, 0].set_ylabel('Precision')
            axes[1, 0].legend()
            axes[1, 0].grid(True)
        
        # Recall
        if 'recall' in self.history.history:
            axes[1, 1].plot(self.history.history['recall'], label='Train')
            axes[1, 1].plot(self.history.history['val_recall'], label='Validation')
            axes[1, 1].set_title('Model Recall')
            axes[1, 1].set_xlabel('Epoch')
            axes[1, 1].set_ylabel('Recall')
            axes[1, 1].legend()
            axes[1, 1].grid(True)
        
        plt.tight_layout()
        
        # Save figure
        plots_dir = '../visualizations'
        os.makedirs(plots_dir, exist_ok=True)
        
        plot_path = os.path.join(plots_dir, 'training_history.png')
        plt.savefig(plot_path, dpi=300, bbox_inches='tight')
        print(f"Training plot saved: {plot_path}")
        
        plt.show()
    
    def run(self):
        """Run the complete training pipeline"""
        print("=" * 50)
        print("Mkulima AI Model Training")
        print("=" * 50)
        
        # Load data
        train_ds, val_ds, test_ds = self.load_dataset()
        
        # Create model
        self.model = self.create_model()
        self.model = self.compile_model(self.model)
        
        # Train model
        self.history = self.train_model(train_ds, val_ds)
        
        # Evaluate model
        metrics = self.evaluate_model(test_ds)
        
        # Save model
        self.save_model(format='both')
        
        # Plot history
        self.plot_training_history()
        
        print("\nTraining completed successfully!")
        return metrics

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Train plant disease detection model')
    parser.add_argument('--config', type=str, default='config.yaml',
                       help='Path to configuration file')
    parser.add_argument('--epochs', type=int, default=None,
                       help='Number of training epochs')
    parser.add_argument('--batch_size', type=int, default=None,
                       help='Batch size for training')
    
    args = parser.parse_args()
    
    # Initialize and run trainer
    trainer = PlantDiseaseModel(args.config)
    
    # Override config if provided
    if args.epochs:
        trainer.config['training']['epochs'] = args.epochs
    if args.batch_size:
        trainer.config['data']['batch_size'] = args.batch_size
    
    # Run training
    trainer.run()

if __name__ == '__main__':
    main()
