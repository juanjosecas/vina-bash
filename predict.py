#!/usr/bin/env python3
"""
Binding Affinity Prediction using Trained ML Model

This script uses a trained machine learning model to predict binding affinities
for new compounds using Vina scores and molecular descriptors.

Usage:
    python predict.py -m model.pkl -i input.csv -o predictions.csv [OPTIONS]

Input CSV Format:
    Must contain columns required by the trained model:
    - SMILES or molecular structure identifiers
    - Score_kcal_mol: Vina docking score (if used in training)
    - Other descriptor columns (if used in training)

Output:
    CSV file with predicted binding affinities
"""

import argparse
import sys
import os
import pickle
import warnings
from typing import Dict, List, Optional

import numpy as np
import pandas as pd

# Try to import optional dependencies
try:
    from rdkit import Chem
    from rdkit.Chem import Descriptors, Descriptors3D, AllChem
    RDKIT_AVAILABLE = True
except ImportError:
    RDKIT_AVAILABLE = False
    print("Warning: RDKit not available. Limited to existing descriptors in CSV.")

warnings.filterwarnings('ignore')


class BindingAffinityPredictor:
    """Predict binding affinities using trained ML model."""
    
    def __init__(self, model_path: str):
        """
        Initialize predictor.
        
        Args:
            model_path: Path to trained model file
        """
        self.model_path = model_path
        self.model = None
        self.scaler = None
        self.feature_names = []
        self.model_type = None
        self.metrics = {}
        
        self.load_model()
    
    def load_model(self):
        """Load trained model from file."""
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Model file not found: {self.model_path}")
        
        print(f"Loading model from: {self.model_path}")
        
        with open(self.model_path, 'rb') as f:
            model_data = pickle.load(f)
        
        self.model = model_data['model']
        self.scaler = model_data['scaler']
        self.feature_names = model_data['feature_names']
        self.model_type = model_data.get('model_type', 'unknown')
        self.metrics = model_data.get('metrics', {})
        
        print(f"Loaded {self.model_type} model")
        print(f"Required features: {len(self.feature_names)}")
        
        if self.metrics:
            print(f"Model CV R²: {self.metrics.get('cv_r2_mean', 0):.4f}")
    
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
    
    def compute_3d_descriptors(self, smiles: str, random_state: int = 42) -> Dict:
        """
        Compute 3D molecular descriptors from SMILES.
        
        Args:
            smiles: SMILES string
            random_state: Random seed for 3D generation
            
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
            result = AllChem.EmbedMolecule(mol, randomSeed=random_state)
            
            if result != 0:
                # Fallback if 3D generation fails
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
            Feature dataframe with required columns
        """
        features_df = df.copy()
        
        # Compute descriptors from SMILES if needed
        if compute_descriptors and 'SMILES' in df.columns and RDKIT_AVAILABLE:
            print("Computing molecular descriptors from SMILES...")
            
            # Check which descriptors are needed
            needs_2d = any(desc in self.feature_names for desc in [
                'MW', 'LogP', 'TPSA', 'HBA', 'HBD', 'RotatableBonds',
                'AromaticRings', 'Rings', 'FractionCSP3', 'MolMR',
                'NumAtoms', 'NumHeavyAtoms'
            ])
            
            needs_3d = any(desc in self.feature_names for desc in [
                'InertialShapeFactor', 'Eccentricity', 'Asphericity',
                'SpherocityIndex', 'RadiusOfGyration', 'PMI1', 'PMI2',
                'PMI3', 'NPR1', 'NPR2'
            ])
            
            if needs_2d:
                desc_2d_list = []
                for smiles in df['SMILES']:
                    desc_2d_list.append(self.compute_2d_descriptors(smiles))
                
                desc_2d_df = pd.DataFrame(desc_2d_list)
                features_df = pd.concat([features_df, desc_2d_df], axis=1)
            
            if needs_3d:
                desc_3d_list = []
                for smiles in df['SMILES']:
                    desc_3d_list.append(self.compute_3d_descriptors(smiles))
                
                desc_3d_df = pd.DataFrame(desc_3d_list)
                features_df = pd.concat([features_df, desc_3d_df], axis=1)
        
        return features_df
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """
        Make predictions.
        
        Args:
            X: Feature matrix
            
        Returns:
            Array of predictions
        """
        X_scaled = self.scaler.transform(X)
        predictions = self.model.predict(X_scaled)
        return predictions
    
    def predict_from_dataframe(self, df: pd.DataFrame, 
                               compute_descriptors: bool = True) -> pd.DataFrame:
        """
        Make predictions from dataframe.
        
        Args:
            df: Input dataframe
            compute_descriptors: Whether to compute descriptors from SMILES
            
        Returns:
            Dataframe with predictions
        """
        # Prepare features
        features_df = self.prepare_features(df, compute_descriptors)
        
        # Check for required features
        missing_features = [f for f in self.feature_names if f not in features_df.columns]
        
        if missing_features:
            print(f"Warning: Missing features: {', '.join(missing_features)}")
            print("These will be filled with zeros.")
            
            for feature in missing_features:
                features_df[feature] = 0.0
        
        # Extract feature matrix
        X = features_df[self.feature_names].values
        X = np.nan_to_num(X, nan=0.0)
        
        # Make predictions
        predictions = self.predict(X)
        
        # Add predictions to dataframe
        result_df = df.copy()
        result_df['predicted_affinity'] = predictions
        
        # Add uncertainty estimate if available (for sklearn ensemble models)
        try:
            if hasattr(self.model, 'estimators_') and hasattr(self.model.estimators_[0], 'predict'):
                # For Random Forest and Gradient Boosting
                X_scaled = self.scaler.transform(X)
                all_predictions = np.array([tree.predict(X_scaled) for tree in self.model.estimators_])
                prediction_std = np.std(all_predictions, axis=0)
                result_df['prediction_std'] = prediction_std
        except Exception as e:
            # Silently skip uncertainty estimation if not available
            pass
        
        return result_df


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Predict binding affinities using trained ML model',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument(
        '-m', '--model',
        required=True,
        help='Trained model file (.pkl)'
    )
    parser.add_argument(
        '-i', '--input',
        required=True,
        help='Input CSV file with molecular data'
    )
    parser.add_argument(
        '-o', '--output',
        default='predictions.csv',
        help='Output CSV file with predictions (default: predictions.csv)'
    )
    parser.add_argument(
        '-c', '--compute-descriptors',
        action='store_true',
        help='Compute descriptors from SMILES (requires RDKit)'
    )
    parser.add_argument(
        '--sort',
        action='store_true',
        help='Sort results by predicted affinity (best first)'
    )
    
    args = parser.parse_args()
    
    # Check input files
    if not os.path.exists(args.model):
        print(f"Error: Model file not found: {args.model}")
        sys.exit(1)
    
    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)
    
    # Load data
    print(f"Loading data from: {args.input}")
    df = pd.read_csv(args.input)
    print(f"Loaded {len(df)} samples")
    
    # Initialize predictor
    predictor = BindingAffinityPredictor(args.model)
    
    # Make predictions
    print("\nMaking predictions...")
    result_df = predictor.predict_from_dataframe(df, compute_descriptors=args.compute_descriptors)
    
    # Sort if requested
    if args.sort:
        result_df = result_df.sort_values('predicted_affinity', ascending=True)
    
    # Save results
    result_df.to_csv(args.output, index=False)
    print(f"\nPredictions saved to: {args.output}")
    
    # Display summary statistics
    print("\n" + "="*50)
    print("PREDICTION SUMMARY")
    print("="*50)
    print(f"Number of predictions: {len(result_df)}")
    print(f"Mean predicted affinity: {result_df['predicted_affinity'].mean():.4f}")
    print(f"Std predicted affinity:  {result_df['predicted_affinity'].std():.4f}")
    print(f"Min predicted affinity:  {result_df['predicted_affinity'].min():.4f}")
    print(f"Max predicted affinity:  {result_df['predicted_affinity'].max():.4f}")
    
    if 'prediction_std' in result_df.columns:
        print(f"\nMean prediction uncertainty: {result_df['prediction_std'].mean():.4f}")
    
    print("="*50 + "\n")
    
    # Display top predictions
    if args.sort:
        print("Top 5 Predictions (best binding affinity):")
        print(result_df[['predicted_affinity']].head().to_string())
    
    print("\nPrediction completed successfully!")


if __name__ == '__main__':
    main()
