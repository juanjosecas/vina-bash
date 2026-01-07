#!/bin/bash
#######################################
# AutoDock Vina Results Post-Processing Script
# Extracts scores and molecular descriptors from docking results
#
# Usage: ./score.sh [OPTIONS]
# Options:
#   -i, --input PATTERN   Input PDBQT pattern (default: out*.pdbqt)
#   -o, --output FILE     Output CSV file (default: scoring.csv)
#   -s, --sorted FILE     Sorted output CSV file (default: scoring_ord.csv)
#   -d, --descriptors LIST Additional descriptors (comma-separated)
#   -k, --keep-mol2       Keep MOL2 files after processing
#   -h, --help            Show this help message
#######################################

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh" || exit 1

# Default values
INPUT_PATTERN="out*.pdbqt"
OUTPUT_CSV="scoring.csv"
SORTED_CSV="scoring_ord.csv"
KEEP_MOL2=false
ADDITIONAL_DESCRIPTORS=""

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
AutoDock Vina Results Post-Processing Script

Usage: $0 [OPTIONS]

Options:
    -i, --input PATTERN        Input PDBQT pattern (default: out*.pdbqt)
    -o, --output FILE          Output CSV file (default: scoring.csv)
    -s, --sorted FILE          Sorted output CSV file (default: scoring_ord.csv)
    -d, --descriptors LIST     Additional descriptors (comma-separated)
    -k, --keep-mol2            Keep MOL2 files after processing
    -h, --help                 Show this help message

Available Descriptors:
    MW, logP, TPSA, MR, HBA1, HBA2, HBD (default)
    Additional: InChI, InChIKey, L5, atoms, bonds, abonds
    
Examples:
    $0
    $0 -i "results/out*.pdbqt" -o my_scores.csv
    $0 --keep-mol2 --descriptors "InChI,L5"

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_PATTERN="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_CSV="$2"
                shift 2
                ;;
            -s|--sorted)
                SORTED_CSV="$2"
                shift 2
                ;;
            -d|--descriptors)
                ADDITIONAL_DESCRIPTORS="$2"
                shift 2
                ;;
            -k|--keep-mol2)
                KEEP_MOL2=true
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
# Extract score from PDBQT file
# Arguments:
#   PDBQT file path
# Returns:
#   Score value (kcal/mol)
#######################################
extract_score() {
    local pdbqt_file=$1
    local filescore=$(sed -n 2p "$pdbqt_file")
    local score=$(echo "$filescore" | awk '{ print $4 }')
    
    if [ -z "$score" ]; then
        warning "Could not extract score from $pdbqt_file"
        echo "N/A"
    else
        echo "$score"
    fi
}

#######################################
# Calculate derived scores
# Arguments:
#   Score in kcal/mol
#   Calculation type (score_j|pkb)
# Returns:
#   Calculated value
#######################################
calculate_derived_score() {
    local score=$1
    local calc_type=$2
    
    if [ "$score" = "N/A" ]; then
        echo "N/A"
        return
    fi
    
    case $calc_type in
        score_j)
            echo "scale=2; ${score}*4182" | bc
            ;;
        pkb)
            echo "scale=2; ${score}*-1.36" | bc
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

#######################################
# Extract molecular descriptor using OpenBabel
# Arguments:
#   MOL2 file path
#   Descriptor name
# Returns:
#   Descriptor value
#######################################
extract_descriptor() {
    local mol2_file=$1
    local descriptor=$2
    
    if [ ! -f "$mol2_file" ]; then
        echo "N/A"
        return
    fi
    
    local value=$(obabel "$mol2_file" -o txt --title "" --append "$descriptor" 2>/dev/null)
    
    if [ -z "$value" ]; then
        echo "N/A"
    else
        echo "$value"
    fi
}

