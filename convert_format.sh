#!/bin/bash
#######################################
# Format Conversion Utility
# Converts molecular structures between different formats
#
# Usage: ./convert_format.sh [OPTIONS]
#######################################

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh" || exit 1

# Default values
INPUT_FORMAT=""
OUTPUT_FORMAT=""
INPUT_PATTERN=""
OUTPUT_DIR="converted"
ALL_POSES=false

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
Format Conversion Utility

Converts molecular structure files between formats using OpenBabel.

Usage: $0 -i FORMAT -o FORMAT -p PATTERN [OPTIONS]

Required Options:
    -i, --input FORMAT      Input format (pdbqt, mol2, pdb, sdf, mol, etc.)
    -o, --output FORMAT     Output format (pdbqt, mol2, pdb, sdf, mol, etc.)
    -p, --pattern PATTERN   Input file pattern (e.g., "*.pdbqt")

Optional:
    -d, --output-dir DIR    Output directory (default: converted)
    -a, --all-poses         Convert all poses (default: first pose only)
    -h, --help              Show this help message

Supported Formats:
    pdbqt, mol2, pdb, sdf, mol, xyz, smiles, inchi, and many more

Examples:
    $0 -i pdbqt -o mol2 -p "out*.pdbqt"
    $0 -i pdbqt -o sdf -p "*.pdbqt" --all-poses
    $0 -i mol2 -o pdb -p "*.mol2" -d pdb_files

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -p|--pattern)
                INPUT_PATTERN="$2"
                shift 2
                ;;
            -d|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -a|--all-poses)
                ALL_POSES=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
}

#######################################
# Validate arguments
#######################################
validate_arguments() {
    if [ -z "$INPUT_FORMAT" ]; then
        error_exit "Input format is required. Use -i or --input."
    fi
    
    if [ -z "$OUTPUT_FORMAT" ]; then
        error_exit "Output format is required. Use -o or --output."
    fi
    
    if [ -z "$INPUT_PATTERN" ]; then
        error_exit "Input pattern is required. Use -p or --pattern."
    fi
    
    # Check dependencies
    check_dependencies obabel
}

#######################################
# Convert a single file
# Arguments:
#   Input file path
#######################################
convert_file() {
    local input_file=$1
    local base=$(basename -s ".${INPUT_FORMAT}" "$input_file")
    local output_file="${OUTPUT_DIR}/${base}.${OUTPUT_FORMAT}"
    
    # Build obabel command
    local cmd="obabel -i${INPUT_FORMAT} ${input_file} -o${OUTPUT_FORMAT} -O ${output_file}"
    
    # Add options
    if [ "$ALL_POSES" = false ]; then
        cmd="$cmd -l 1"
    fi
    
    # Execute conversion
    if $cmd >> "$LOG_FILE" 2>&1; then
        success "Converted: $input_file -> $output_file"
        return 0
    else
        warning "Failed to convert: $input_file"
        return 1
    fi
}

#######################################
# Main function
#######################################
main() {
    init_log
    info "Starting format conversion"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate
    validate_arguments
    
    # Create output directory
    ensure_directory "$OUTPUT_DIR"
    
    # Count input files
    local file_count=$(count_files "$INPUT_PATTERN")
    
    if [ "$file_count" -eq 0 ]; then
        error_exit "No files found matching pattern: $INPUT_PATTERN"
    fi
    
    info "Found $file_count file(s) to convert"
    info "Input format: $INPUT_FORMAT"
    info "Output format: $OUTPUT_FORMAT"
    info "Output directory: $OUTPUT_DIR"
    
    if [ "$ALL_POSES" = true ]; then
        info "Converting all poses"
    else
        info "Converting first pose only"
    fi
    
    echo ""
    
    # Convert files
    local converted=0
    local failed=0
    local current=0
    
    for input_file in $INPUT_PATTERN; do
        if [ -f "$input_file" ]; then
            current=$((current + 1))
            show_progress "$current" "$file_count" "Converting files"
            
            if convert_file "$input_file"; then
                converted=$((converted + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo ""
    
    # Summary
    success "Conversion completed!"
    info "Successfully converted: $converted/$file_count"
    
    if [ "$failed" -gt 0 ]; then
        warning "Failed: $failed/$file_count"
    fi
    
    info "Converted files saved in: $OUTPUT_DIR"
}

# Run main function
main "$@"
