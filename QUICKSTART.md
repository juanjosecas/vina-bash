# Quick Start Guide

This guide will help you get started with vina-bash for molecular docking workflows.

## Prerequisites

Before using vina-bash, ensure you have:

1. **AutoDock Vina** installed and in your PATH
   ```bash
   vina --help  # Should work without errors
   ```

2. **OpenBabel** installed and in your PATH
   ```bash
   obabel --help  # Should work without errors
   ```

3. **Standard Unix utilities**: bash, bc, sed, awk, sort (usually pre-installed)

## Quick Start

### 1. Prepare Your Files

You need three types of files:

1. **Receptor file** (e.g., `receptor.pdbqt`) - Your target protein
2. **Ligand files** (e.g., `lig1.pdbqt`, `lig2.pdbqt`, etc.) - Molecules to dock
3. **Configuration file** (`config.txt`) - Docking parameters

#### Create Configuration File

Copy the example:
```bash
cp config.txt.example config.txt
```

Edit `config.txt` to specify:
- Path to receptor file
- Search box center coordinates (x, y, z)
- Search box size (x, y, z dimensions in Angstroms)
- Optional: exhaustiveness, number of modes, etc.

Example:
```
receptor = receptor.pdbqt
center_x = 25.0
center_y = 30.0
center_z = 10.0
size_x = 20
size_y = 20
size_z = 20
exhaustiveness = 8
```

### 2. Run the Complete Pipeline

The easiest way to run everything:

```bash
./vina_pipeline.sh --jobs 4 --top 20
```

This will:
1. Dock all ligands matching `lig*.pdbqt`
2. Calculate molecular descriptors
3. Filter top 20 results
4. Generate summary report

All results will be in the `results/` directory.

### 3. Or Run Steps Individually

#### Step 1: Docking

```bash
./vina.sh --config config.txt --jobs 4 --output results/
```

This runs AutoDock Vina on all ligands in parallel (4 jobs).

#### Step 2: Post-Processing

```bash
./score.sh --input "results/out*.pdbqt" --output results/scoring.csv
```

This extracts scores and calculates molecular descriptors.

#### Step 3: Filter Results

```bash
./filter_results.sh --input results/scoring_ord.csv --top 20 --lipinski
```

This filters the top 20 drug-like compounds.

#### Step 4: Generate Report

```bash
./generate_summary.sh --input results/scoring_ord.csv --output results/report.txt
```

This creates a statistical summary of all results.

## Common Workflows

### Workflow 1: Screen a Library

```bash
# Place all ligands as lig*.pdbqt
# Run complete pipeline with parallel processing
./vina_pipeline.sh -c config.txt -j 8 -o screening_results/ -n 50
```

### Workflow 2: Re-process Existing Results

```bash
# If you already have out*.pdbqt files
./score.sh -i "out*.pdbqt" --keep-mol2
./filter_results.sh --top 10 --threshold -8.0
./generate_summary.sh
```

### Workflow 3: Custom Descriptors

```bash
# Calculate additional molecular descriptors
./score.sh --descriptors "InChI,InChIKey,L5,atoms,bonds"
```

### Workflow 4: Convert Formats

```bash
# Convert all docking results to MOL2
./convert_format.sh -i pdbqt -o mol2 -p "out*.pdbqt" -d mol2_files/

# Convert to SDF with all poses
./convert_format.sh -i pdbqt -o sdf -p "out*.pdbqt" --all-poses
```

## Understanding Results

### Output Files

After running the pipeline, you'll find:

- **results/out_*.pdbqt** - Docking outputs with multiple poses
- **results/scoring.csv** - Complete results with all descriptors
- **results/scoring_ord.csv** - Results sorted by score (best first)
- **results/top_results.csv** - Filtered top results
- **results/summary_report.txt** - Statistical analysis
- **vina_pipeline.log** - Execution log

### Reading the CSV

The CSV contains:
- **Score_kcal_mol**: Binding affinity (more negative = better)
- **MW**: Molecular weight
- **logP**: Lipophilicity
- **TPSA**: Polar surface area
- **HBA/HBD**: H-bond acceptors/donors
- **Formula**: Molecular formula

### Interpreting Scores

- Scores are in kcal/mol
- More negative = stronger binding (better)
- Typical good scores: -8 to -12 kcal/mol
- Excellent scores: < -10 kcal/mol

### Lipinski Rule of Five

Drug-like compounds should have:
- MW ≤ 500 Da
- logP ≤ 5
- HBD ≤ 5
- HBA ≤ 10

Use `--lipinski` flag to filter by these criteria.

## Troubleshooting

### Problem: "Command not found: vina"
**Solution**: Install AutoDock Vina and add to PATH

### Problem: "Command not found: obabel"
**Solution**: Install OpenBabel and add to PATH

### Problem: No ligands found
**Solution**: Check ligand file pattern matches your files (default: `lig*.pdbqt`)

### Problem: Docking fails
**Solution**: 
1. Check config.txt is valid
2. Verify receptor.pdbqt exists
3. Check ligand files are valid PDBQT format
4. Review vina_pipeline.log for errors

### Problem: Score extraction fails
**Solution**: Verify docking completed successfully and out*.pdbqt files are valid

### Problem: Slow performance
**Solution**: Use parallel processing with `-j` flag (e.g., `-j 4` for 4 cores)

## Tips for Best Results

1. **Determine search box carefully**: Visualize your receptor in PyMOL or Chimera to find the binding site coordinates

2. **Use appropriate exhaustiveness**: 
   - Default (8) for quick screens
   - 16-32 for final docking

3. **Process in batches**: For very large libraries (1000+ compounds), process in batches to manage resources

4. **Validate top hits**: Always visually inspect top-scoring compounds

5. **Keep logs**: The log file helps troubleshoot issues

## Advanced Usage

### Parallel Processing

Maximum speedup with multi-core:
```bash
./vina_pipeline.sh --jobs $(nproc)  # Use all CPU cores
```

### Custom Filtering

Combine multiple filters:
```bash
./filter_results.sh --top 100 --threshold -7.0 --lipinski
```

### Batch Processing

Process multiple sets:
```bash
for dir in set1 set2 set3; do
  cd $dir
  ../vina_pipeline.sh -o results/
  cd ..
done
```

## Next Steps

1. Analyze top results in visualization software (PyMOL, Chimera, etc.)
2. Validate binding modes
3. Consider molecular dynamics for top hits
4. Plan experimental validation

## Getting Help

- Run any script with `--help` for detailed options
- Check the log file for error messages
- Review README.md for complete documentation

## Example Session

```bash
# Setup
cp config.txt.example config.txt
# Edit config.txt with your parameters

# Quick test with one ligand
./vina.sh -p "lig1.pdbqt" -o test/

# Full run
./vina_pipeline.sh -j 4 -n 50 -o screening_results/

# View results
cat screening_results/summary_report.txt
head -20 screening_results/scoring_ord.csv

# Analyze top hit
cat screening_results/top_results.csv
```

That's it! You're ready to start docking!