#######################################
# Process a single docking result
# Arguments:
#   PDBQT file path
#######################################
process_result() {
    local pdbqt_file=$1
    local base=$(basename -s .pdbqt "$pdbqt_file")
    local mol2_file="${base}.mol2"
    
    # Convert PDBQT to MOL2 (first pose only)
    if ! obabel -ipdbqt "$pdbqt_file" -omol2 -O "$mol2_file" -l 1 >> "$LOG_FILE" 2>&1; then
        warning "Failed to convert $pdbqt_file to MOL2"
        return 1
    fi
    
    # Extract score
    local score=$(extract_score "$pdbqt_file")
    local score_j=$(calculate_derived_score "$score" "score_j")
    local pkb=$(calculate_derived_score "$score" "pkb")
    
    # Extract molecular descriptors
    local smiles=$(extract_descriptor "$mol2_file" "cansmi")
    local mw=$(extract_descriptor "$mol2_file" "MW")
    local logp=$(extract_descriptor "$mol2_file" "logP")
    local tpsa=$(extract_descriptor "$mol2_file" "TPSA")
    local mr=$(extract_descriptor "$mol2_file" "MR")
    local hba1=$(extract_descriptor "$mol2_file" "HBA1")
    local hba2=$(extract_descriptor "$mol2_file" "HBA2")
    local hbd=$(extract_descriptor "$mol2_file" "HBD")
    local formula=$(extract_descriptor "$mol2_file" "formula")
    
    # Build CSV row
    local csv_row="$pdbqt_file,$mol2_file,$smiles,$score,$score_j,$pkb,$mw,$logp,$tpsa,$mr,$hba1,$hba2,$hbd,$formula"
    
    # Add additional descriptors if specified
    if [ -n "$ADDITIONAL_DESCRIPTORS" ]; then
        IFS=',' read -ra DESCRIPTORS <<< "$ADDITIONAL_DESCRIPTORS"
        for desc in "${DESCRIPTORS[@]}"; do
            local value=$(extract_descriptor "$mol2_file" "$desc")
            csv_row="${csv_row},$value"
        done
    fi
    
    echo "$csv_row" >> "$OUTPUT_CSV"
    
    # Clean up MOL2 file if not keeping
    if [ "$KEEP_MOL2" = false ]; then
        rm -f "$mol2_file"
    fi
    
    return 0
}

#######################################
# Validate configuration
#######################################
validate_config() {
    info "Validating configuration..."
    
    # Check dependencies
    check_dependencies obabel bc sed awk sort
    
    success "Configuration validated"
}

#######################################
# Create CSV header
#######################################
create_csv_header() {
    local header="PDBQT_File,MOL2_File,SMILES,Score_kcal_mol,Score_J_mol,pKb,MW,logP,TPSA,MR,HBA1,HBA2,HBD,Formula"
    
    # Add additional descriptor columns
    if [ -n "$ADDITIONAL_DESCRIPTORS" ]; then
        IFS=',' read -ra DESCRIPTORS <<< "$ADDITIONAL_DESCRIPTORS"
        for desc in "${DESCRIPTORS[@]}"; do
            header="${header},${desc}"
        done
    fi
    
    echo "$header" > "$OUTPUT_CSV"
}

#######################################
# Sort results by score
#######################################
sort_results() {
    info "Sorting results by score..."
    
    # Sort by score column (4th column), numerically
    # Use -g for general numeric sort which handles scientific notation and N/A
    (head -n 1 "$OUTPUT_CSV" && tail -n +2 "$OUTPUT_CSV" | sort -t, -k4 -g) > "$SORTED_CSV"
    
    if [ -f "$SORTED_CSV" ]; then
        success "Sorted results saved to: $SORTED_CSV"
    else
        warning "Failed to create sorted results file"
    fi
}

#######################################
# Main function
#######################################
main() {
    init_log
    info "Starting post-processing of docking results"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate configuration
    validate_config
    
    # Count input files
    local file_count=$(count_files "$INPUT_PATTERN")
    
    if [ "$file_count" -eq 0 ]; then
        error_exit "No result files found matching pattern: $INPUT_PATTERN"
    fi
    
    info "Found $file_count result file(s) to process"
    info "Output CSV: $OUTPUT_CSV"
    
    # Create CSV with header
    create_csv_header
    
    # Process results
    local processed=0
    local failed=0
    local current=0
    
    for pdbqt_file in $INPUT_PATTERN; do
        if [ -f "$pdbqt_file" ]; then
            current=$((current + 1))
            show_progress "$current" "$file_count" "Processing results"
            
            if process_result "$pdbqt_file"; then
                processed=$((processed + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo ""
    
    # Sort results
    sort_results
    
    # Summary
    success "Post-processing completed!"
    info "Successfully processed: $processed/$file_count"
    
    if [ "$failed" -gt 0 ]; then
        warning "Failed: $failed/$file_count"
    fi
    
    if [ "$KEEP_MOL2" = true ]; then
        info "MOL2 files kept in current directory"
    else
        info "MOL2 files cleaned up"
    fi
    
    info "Results saved in: $OUTPUT_CSV"
    info "Sorted results saved in: $SORTED_CSV"
    info "Log file: $LOG_FILE"
}

# Run main function
main "$@"
