#!/bin/bash
#######################################
# Filter Docking Results
# Filters and extracts top results based on various criteria
#
# Usage: ./filter_results.sh [OPTIONS]
#######################################

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh" || exit 1

# Default values
INPUT_CSV="scoring_ord.csv"
OUTPUT_CSV="filtered_results.csv"
TOP_N=10
SCORE_THRESHOLD=""
LIPINSKI_FILTER=false

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
Filter Docking Results

Usage: $0 [OPTIONS]

Options:
    -i, --input FILE       Input CSV file (default: scoring_ord.csv)
    -o, --output FILE      Output CSV file (default: filtered_results.csv)
    -n, --top NUM          Extract top N results (default: 10)
    -t, --threshold SCORE  Filter by score threshold (kcal/mol)
    -l, --lipinski         Apply Lipinski Rule of Five filter
    -h, --help             Show this help message

Examples:
    $0 --top 20
    $0 --threshold -8.0
    $0 --top 50 --lipinski

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_CSV="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_CSV="$2"
                shift 2
                ;;
            -n|--top)
                TOP_N="$2"
                shift 2
                ;;
            -t|--threshold)
                SCORE_THRESHOLD="$2"
                shift 2
                ;;
            -l|--lipinski)
                LIPINSKI_FILTER=true
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
# Check if compound passes Lipinski Rule of Five
# Arguments:
#   MW, logP, HBD, HBA (from CSV row)
# Returns:
#   0 if passes, 1 if fails
#######################################
check_lipinski() {
    local mw=$1
    local logp=$2
    local hbd=$3
    local hba=$4
    
    # Rule of Five criteria:
    # MW <= 500, logP <= 5, HBD <= 5, HBA <= 10
    
    if [ "$mw" = "N/A" ] || [ "$logp" = "N/A" ] || [ "$hbd" = "N/A" ] || [ "$hba" = "N/A" ]; then
        return 1
    fi
    
    # Use awk for floating-point comparison
    local passes=$(awk -v mw="$mw" -v logp="$logp" -v hbd="$hbd" -v hba="$hba" 'BEGIN {
        if (mw <= 500 && logp <= 5 && hbd <= 5 && hba <= 10) print 1; else print 0
    }')
    
    if [ "$passes" -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

#######################################
# Main function
#######################################
main() {
    init_log
    info "Starting result filtering"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate input file
    check_file "$INPUT_CSV"
    
    info "Input file: $INPUT_CSV"
    info "Output file: $OUTPUT_CSV"
    
    # Read header
    local header=$(head -n 1 "$INPUT_CSV")
    echo "$header" > "$OUTPUT_CSV"
    
    local count=0
    local line_num=0
    
    # Process data lines
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # Skip header
        if [ $line_num -eq 1 ]; then
            continue
        fi
        
        # Extract fields (adjust indices based on CSV structure)
        IFS=',' read -ra fields <<< "$line"
        local score="${fields[3]}"
        local mw="${fields[6]}"
        local logp="${fields[7]}"
        local hbd="${fields[12]}"
        local hba1="${fields[10]}"
        
        # Apply filters
        local pass=true
        
        # Score threshold filter
        if [ -n "$SCORE_THRESHOLD" ] && [ "$score" != "N/A" ]; then
            # Use awk for floating-point comparison
            local score_pass=$(awk -v score="$score" -v threshold="$SCORE_THRESHOLD" 'BEGIN {
                if (score <= threshold) print 1; else print 0
            }')
            if [ "$score_pass" -eq 0 ]; then
                pass=false
            fi
        fi
        
        # Lipinski filter
        if [ "$LIPINSKI_FILTER" = true ]; then
            if ! check_lipinski "$mw" "$logp" "$hbd" "$hba1"; then
                pass=false
            fi
        fi
        
        # Top N filter
        if [ "$count" -ge "$TOP_N" ]; then
            break
        fi
        
        # Add to output if passes all filters
        if [ "$pass" = true ]; then
            echo "$line" >> "$OUTPUT_CSV"
            count=$((count + 1))
        fi
        
    done < "$INPUT_CSV"
    
    # Summary
    success "Filtering completed!"
    info "Extracted $count result(s)"
    info "Results saved in: $OUTPUT_CSV"
}

# Run main function
main "$@"
