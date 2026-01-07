#!/bin/bash
#######################################
# AutoDock Vina Batch Docking Script
# Performs molecular docking for multiple ligands
#
# Usage: ./vina.sh [OPTIONS]
# Options:
#   -c, --config FILE    Configuration file (default: config.txt)
#   -p, --pattern PATTERN Ligand file pattern (default: lig*.pdbqt)
#   -o, --output DIR     Output directory (default: current directory)
#   -j, --jobs NUM       Number of parallel jobs (default: 1)
#   -h, --help           Show this help message
#######################################

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh" || exit 1

# Default values
CONFIG_FILE="config.txt"
LIGAND_PATTERN="lig*.pdbqt"
OUTPUT_DIR="."
PARALLEL_JOBS=1

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
AutoDock Vina Batch Docking Script

Usage: $0 [OPTIONS]

Options:
    -c, --config FILE       Configuration file (default: config.txt)
    -p, --pattern PATTERN   Ligand file pattern (default: lig*.pdbqt)
    -o, --output DIR        Output directory (default: current directory)
    -j, --jobs NUM          Number of parallel jobs (default: 1)
    -h, --help              Show this help message

Examples:
    $0
    $0 -c my_config.txt -p "ligand*.pdbqt"
    $0 --config config.txt --jobs 4 --output results/

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -p|--pattern)
                LIGAND_PATTERN="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
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
# Validate configuration
#######################################
validate_config() {
    info "Validating configuration..."
    
    # Check dependencies
    check_dependencies vina
    
    # Check config file
    check_file "$CONFIG_FILE"
    
    # Create output directory
    ensure_directory "$OUTPUT_DIR"
    
    # Validate parallel jobs number
    if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [ "$PARALLEL_JOBS" -lt 1 ]; then
        error_exit "Invalid number of parallel jobs: $PARALLEL_JOBS"
    fi
    
    success "Configuration validated"
}

#######################################
# Run docking for a single ligand
# Arguments:
#   Ligand file path
#######################################
run_docking() {
    local ligand_file=$1
    local base=$(basename -s .pdbqt "$ligand_file")
    local output_file="${OUTPUT_DIR}/out_${base}.pdbqt"
    
    # Validate ligand file
    if ! validate_pdbqt "$ligand_file"; then
        warning "Invalid PDBQT file: $ligand_file (skipping)"
        return 1
    fi
    
    info "Docking: $ligand_file"
    
    # Run Vina
    if vina --config "$CONFIG_FILE" --ligand "$ligand_file" --out "$output_file" >> "$LOG_FILE" 2>&1; then
        success "Completed: $ligand_file -> $output_file"
        return 0
    else
        warning "Failed: $ligand_file"
        return 1
    fi
}

#######################################
# Main function
#######################################
main() {
    init_log
    info "Starting AutoDock Vina batch docking"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate configuration
    validate_config
    
    # Count ligands
    local ligand_count=$(count_files "$LIGAND_PATTERN")
    
    if [ "$ligand_count" -eq 0 ]; then
        error_exit "No ligand files found matching pattern: $LIGAND_PATTERN"
    fi
    
    info "Found $ligand_count ligand file(s) to process"
    info "Configuration file: $CONFIG_FILE"
    info "Output directory: $OUTPUT_DIR"
    info "Parallel jobs: $PARALLEL_JOBS"
    
    # Process ligands
    local processed=0
    local failed=0
    local current=0
    
    if [ "$PARALLEL_JOBS" -eq 1 ]; then
        # Sequential processing
        for ligand_file in $LIGAND_PATTERN; do
            if [ -f "$ligand_file" ]; then
                current=$((current + 1))
                show_progress "$current" "$ligand_count" "Processing ligands"
                
                if run_docking "$ligand_file"; then
                    processed=$((processed + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        done
    else
        # Parallel processing
        info "Processing ligands in parallel (jobs: $PARALLEL_JOBS)"
        local job_count=0
        
        for ligand_file in $LIGAND_PATTERN; do
            if [ -f "$ligand_file" ]; then
                run_docking "$ligand_file" &
                job_count=$((job_count + 1))
                
                # Wait if max parallel jobs reached
                if [ "$job_count" -ge "$PARALLEL_JOBS" ]; then
                    wait -n
                    job_count=$((job_count - 1))
                fi
                
                current=$((current + 1))
                show_progress "$current" "$ligand_count" "Submitting jobs"
            fi
        done
        
        # Wait for remaining jobs
        wait
        
        # Count results
        for ligand_file in $LIGAND_PATTERN; do
            if [ -f "$ligand_file" ]; then
                local base=$(basename -s .pdbqt "$ligand_file")
                local output_file="${OUTPUT_DIR}/out_${base}.pdbqt"
                if [ -f "$output_file" ]; then
                    processed=$((processed + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        done
    fi
    
    # Summary
    echo ""
    success "Docking completed!"
    info "Successfully processed: $processed/$ligand_count"
    
    if [ "$failed" -gt 0 ]; then
        warning "Failed: $failed/$ligand_count"
    fi
    
    info "Results saved in: $OUTPUT_DIR"
    info "Log file: $LOG_FILE"
}

# Run main function
main "$@"

