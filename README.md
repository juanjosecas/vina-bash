# vina-bash

A comprehensive bash toolkit for AutoDock Vina molecular docking automation and post-processing.

## Overview

This repository provides a complete pipeline for running AutoDock Vina molecular docking simulations with automated post-processing, molecular descriptor calculation, result filtering, and reporting capabilities.

## Features

- **Automated Batch Docking**: Run Vina on multiple ligands with parallel processing support
- **Post-Processing**: Extract binding scores and calculate molecular descriptors
- **Result Filtering**: Filter top results based on scores and drug-likeness criteria
- **Format Conversion**: Convert between different molecular structure formats
- **Summary Reports**: Generate comprehensive analysis reports
- **Complete Pipeline**: Run the entire workflow with a single command
- **Robust Error Handling**: Comprehensive validation and logging
- **Progress Tracking**: Real-time progress bars and status updates

## Requirements

- [AutoDock Vina](http://vina.scripps.edu/)
- [OpenBabel](http://openbabel.org/)
- bash (4.0+)
- bc (for calculations)
- Standard Unix utilities (sed, awk, sort, grep)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/juanjosecas/vina-bash.git
cd vina-bash
```

2. Make scripts executable (if not already):
```bash
chmod +x *.sh
```

3. Ensure AutoDock Vina and OpenBabel are installed and in your PATH

## Scripts

### 1. vina.sh - Batch Docking

Runs AutoDock Vina on multiple ligands.

**Usage:**
```bash
./vina.sh [OPTIONS]
```

**Options:**
- `-c, --config FILE`: Configuration file (default: config.txt)
- `-p, --pattern PATTERN`: Ligand file pattern (default: lig*.pdbqt)
- `-o, --output DIR`: Output directory (default: current directory)
- `-j, --jobs NUM`: Number of parallel jobs (default: 1)
- `-h, --help`: Show help message

**Examples:**
```bash
# Basic usage
./vina.sh

# Custom configuration with parallel processing
./vina.sh -c my_config.txt -j 4

# Process specific ligands
./vina.sh -p "compound*.pdbqt" -o results/
```

### 2. score.sh - Post-Processing

Extracts docking scores and calculates molecular descriptors.

**Usage:**
```bash
./score.sh [OPTIONS]
```

**Options:**
- `-i, --input PATTERN`: Input PDBQT pattern (default: out*.pdbqt)
- `-o, --output FILE`: Output CSV file (default: scoring.csv)
- `-s, --sorted FILE`: Sorted output CSV file (default: scoring_ord.csv)
- `-d, --descriptors LIST`: Additional descriptors (comma-separated)
- `-k, --keep-mol2`: Keep MOL2 files after processing
- `-h, --help`: Show help message

**Calculated Properties:**
- Binding scores (kcal/mol, J/mol)
- pKb estimation
- Molecular weight (MW)
- LogP (octanol/water partition coefficient)
- TPSA (topological polar surface area)
- Molar refractivity (MR)
- Hydrogen bond acceptors/donors (HBA1, HBA2, HBD)
- SMILES and molecular formula

**Examples:**
```bash
# Basic usage
./score.sh

# Process specific results with additional descriptors
./score.sh -i "docking_out*.pdbqt" -d "InChI,L5"

# Keep MOL2 files
./score.sh --keep-mol2
```

### 3. filter_results.sh - Result Filtering

Filters results based on various criteria.

**Usage:**
```bash
./filter_results.sh [OPTIONS]
```

**Options:**
- `-i, --input FILE`: Input CSV file (default: scoring_ord.csv)
- `-o, --output FILE`: Output CSV file (default: filtered_results.csv)
- `-n, --top NUM`: Extract top N results (default: 10)
- `-t, --threshold SCORE`: Filter by score threshold (kcal/mol)
- `-l, --lipinski`: Apply Lipinski Rule of Five filter
- `-h, --help`: Show help message

**Examples:**
```bash
# Get top 20 results
./filter_results.sh --top 20

# Filter by score threshold
./filter_results.sh --threshold -8.0

# Apply drug-likeness filter
./filter_results.sh --lipinski --top 50
```

### 4. generate_summary.sh - Summary Reports

Generates comprehensive analysis reports.

**Usage:**
```bash
./generate_summary.sh [OPTIONS]
```

**Options:**
- `-i, --input FILE`: Input CSV file (default: scoring_ord.csv)
- `-o, --output FILE`: Output report file (default: summary_report.txt)
- `-h, --help`: Show help message

**Report Contents:**
- Overview statistics
- Top results
- Score distribution
- Molecular property statistics
- Lipinski Rule of Five compliance

**Example:**
```bash
./generate_summary.sh -i my_scores.csv -o my_report.txt
```

### 5. convert_format.sh - Format Conversion

Converts molecular structures between formats.

**Usage:**
```bash
./convert_format.sh -i FORMAT -o FORMAT -p PATTERN [OPTIONS]
```

**Options:**
- `-i, --input FORMAT`: Input format
- `-o, --output FORMAT`: Output format
- `-p, --pattern PATTERN`: Input file pattern
- `-d, --output-dir DIR`: Output directory (default: converted)
- `-a, --all-poses`: Convert all poses (default: first pose only)
- `-h, --help`: Show help message

**Supported Formats:**
pdbqt, mol2, pdb, sdf, mol, xyz, smiles, inchi, and more

**Examples:**
```bash
# Convert PDBQT to MOL2
./convert_format.sh -i pdbqt -o mol2 -p "*.pdbqt"

# Convert all poses to SDF
./convert_format.sh -i pdbqt -o sdf -p "out*.pdbqt" --all-poses
```

### 6. vina_pipeline.sh - Complete Pipeline

Runs the complete docking and analysis workflow.

**Usage:**
```bash
./vina_pipeline.sh [OPTIONS]
```

**Options:**
- `-c, --config FILE`: Configuration file (default: config.txt)
- `-p, --pattern PATTERN`: Ligand file pattern (default: lig*.pdbqt)
- `-o, --output DIR`: Output directory (default: results)
- `-j, --jobs NUM`: Number of parallel jobs (default: 1)
- `-k, --keep-mol2`: Keep MOL2 files after processing
- `-n, --top NUM`: Number of top results to filter (default: 10)
- `--no-report`: Skip summary report generation
- `-h, --help`: Show help message

**Pipeline Steps:**
1. Molecular docking with Vina
2. Post-processing and scoring
3. Result filtering
4. Summary report generation

**Example:**
```bash
# Run complete pipeline
./vina_pipeline.sh -c config.txt --jobs 4 --top 20
```

## Typical Workflow

1. **Prepare your files:**
   - Receptor PDBQT file
   - Ligand PDBQT files (lig*.pdbqt)
   - Vina configuration file (config.txt)

2. **Run the complete pipeline:**
   ```bash
   ./vina_pipeline.sh --jobs 4 --top 20
   ```

3. **Or run steps individually:**
   ```bash
   # Step 1: Docking
   ./vina.sh -j 4 -o results/
   
   # Step 2: Post-processing
   ./score.sh -i "results/out*.pdbqt" -o results/scoring.csv
   
   # Step 3: Filter results
   ./filter_results.sh -i results/scoring_ord.csv --top 20 --lipinski
   
   # Step 4: Generate report
   ./generate_summary.sh -i results/scoring_ord.csv -o results/report.txt
   ```

## Output Files

- **out_*.pdbqt**: Docking output files with all poses
- **scoring.csv**: Complete results with scores and descriptors
- **scoring_ord.csv**: Results sorted by binding score (best first)
- **top_results.csv**: Filtered top results
- **summary_report.txt**: Comprehensive analysis report
- **vina_pipeline.log**: Execution log with timestamps
- ***.mol2**: Converted MOL2 files (if --keep-mol2 is used)

## Configuration File (config.txt)

Example Vina configuration file:
```
receptor = receptor.pdbqt
center_x = 25.0
center_y = 30.0
center_z = 10.0
size_x = 20
size_y = 20
size_z = 20
exhaustiveness = 8
num_modes = 9
energy_range = 3
```

## Utilities Library (utils.sh)

The `utils.sh` library provides common functionality:
- Error handling and validation
- Colored logging (INFO, WARNING, ERROR, SUCCESS)
- Progress bars
- Dependency checking
- File validation
- Directory management

All scripts automatically source this library for consistent behavior.

## Tips and Best Practices

1. **Parallel Processing**: Use `-j` option to speed up docking on multi-core systems
2. **Memory Management**: For large datasets, process in batches
3. **Quality Control**: Review the log file for warnings or errors
4. **Validation**: Always validate your input files before running
5. **Reproducibility**: Keep your config files versioned for reproducibility

## Troubleshooting

**Problem**: Scripts fail with "command not found"
- **Solution**: Ensure AutoDock Vina and OpenBabel are in your PATH

**Problem**: "Permission denied" errors
- **Solution**: Run `chmod +x *.sh` to make scripts executable

**Problem**: No ligands found
- **Solution**: Check your ligand file pattern and ensure files exist

**Problem**: Score extraction fails
- **Solution**: Verify PDBQT output files contain valid docking results

## Machine Learning Model Training

### Overview

In addition to traditional docking workflows, this repository now includes machine learning capabilities to train predictive models that combine Vina docking scores with 2D and 3D molecular descriptors to improve binding affinity predictions.

**For a complete tutorial, see [ML_QUICKSTART.md](ML_QUICKSTART.md)**

### Why Use Machine Learning?

While AutoDock Vina provides excellent docking scores, machine learning models can:
- Correct systematic biases in docking scores
- Incorporate additional molecular properties (lipophilicity, shape, flexibility)
- Learn from experimental data to improve predictions
- Provide confidence estimates for predictions

### Requirements

Install Python dependencies:
```bash
pip install -r requirements.txt
```

Key dependencies:
- scikit-learn: Machine learning algorithms
- xgboost: Gradient boosting (optional)
- rdkit: Molecular descriptor calculation
- pandas/numpy: Data manipulation

### 7. train_model.py - Model Training

Train a machine learning model using experimental binding affinity data.

**Usage:**
```bash
python train_model.py -i training_data.csv -o model.pkl [OPTIONS]
```

**Options:**
- `-i, --input FILE`: Input CSV with training data (required)
- `-o, --output FILE`: Output model file (default: binding_affinity_model.pkl)
- `-t, --target COL`: Target column name (default: experimental_affinity)
- `-m, --model-type TYPE`: Model type (random_forest, gradient_boosting, xgboost)
- `-n, --n-estimators NUM`: Number of trees (default: 100)
- `-c, --compute-descriptors`: Compute descriptors from SMILES
- `--cv-folds NUM`: Cross-validation folds (default: 5)
- `--no-plots`: Skip generating plots
- `--random-state NUM`: Random seed (default: 42)

**Input CSV Format:**

Your training CSV must contain:
- `experimental_affinity`: Experimental binding values (pKd, pKi, ΔG, etc.)
- `SMILES`: Molecular structure (for descriptor computation)
- `Score_kcal_mol`: Vina docking score (optional)
- Other descriptors from `score.sh` output (MW, logP, TPSA, etc.)

**Example:**
```csv
PDBQT_File,SMILES,Score_kcal_mol,MW,logP,TPSA,experimental_affinity
out_lig1.pdbqt,CCO,-7.5,46.07,0.01,20.23,-7.8
out_lig2.pdbqt,CC(C)O,-8.2,60.10,0.14,20.23,-8.5
```

**Examples:**
```bash
# Basic training with existing descriptors
python train_model.py -i training_data.csv -o my_model.pkl

# Train with computed 2D/3D descriptors
python train_model.py -i training_data.csv -o my_model.pkl --compute-descriptors

# Use XGBoost with 200 trees
python train_model.py -i training_data.csv -m xgboost -n 200

# Custom target column name
python train_model.py -i data.csv -t pKd_experimental
```

**Output Files:**
- `model.pkl`: Trained model
- `model_metrics.json`: Performance metrics
- `model_feature_importance.png`: Feature importance plot
- `model_predictions.png`: Predicted vs actual plot

### 8. predict.py - Making Predictions

Use a trained model to predict binding affinities for new compounds.

**Usage:**
```bash
python predict.py -m model.pkl -i input.csv -o predictions.csv [OPTIONS]
```

**Options:**
- `-m, --model FILE`: Trained model file (required)
- `-i, --input FILE`: Input CSV with molecular data (required)
- `-o, --output FILE`: Output CSV with predictions (default: predictions.csv)
- `-c, --compute-descriptors`: Compute descriptors from SMILES
- `--sort`: Sort results by predicted affinity

**Examples:**
```bash
# Basic prediction
python predict.py -m my_model.pkl -i new_compounds.csv -o results.csv

# Predict with descriptor computation and sorting
python predict.py -m my_model.pkl -i compounds.csv --compute-descriptors --sort

# Use with Vina docking results
./score.sh -i "out*.pdbqt"  # Generate descriptors
python predict.py -m my_model.pkl -i scoring.csv -o enhanced_predictions.csv
```

**Output:**

The output CSV includes:
- All original columns from input
- `predicted_affinity`: ML-predicted binding affinity
- `prediction_std`: Uncertainty estimate (for ensemble models)

### Complete ML Workflow Example

**Step 1: Prepare Training Data**

Collect experimental binding affinity data for your target protein. This could be from:
- Your own experiments
- Public databases (ChEMBL, BindingDB, PDBbind)
- Literature sources

Format as CSV with required columns (see example above).

**Step 2: Generate Descriptors**

If you don't have descriptors yet, run docking and post-processing:
```bash
# Run docking pipeline
./vina_pipeline.sh --jobs 4

# This creates scoring_ord.csv with Vina scores and descriptors
```

**Step 3: Add Experimental Values**

Add your experimental binding affinity values to the CSV:
```bash
# Edit scoring_ord.csv to add experimental_affinity column
# Or merge with your experimental data
```

**Step 4: Train Model**

```bash
# Train model with computed 2D/3D descriptors
python train_model.py \
  -i training_data.csv \
  -o my_target_model.pkl \
  -m xgboost \
  -n 200 \
  --compute-descriptors

# Review output metrics and plots
cat my_target_model_metrics.json
```

**Step 5: Make Predictions**

```bash
# Predict binding affinities for new compounds
python predict.py \
  -m my_target_model.pkl \
  -i scoring_ord.csv \
  -o enhanced_predictions.csv \
  --compute-descriptors \
  --sort

# Best predicted binders are now at the top
head enhanced_predictions.csv
```

### Model Features

The ML models can use these features:

**Vina Scoring:**
- Score_kcal_mol: Binding energy
- Score_J_mol: Energy in Joules
- pKb: Estimated binding constant

**2D Descriptors:**
- MW: Molecular weight
- LogP: Lipophilicity
- TPSA: Topological polar surface area
- HBA/HBD: Hydrogen bond acceptors/donors
- RotatableBonds: Molecular flexibility
- AromaticRings: Aromaticity
- MolMR: Molar refractivity

**3D Descriptors (computed from SMILES):**
- InertialShapeFactor: Molecular shape
- Eccentricity: Shape elongation
- Asphericity: Deviation from sphere
- RadiusOfGyration: Molecular size
- PMI1/PMI2/PMI3: Principal moments of inertia
- NPR1/NPR2: Normalized principal ratios

### Tips for Model Training

1. **Data Quality**: Use high-quality experimental data from the same assay type
2. **Sample Size**: Aim for at least 50-100 compounds for training
3. **Feature Selection**: The model automatically selects relevant features
4. **Cross-Validation**: Use CV metrics (not training metrics) to assess performance
5. **Descriptor Computation**: Use `--compute-descriptors` for additional 3D features
6. **Model Choice**: 
   - Random Forest: Good default, robust to overfitting
   - XGBoost: Often better performance, requires tuning
   - Gradient Boosting: Balance between the two

### Interpreting Results

**R² (Coefficient of Determination):**
- 1.0 = Perfect predictions
- 0.8-0.9 = Excellent model
- 0.6-0.8 = Good model
- <0.6 = May need more data or features

**RMSE (Root Mean Square Error):**
- Lower is better
- Compare to the range of your target values
- Should be similar between CV and training sets

**MAE (Mean Absolute Error):**
- Average prediction error
- More interpretable than RMSE
- In the same units as your target variable

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

Apache License 2.0 - See LICENSE file for details

## Author

Juan José Cas

## References

- [AutoDock Vina](http://vina.scripps.edu/)
- [OpenBabel](http://openbabel.org/)
- [RDKit](https://www.rdkit.org/)
- [scikit-learn](https://scikit-learn.org/)
- Lipinski's Rule of Five for drug-likeness assessment