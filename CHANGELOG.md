# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-01-07

### Added

#### New Scripts
- **utils.sh**: Comprehensive utility library with error handling, logging, and validation functions
- **vina_pipeline.sh**: Complete automated workflow pipeline for docking and post-processing
- **filter_results.sh**: Advanced result filtering with score thresholds and Lipinski Rule of Five
- **generate_summary.sh**: Statistical summary and analysis report generation
- **convert_format.sh**: Molecular structure format conversion utility

#### Features
- Command-line argument parsing for all scripts with flexible options
- Colored logging system (INFO, WARNING, ERROR, SUCCESS) with timestamps
- Real-time progress bars for long-running operations
- Comprehensive error handling and validation throughout
- Parallel processing support in vina.sh (multi-core execution)
- Dependency checking at script startup
- Configuration file validation
- Support for additional molecular descriptors
- Option to keep or clean intermediate MOL2 files
- Lipinski Rule of Five compliance checking
- Multiple output formats and sorting options

#### Documentation
- Comprehensive README.md with usage examples and detailed documentation
- QUICKSTART.md for new users
- config.txt.example as a template configuration file
- Inline documentation for all functions
- Help messages for all scripts (`--help` flag)
- CHANGELOG.md for tracking changes

#### Quality Improvements
- .gitignore file to exclude output files and logs
- Modular function-based architecture
- Proper file and directory management
- Improved CSV formatting (no extra spaces)
- Better handling of N/A values in sorting and calculations
- Optimized numeric comparisons using awk instead of bc

### Changed

#### vina.sh
- Complete refactor with function-based structure
- Added command-line options: `--config`, `--pattern`, `--output`, `--jobs`, `--help`
- Added parallel execution capability
- Added progress tracking
- Improved error handling
- Added configuration validation
- Added logging to file

#### score.sh
- Complete refactor with modular functions
- Added command-line options: `--input`, `--output`, `--sorted`, `--descriptors`, `--keep-mol2`, `--help`
- Improved CSV header formatting (no spaces, underscore-separated)
- Better error handling for conversion failures
- Added progress tracking
- Support for additional custom descriptors
- Option to keep MOL2 files
- Improved score extraction with error checking
- Fixed sorting to handle N/A values properly

### Technical Details

#### Architecture Improvements
- Separated concerns with utility library
- Consistent error handling patterns across all scripts
- Proper POSIX-compliant bash scripting
- Functions with clear input/output contracts
- Local variable scoping
- Proper quoting and expansion

#### Performance Improvements
- Parallel processing support reduces runtime significantly
- Optimized numeric comparisons (awk vs bc)
- Efficient file counting and pattern matching
- Progress tracking without performance penalty

#### Robustness Improvements
- Dependency checking before execution
- File validation before processing
- Proper error messages and exit codes
- Graceful handling of missing or invalid data
- Log file for debugging and audit trail

### Backward Compatibility

The enhanced scripts maintain backward compatibility:
- Running `./vina.sh` without arguments works as before (with default patterns)
- Running `./score.sh` without arguments works as before (with default patterns)
- All original functionality is preserved
- New features are opt-in via command-line flags

### Migration Guide

For users of the original scripts:

1. **No changes required** if you were using the scripts without arguments
2. **To use new features**, add optional flags:
   - Parallel processing: `./vina.sh --jobs 4`
   - Custom output: `./vina.sh --output results/`
   - Keep MOL2 files: `./score.sh --keep-mol2`
3. **New workflow available**: Use `./vina_pipeline.sh` for complete automation

### File Structure

```
vina-bash/
├── README.md                 # Comprehensive documentation
├── QUICKSTART.md            # Quick start guide
├── CHANGELOG.md             # This file
├── LICENSE                  # Apache 2.0 license
├── .gitignore              # Git ignore patterns
├── config.txt.example      # Example configuration
├── utils.sh                # Utility function library
├── vina.sh                 # Enhanced docking script
├── score.sh                # Enhanced scoring script
├── filter_results.sh       # Result filtering
├── generate_summary.sh     # Summary reports
├── convert_format.sh       # Format conversion
└── vina_pipeline.sh        # Complete pipeline
```

## [1.0.0] - Original Release

### Original Features
- Basic batch docking with vina.sh
- Basic post-processing with score.sh
- Molecular descriptor calculation
- Simple CSV output

---

## Version History

- **2.0.0** (2026-01-07): Major refactor with automation tools and improved structure
- **1.0.0**: Initial release with basic docking and scoring functionality
