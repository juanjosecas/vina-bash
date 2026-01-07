#!/bin/bash
#######################################
# Complete Vina Pipeline
# Runs the complete docking and post-processing workflow
#
# Usage: ./vina_pipeline.sh [OPTIONS]
#######################################

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh" || exit 1

# Default values
CONFIG_FILE="config.txt"
LIGAND_PATTERN="lig*.pdbqt"
OUTPUT_DIR="results"
PARALLEL_JOBS=1
KEEP_MOL2=false
GENERATE_REPORT=true
FILTER_TOP=10

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
Complete AutoDock Vina Pipeline

Runs the complete workflow:
1. Molecular docking with Vina
2. Post-processing and scoring
3. Result filtering
4. Summary report generation

Usage: $0 [OPTIONS]

Options:
    -c, --config FILE       Configuration file (default: config.txt)
    -p, --pattern PATTERN   Ligand file pattern (default: lig*.pdbqt)
    -o, --output DIR        Output directory (default: results)
    -j, --jobs NUM          Number of parallel jobs (default: 1)
    -k, --keep-mol2         Keep MOL2 files after processing
    -n, --top NUM           Number of top results to filter (default: 10)
    --no-report             Skip summary report generation
    -h, --help              Show this help message

Examples:
    $0
    $0 -c my_config.txt --jobs 4 --top 20
    $0 --config config.txt --output my_results

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
            -k|--keep-mol2)
                KEEP_MOL2=true
                shift
                ;;
            -n|--top)
                FILTER_TOP="$2"
                shift 2
                ;;
            --no-report)
                GENERATE_REPORT=false
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
# Main function
#######################################
main() {
    init_log
    
    echo ""
    echo "========================================"
    echo "   AutoDock Vina Complete Pipeline"
    echo "========================================"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Create output directory
    ensure_directory "$OUTPUT_DIR"
    
    info "Pipeline Configuration:"
    info "  Config file: $CONFIG_FILE"
    info "  Ligand pattern: $LIGAND_PATTERN"
    info "  Output directory: $OUTPUT_DIR"
    info "  Parallel jobs: $PARALLEL_JOBS"
    echo ""
    
    # Step 1: Run docking
    echo "========================================"
    echo "Step 1: Molecular Docking"
    echo "========================================"
    echo ""
    
    if [ -x "${SCRIPT_DIR}/vina.sh" ]; then
        if "${SCRIPT_DIR}/vina.sh" \
            --config "$CONFIG_FILE" \
            --pattern "$LIGAND_PATTERN" \
            --output "$OUTPUT_DIR" \
            --jobs "$PARALLEL_JOBS"; then
            success "Docking completed successfully"
        else
            error_exit "Docking failed"
        fi
    else
        error_exit "vina.sh not found or not executable"
    fi
    
    echo ""
    
    # Step 2: Post-processing
    echo "========================================"
    echo "Step 2: Post-Processing & Scoring"
    echo "========================================"
    echo ""
    
    if [ -x "${SCRIPT_DIR}/score.sh" ]; then
        local score_args="-i ${OUTPUT_DIR}/out*.pdbqt -o ${OUTPUT_DIR}/scoring.csv -s ${OUTPUT_DIR}/scoring_ord.csv"
        
        if [ "$KEEP_MOL2" = true ]; then
            score_args="$score_args --keep-mol2"
        fi
        
        if "${SCRIPT_DIR}/score.sh" $score_args; then
            success "Post-processing completed successfully"
        else
            error_exit "Post-processing failed"
        fi
    else
        error_exit "score.sh not found or not executable"
    fi
    
    echo ""
    
    # Step 3: Filter top results
    echo "========================================"
    echo "Step 3: Filtering Top Results"
    echo "========================================"
    echo ""
    
    if [ -x "${SCRIPT_DIR}/filter_results.sh" ]; then
        if "${SCRIPT_DIR}/filter_results.sh" \
            --input "${OUTPUT_DIR}/scoring_ord.csv" \
            --output "${OUTPUT_DIR}/top_results.csv" \
            --top "$FILTER_TOP"; then
            success "Filtering completed successfully"
        else
            warning "Filtering failed (non-critical)"
        fi
    else
        warning "filter_results.sh not found or not executable (skipping)"
    fi
    
    echo ""
    
    # Step 4: Generate summary report
    if [ "$GENERATE_REPORT" = true ]; then
        echo "========================================"
        echo "Step 4: Generating Summary Report"
        echo "========================================"
        echo ""
        
        if [ -x "${SCRIPT_DIR}/generate_summary.sh" ]; then
            if "${SCRIPT_DIR}/generate_summary.sh" \
                --input "${OUTPUT_DIR}/scoring_ord.csv" \
                --output "${OUTPUT_DIR}/summary_report.txt"; then
                success "Summary report generated successfully"
            else
                warning "Summary report generation failed (non-critical)"
            fi
        else
            warning "generate_summary.sh not found or not executable (skipping)"
        fi
        
        echo ""
    fi
    
    # Final summary
    echo "========================================"
    echo "Pipeline Completed Successfully!"
    echo "========================================"
    echo ""
    info "Results location: $OUTPUT_DIR"
    info "  - Docking outputs: out_*.pdbqt"
    info "  - Scoring CSV: scoring.csv"
    info "  - Sorted scores: scoring_ord.csv"
    info "  - Top results: top_results.csv"
    if [ "$GENERATE_REPORT" = true ]; then
        info "  - Summary report: summary_report.txt"
    fi
    if [ "$KEEP_MOL2" = true ]; then
        info "  - MOL2 files: *.mol2"
    fi
    echo ""
    info "Log file: $LOG_FILE"
    echo ""
    
    success "All done!"
}

# Run main function
main "$@"
