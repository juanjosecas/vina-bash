#!/usr/bin/env python3
"""
Machine Learning Model Training for Binding Affinity Prediction

This script trains a machine learning model to predict binding affinities
using Vina docking scores combined with 2D and 3D molecular descriptors.

Usage:
    python train_model.py -i training_data.csv -o model.pkl [OPTIONS]

Input CSV Format:
    Must contain columns:
    - SMILES or MOL2_File: Molecular structure
    - experimental_affinity: Experimental binding affinity (e.g., pKd, pKi, DG)
    - Score_kcal_mol: Vina docking score (optional if from score.sh output)
    - Other descriptor columns (optional, will be computed if not present)

Output:
    - Trained model file (.pkl)
    - Feature importance plot
    - Cross-validation results
    - Model performance metrics
"""

import argparse
import sys
import os
import warnings
import pickle
import json
from typing import Dict, List, Tuple, Optional

import numpy as np
import pandas as pd
from sklearn.model_selection import cross_val_score, train_test_split, KFold
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.preprocessing import StandardScaler
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import seaborn as sns

# Try to import optional dependencies
try:
    from rdkit import Chem
    from rdkit.Chem import Descriptors, Descriptors3D, AllChem
    RDKIT_AVAILABLE = True
except ImportError:
    RDKIT_AVAILABLE = False
    print("Warning: RDKit not available. Limited to existing descriptors in CSV.")

try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False
    print("Warning: XGBoost not available. Using Random Forest only.")

warnings.filterwarnings('ignore')


