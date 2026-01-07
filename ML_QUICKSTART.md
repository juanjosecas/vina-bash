# Machine Learning Quickstart Guide

This guide will help you get started with training machine learning models to improve binding affinity predictions.

## Overview

The ML workflow combines AutoDock Vina docking scores with 2D and 3D molecular descriptors to create more accurate predictions. This is especially useful when you have experimental binding affinity data for your target protein.

## Prerequisites

### Install Python Dependencies

```bash
pip install -r requirements.txt
```

If you encounter issues with RDKit, you can still use the scripts with existing descriptors (computed by `score.sh`), though computing additional 2D/3D descriptors from SMILES won't be available.

## Quick Start: Complete Workflow

### 1. Prepare Your Training Data

You need a CSV file with:
- **experimental_affinity**: Your experimental values (pKd, pKi, ΔG, etc.)
- **SMILES**: Molecular structures
- **Score_kcal_mol**: Vina docking scores (from `score.sh`)
- **Other descriptors**: MW, logP, TPSA, etc. (from `score.sh`)

#### Option A: Start with Experimental Data

If you already have experimental data:

```csv
SMILES,experimental_affinity
CCO,-7.8
CC(C)O,-8.5
c1ccccc1,-6.3
```

Then run docking to get Vina scores:

```bash
# Prepare ligands (SMILES to PDBQT)
# Run docking
./vina_pipeline.sh --jobs 4

# Get descriptors
./score.sh -i "out*.pdbqt"

# Merge with your experimental data
# (manually or with a script)
```

#### Option B: Use Existing Docking Results

If you have docking results and want to add experimental values:

```bash
# Generate descriptors from docking
./score.sh -i "out*.pdbqt"

# Edit scoring.csv to add experimental_affinity column
# Add your experimental values for each compound
```

### 2. Train the Model

Basic training (using existing descriptors):

```bash
python train_model.py \
  -i training_data.csv \
  -o my_model.pkl \
  -t experimental_affinity
```

Advanced training (compute additional descriptors from SMILES):

```bash
python train_model.py \
  -i training_data.csv \
  -o my_model.pkl \
  -t experimental_affinity \
  -m xgboost \
  -n 200 \
  --compute-descriptors
```

**Parameters explained:**
- `-i`: Input CSV with training data
- `-o`: Output model file name
- `-t`: Column name with experimental values
- `-m`: Model type (random_forest, xgboost, gradient_boosting)
- `-n`: Number of trees/estimators
- `--compute-descriptors`: Calculate 2D/3D descriptors from SMILES (requires RDKit)

### 3. Review Model Performance

After training, check the output:

```bash
# View metrics
cat my_model_metrics.json

# Check plots (if generated)
# - my_model_feature_importance.png: Shows which features are most important
# - my_model_predictions.png: Predicted vs actual values
```

**What to look for:**
- **CV R²** > 0.7: Good model
- **CV RMSE**: Should be low relative to your data range
- Check that CV metrics are similar to training metrics (avoid overfitting)

### 4. Make Predictions

For new compounds:

```bash
# Run docking for new compounds
./vina_pipeline.sh --jobs 4 -p "new_lig*.pdbqt"

# Generate descriptors
./score.sh -i "out_new*.pdbqt" -o new_scoring.csv

# Predict binding affinities
python predict.py \
  -m my_model.pkl \
  -i new_scoring.csv \
  -o predictions.csv \
  --sort

# View top predictions
head predictions.csv
```

## Example with Provided Data

Try it with the example dataset:

```bash
# Train model
python train_model.py \
  -i training_data_extended.csv \
  -o example_model.pkl

# Make predictions (using same data for demo)
python predict.py \
  -m example_model.pkl \
  -i training_data_extended.csv \
  -o example_predictions.csv \
  --sort

# View results
head -10 example_predictions.csv
```

## Understanding the Output

### Training Output

```
MODEL PERFORMANCE METRICS
==================================================
Cross-Validation RMSE: 0.34 ± 0.10
Cross-Validation MAE:  0.27 ± 0.10
Cross-Validation R²:   0.70 ± 0.21

Training RMSE: 0.19
Training MAE:  0.13
Training R²:   0.95
==================================================
```

- **R²**: Proportion of variance explained (higher is better, max 1.0)
- **RMSE**: Root mean square error (lower is better)
- **MAE**: Mean absolute error (average prediction error)
- **CV** metrics are more reliable than training metrics

### Prediction Output

The output CSV contains:
- All original columns
- `predicted_affinity`: ML predictions
- `prediction_std`: Uncertainty estimate (higher = less confident)

Sort by `predicted_affinity` to find the best candidates!

## Tips for Better Models

### 1. Data Quality
- Use consistent experimental data (same assay, conditions)
- Aim for at least 50-100 compounds
- Cover a range of affinities (not all strong/weak binders)

### 2. Feature Selection
- The model automatically selects relevant features
- More features ≠ better (can cause overfitting)
- Use `--compute-descriptors` if you have <20 features

### 3. Model Selection
- **Random Forest**: Good default, fast, robust
- **XGBoost**: Often best performance, may need tuning
- **Gradient Boosting**: Balance between the two

### 4. Avoiding Overfitting
- Check that CV R² ≈ Training R²
- Use more trees (100-300) for complex datasets
- If CV R² << Training R², you may be overfitting

## Troubleshooting

### "Not enough samples for training"
- You need at least 10 compounds
- Recommended: 50-100+ for reliable models

### "RDKit not available"
- You can still use existing descriptors from `score.sh`
- To use `--compute-descriptors`, install RDKit:
  ```bash
  pip install rdkit
  # or
  conda install -c conda-forge rdkit
  ```

### Poor model performance (R² < 0.5)
- Need more training data
- Check data quality (experimental values accurate?)
- Try different model types (-m xgboost)
- Use `--compute-descriptors` for more features

### Predictions seem off
- Make sure prediction input has same features as training
- Check that Vina docking settings are consistent
- Ensure SMILES structures are correct

## Advanced Usage

### Custom Target Column

If your experimental values are in a different column:

```bash
python train_model.py \
  -i data.csv \
  -t pKd_experimental \
  -o model.pkl
```

### Cross-Validation Folds

Adjust cross-validation (default is 5-fold):

```bash
python train_model.py \
  -i data.csv \
  -o model.pkl \
  --cv-folds 10
```

### Using Only Specific Features

Edit your CSV to include only the columns you want, or modify the `select_features` function in `train_model.py`.

## Next Steps

1. Collect more experimental data for your target
2. Integrate predictions into your compound selection workflow
3. Validate top predictions experimentally
4. Retrain model with new data to improve predictions iteratively

## References

- [scikit-learn documentation](https://scikit-learn.org/)
- [RDKit documentation](https://www.rdkit.org/docs/)
- [AutoDock Vina](http://vina.scripps.edu/)

For more details, see the main README.md file.