class BindingAffinityModelTrainer:
    """Train ML models for binding affinity prediction."""
    
    def __init__(self, model_type='random_forest', n_estimators=100, random_state=42):
        """
        Initialize the trainer.
        
        Args:
            model_type: Type of model ('random_forest', 'gradient_boosting', 'xgboost')
            n_estimators: Number of trees/estimators
            random_state: Random seed for reproducibility
        """
        self.model_type = model_type
        self.n_estimators = n_estimators
        self.random_state = random_state
        self.model = None
        self.scaler = StandardScaler()
        self.feature_names = []
        self.metrics = {}
        
    def compute_2d_descriptors(self, smiles: str) -> Dict:
        """
        Compute 2D molecular descriptors from SMILES.
        
        Args:
            smiles: SMILES string
            
        Returns:
            Dictionary of descriptor values
        """
        if not RDKIT_AVAILABLE:
            return {}
        
        try:
            mol = Chem.MolFromSmiles(smiles)
            if mol is None:
                return {}
            
            descriptors = {
                'MW': Descriptors.MolWt(mol),
                'LogP': Descriptors.MolLogP(mol),
                'TPSA': Descriptors.TPSA(mol),
                'HBA': Descriptors.NumHAcceptors(mol),
                'HBD': Descriptors.NumHDonors(mol),
                'RotatableBonds': Descriptors.NumRotatableBonds(mol),
                'AromaticRings': Descriptors.NumAromaticRings(mol),
                'Rings': Descriptors.RingCount(mol),
                'FractionCSP3': Descriptors.FractionCsp3(mol),
                'MolMR': Descriptors.MolMR(mol),
                'NumAtoms': mol.GetNumAtoms(),
                'NumHeavyAtoms': mol.GetNumHeavyAtoms(),
            }
            
            return descriptors
        except Exception as e:
            print(f"Error computing 2D descriptors for {smiles}: {e}")
            return {}
    
    def compute_3d_descriptors(self, smiles: str) -> Dict:
        """
        Compute 3D molecular descriptors from SMILES.
        Generates 3D coordinates and computes 3D descriptors.
        
        Args:
            smiles: SMILES string
            
        Returns:
            Dictionary of 3D descriptor values
        """
        if not RDKIT_AVAILABLE:
            return {}
        
        try:
            mol = Chem.MolFromSmiles(smiles)
            if mol is None:
                return {}
            
            # Add hydrogens and generate 3D coordinates
            mol = Chem.AddHs(mol)
            result = AllChem.EmbedMolecule(mol, randomSeed=self.random_state)
            
            if result != 0:
                # Fallback to 2D if 3D generation fails
                return {}
            
            # Optimize geometry
            AllChem.MMFFOptimizeMolecule(mol)
            
            descriptors = {
                'InertialShapeFactor': Descriptors3D.InertialShapeFactor(mol),
                'Eccentricity': Descriptors3D.Eccentricity(mol),
                'Asphericity': Descriptors3D.Asphericity(mol),
                'SpherocityIndex': Descriptors3D.SpherocityIndex(mol),
                'RadiusOfGyration': Descriptors3D.RadiusOfGyration(mol),
                'PMI1': Descriptors3D.PMI1(mol),
                'PMI2': Descriptors3D.PMI2(mol),
                'PMI3': Descriptors3D.PMI3(mol),
                'NPR1': Descriptors3D.NPR1(mol),
                'NPR2': Descriptors3D.NPR2(mol),
            }
            
            return descriptors
        except Exception as e:
            print(f"Error computing 3D descriptors for {smiles}: {e}")
            return {}
    
    def prepare_features(self, df: pd.DataFrame, compute_descriptors: bool = True) -> pd.DataFrame:
        """
        Prepare feature matrix from input data.
        
        Args:
            df: Input dataframe
            compute_descriptors: Whether to compute descriptors from SMILES
            
        Returns:
            Feature dataframe
        """
        features_df = df.copy()
        
        # If SMILES available and requested, compute descriptors
        if compute_descriptors and 'SMILES' in df.columns and RDKIT_AVAILABLE:
            print("Computing molecular descriptors from SMILES...")
            
            # Compute 2D descriptors
            desc_2d_list = []
            for smiles in df['SMILES']:
                desc_2d_list.append(self.compute_2d_descriptors(smiles))
            
            desc_2d_df = pd.DataFrame(desc_2d_list)
            features_df = pd.concat([features_df, desc_2d_df], axis=1)
            
            # Compute 3D descriptors
            desc_3d_list = []
            for smiles in df['SMILES']:
                desc_3d_list.append(self.compute_3d_descriptors(smiles))
            
            desc_3d_df = pd.DataFrame(desc_3d_list)
            features_df = pd.concat([features_df, desc_3d_df], axis=1)
        
        return features_df
    
    def select_features(self, df: pd.DataFrame, target_col: str) -> List[str]:
        """
        Select feature columns for training.
        
        Args:
            df: Feature dataframe
            target_col: Target column name
            
        Returns:
            List of feature column names
        """
        # Exclude non-feature columns
        exclude_cols = [
            target_col, 'SMILES', 'PDBQT_File', 'MOL2_File', 
            'Formula', 'InChI', 'InChIKey', 'cansmi'
        ]
        
        feature_cols = [col for col in df.columns if col not in exclude_cols]
        
        # Remove columns with too many missing values
        feature_cols = [col for col in feature_cols if df[col].notna().sum() > len(df) * 0.5]
        
        return feature_cols
    
    def train(self, X: np.ndarray, y: np.ndarray, feature_names: List[str]):
        """
        Train the model.
        
        Args:
            X: Feature matrix
            y: Target values
            feature_names: List of feature names
        """
        self.feature_names = feature_names
        
        # Initialize model
        if self.model_type == 'random_forest':
            self.model = RandomForestRegressor(
                n_estimators=self.n_estimators,
                random_state=self.random_state,
                n_jobs=-1,
                max_depth=10,
                min_samples_split=5,
                min_samples_leaf=2
            )
        elif self.model_type == 'gradient_boosting':
            self.model = GradientBoostingRegressor(
                n_estimators=self.n_estimators,
                random_state=self.random_state,
                max_depth=5,
                learning_rate=0.1
            )
        elif self.model_type == 'xgboost' and XGBOOST_AVAILABLE:
            self.model = xgb.XGBRegressor(
                n_estimators=self.n_estimators,
                random_state=self.random_state,
                max_depth=6,
                learning_rate=0.1,
                n_jobs=-1
            )
        else:
            raise ValueError(f"Unknown model type: {self.model_type}")
        
        # Scale features
        X_scaled = self.scaler.fit_transform(X)
        
        # Train model
        print(f"Training {self.model_type} model...")
        self.model.fit(X_scaled, y)
    
    def evaluate(self, X: np.ndarray, y: np.ndarray, cv_folds: int = 5) -> Dict:
        """
        Evaluate model performance using cross-validation.
        
        Args:
            X: Feature matrix
            y: Target values
            cv_folds: Number of cross-validation folds
            
        Returns:
            Dictionary of evaluation metrics
        """
        X_scaled = self.scaler.transform(X)
        
        # Cross-validation
        kfold = KFold(n_splits=cv_folds, shuffle=True, random_state=self.random_state)
        
        cv_mse = -cross_val_score(
            self.model, X_scaled, y, 
            cv=kfold, scoring='neg_mean_squared_error', n_jobs=-1
        )
        cv_mae = -cross_val_score(
            self.model, X_scaled, y, 
            cv=kfold, scoring='neg_mean_absolute_error', n_jobs=-1
        )
        cv_r2 = cross_val_score(
            self.model, X_scaled, y, 
            cv=kfold, scoring='r2', n_jobs=-1
        )
        
        # Predictions on full dataset
        y_pred = self.model.predict(X_scaled)
        
        metrics = {
            'cv_rmse_mean': np.sqrt(cv_mse).mean(),
            'cv_rmse_std': np.sqrt(cv_mse).std(),
            'cv_mae_mean': cv_mae.mean(),
            'cv_mae_std': cv_mae.std(),
            'cv_r2_mean': cv_r2.mean(),
            'cv_r2_std': cv_r2.std(),
            'train_rmse': np.sqrt(mean_squared_error(y, y_pred)),
            'train_mae': mean_absolute_error(y, y_pred),
            'train_r2': r2_score(y, y_pred)
        }
        
        self.metrics = metrics
        return metrics
    
    def plot_feature_importance(self, output_path: str = 'feature_importance.png'):
        """
        Plot feature importance.
        
        Args:
            output_path: Output file path for plot
        """
        if not hasattr(self.model, 'feature_importances_'):
            print("Model does not support feature importance.")
            return
        
        importance = self.model.feature_importances_
        indices = np.argsort(importance)[::-1][:20]  # Top 20 features
        
        plt.figure(figsize=(10, 8))
        plt.barh(range(len(indices)), importance[indices])
        plt.yticks(range(len(indices)), [self.feature_names[i] for i in indices])
        plt.xlabel('Feature Importance')
        plt.title('Top 20 Most Important Features')
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Feature importance plot saved to: {output_path}")
    
    def plot_predictions(self, X: np.ndarray, y: np.ndarray, 
                        output_path: str = 'predictions_plot.png'):
        """
        Plot predicted vs actual values.
        
        Args:
            X: Feature matrix
            y: Actual target values
            output_path: Output file path for plot
        """
        X_scaled = self.scaler.transform(X)
        y_pred = self.model.predict(X_scaled)
        
        plt.figure(figsize=(8, 8))
        plt.scatter(y, y_pred, alpha=0.5)
        
        # Plot diagonal line
        min_val = min(y.min(), y_pred.min())
        max_val = max(y.max(), y_pred.max())
        plt.plot([min_val, max_val], [min_val, max_val], 'r--', lw=2)
        
        plt.xlabel('Experimental Affinity')
        plt.ylabel('Predicted Affinity')
        plt.title(f'Predicted vs Actual (R² = {self.metrics.get("train_r2", 0):.3f})')
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Predictions plot saved to: {output_path}")
    
    def save_model(self, output_path: str):
        """
        Save trained model and scaler.
        
        Args:
            output_path: Output file path
        """
        model_data = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'model_type': self.model_type,
            'metrics': self.metrics
        }
        
        with open(output_path, 'wb') as f:
            pickle.dump(model_data, f)
        
        print(f"Model saved to: {output_path}")
    
    def save_metrics(self, output_path: str = 'model_metrics.json'):
        """
        Save evaluation metrics to JSON.
        
        Args:
            output_path: Output file path
        """
        with open(output_path, 'w') as f:
            json.dump(self.metrics, f, indent=2)
        
        print(f"Metrics saved to: {output_path}")


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Train ML model for binding affinity prediction',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument(
        '-i', '--input',
        required=True,
        help='Input CSV file with training data'
    )
    parser.add_argument(
        '-o', '--output',
        default='binding_affinity_model.pkl',
        help='Output model file (default: binding_affinity_model.pkl)'
    )
    parser.add_argument(
        '-t', '--target',
        default='experimental_affinity',
        help='Target column name (default: experimental_affinity)'
    )
    parser.add_argument(
        '-m', '--model-type',
        choices=['random_forest', 'gradient_boosting', 'xgboost'],
        default='random_forest',
        help='Model type (default: random_forest)'
    )
    parser.add_argument(
        '-n', '--n-estimators',
        type=int,
        default=100,
        help='Number of estimators/trees (default: 100)'
    )
    parser.add_argument(
        '-c', '--compute-descriptors',
        action='store_true',
        help='Compute descriptors from SMILES (requires RDKit)'
    )
    parser.add_argument(
        '--cv-folds',
        type=int,
        default=5,
        help='Number of cross-validation folds (default: 5)'
    )
    parser.add_argument(
        '--no-plots',
        action='store_true',
        help='Skip generating plots'
    )
    parser.add_argument(
        '--random-state',
        type=int,
        default=42,
        help='Random seed for reproducibility (default: 42)'
    )
    
    args = parser.parse_args()
    
    # Check input file
    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)
    
    # Load data
    print(f"Loading data from: {args.input}")
    df = pd.read_csv(args.input)
    print(f"Loaded {len(df)} samples")
    
    # Check for target column
    if args.target not in df.columns:
        print(f"Error: Target column '{args.target}' not found in CSV")
        print(f"Available columns: {', '.join(df.columns)}")
        sys.exit(1)
    
    # Remove rows with missing target values
    df = df.dropna(subset=[args.target])
    print(f"Samples with valid target values: {len(df)}")
    
    if len(df) < 10:
        print("Error: Not enough samples for training (minimum 10 required)")
        sys.exit(1)
    
    # Initialize trainer
    trainer = BindingAffinityModelTrainer(
        model_type=args.model_type,
        n_estimators=args.n_estimators,
        random_state=args.random_state
    )
    
    # Prepare features
    features_df = trainer.prepare_features(df, compute_descriptors=args.compute_descriptors)
    
    # Select features
    feature_cols = trainer.select_features(features_df, args.target)
    print(f"Selected {len(feature_cols)} features: {', '.join(feature_cols)}")
    
    if len(feature_cols) == 0:
        print("Error: No valid features found")
        sys.exit(1)
    
    # Prepare training data
    X = features_df[feature_cols].values
    y = features_df[args.target].values
    
    # Handle missing values
    X = np.nan_to_num(X, nan=0.0)
    
    print(f"Feature matrix shape: {X.shape}")
    print(f"Target values shape: {y.shape}")
    
    # Train model
    trainer.train(X, y, feature_cols)
    
    # Evaluate model
    print("\nEvaluating model...")
    metrics = trainer.evaluate(X, y, cv_folds=args.cv_folds)
    
    print("\n" + "="*50)
    print("MODEL PERFORMANCE METRICS")
    print("="*50)
    print(f"Cross-Validation RMSE: {metrics['cv_rmse_mean']:.4f} ± {metrics['cv_rmse_std']:.4f}")
    print(f"Cross-Validation MAE:  {metrics['cv_mae_mean']:.4f} ± {metrics['cv_mae_std']:.4f}")
    print(f"Cross-Validation R²:   {metrics['cv_r2_mean']:.4f} ± {metrics['cv_r2_std']:.4f}")
    print(f"\nTraining RMSE: {metrics['train_rmse']:.4f}")
    print(f"Training MAE:  {metrics['train_mae']:.4f}")
    print(f"Training R²:   {metrics['train_r2']:.4f}")
    print("="*50 + "\n")
    
    # Save model
    trainer.save_model(args.output)
    
    # Save metrics
    metrics_file = args.output.replace('.pkl', '_metrics.json')
    trainer.save_metrics(metrics_file)
    
    # Generate plots
    if not args.no_plots:
        importance_file = args.output.replace('.pkl', '_feature_importance.png')
        trainer.plot_feature_importance(importance_file)
        
        predictions_file = args.output.replace('.pkl', '_predictions.png')
        trainer.plot_predictions(X, y, predictions_file)
    
    print("\nTraining completed successfully!")


if __name__ == '__main__':
    main()
