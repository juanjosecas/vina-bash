#!/bin/bash
#######################################
# Generate Summary Report
# Creates a comprehensive summary of docking results
#
# Usage: ./generate_summary.sh [OPTIONS]
#######################################

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh" || exit 1

# Default values
INPUT_CSV="scoring_ord.csv"
OUTPUT_FILE="summary_report.txt"

#######################################
# Display help message
#######################################
show_help() {
    cat << EOF
Generate Summary Report

Usage: $0 [OPTIONS]

Options:
    -i, --input FILE      Input CSV file (default: scoring_ord.csv)
    -o, --output FILE     Output report file (default: summary_report.txt)
    -h, --help            Show this help message

Examples:
    $0
    $0 -i my_scores.csv -o my_report.txt

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
                OUTPUT_FILE="$2"
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
# Calculate statistics
# Arguments:
#   Column name
#   Column index
#######################################
calculate_stats() {
    local col_name=$1
    local col_idx=$2
    
    # Extract values (skip header)
    local values=$(tail -n +2 "$INPUT_CSV" | cut -d',' -f"$col_idx" | grep -v "N/A")
    
    if [ -z "$values" ]; then
        echo "  No valid data"
        return
    fi
    
    # Calculate statistics
    local count=$(echo "$values" | wc -l)
    local min=$(echo "$values" | sort -n | head -n 1)
    local max=$(echo "$values" | sort -n | tail -n 1)
    local sum=$(echo "$values" | awk '{s+=$1} END {print s}')
    local mean=$(echo "scale=2; $sum / $count" | bc)
    
    # Median
    local median_line=$((count / 2 + 1))
    local median=$(echo "$values" | sort -n | sed -n "${median_line}p")
    
    echo "  Count: $count"
    echo "  Min: $min"
    echo "  Max: $max"
    echo "  Mean: $mean"
    echo "  Median: $median"
}

#######################################
# Main function
#######################################
main() {
    init_log
    info "Generating summary report"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate input file
    check_file "$INPUT_CSV"
    check_dependencies awk bc cut sort
    
    info "Input file: $INPUT_CSV"
    info "Output file: $OUTPUT_FILE"
    
    # Count total results
    local total_count=$(($(wc -l < "$INPUT_CSV") - 1))
    
    # Start report
    {
        echo "========================================"
        echo "   AutoDock Vina Docking Summary Report"
        echo "========================================"
        echo ""
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Input file: $INPUT_CSV"
        echo ""
        echo "----------------------------------------"
        echo "Overview"
        echo "----------------------------------------"
        echo "Total results: $total_count"
        echo ""
        
        # Top 5 results
        echo "----------------------------------------"
        echo "Top 5 Results (by Score)"
        echo "----------------------------------------"
        echo ""
        tail -n +2 "$INPUT_CSV" | head -n 5 | nl -w2 -s'. ' | while IFS=',' read -r num file mol2 smiles score rest; do
            echo "  $num $file"
            echo "     Score: $score kcal/mol"
        done
        echo ""
        
        # Score statistics
        echo "----------------------------------------"
        echo "Score Statistics (kcal/mol)"
        echo "----------------------------------------"
        calculate_stats "Score" 4
        echo ""
        
        # Molecular weight statistics
        echo "----------------------------------------"
        echo "Molecular Weight Statistics"
        echo "----------------------------------------"
        calculate_stats "MW" 7
        echo ""
        
        # LogP statistics
        echo "----------------------------------------"
        echo "LogP Statistics"
        echo "----------------------------------------"
        calculate_stats "logP" 8
        echo ""
        
        # TPSA statistics
        echo "----------------------------------------"
        echo "TPSA Statistics"
        echo "----------------------------------------"
        calculate_stats "TPSA" 9
        echo ""
        
        # Lipinski Rule of Five compliance
        echo "----------------------------------------"
        echo "Lipinski Rule of Five Compliance"
        echo "----------------------------------------"
        local lipinski_pass=0
        local lipinski_fail=0
        
        tail -n +2 "$INPUT_CSV" | while IFS=',' read -r file mol2 smiles score score_j pkb mw logp tpsa mr hba1 hba2 hbd formula; do
            # Check criteria
            local pass=true
            
            if [ "$mw" != "N/A" ] && (( $(echo "$mw > 500" | bc -l) )); then
                pass=false
            fi
            
            if [ "$logp" != "N/A" ] && (( $(echo "$logp > 5" | bc -l) )); then
                pass=false
            fi
            
            if [ "$hbd" != "N/A" ] && (( $(echo "$hbd > 5" | bc -l) )); then
                pass=false
            fi
            
            if [ "$hba1" != "N/A" ] && (( $(echo "$hba1 > 10" | bc -l) )); then
                pass=false
            fi
            
            if [ "$pass" = true ]; then
                lipinski_pass=$((lipinski_pass + 1))
            else
                lipinski_fail=$((lipinski_fail + 1))
            fi
        done
        
        # Read the counts (since while loop runs in subshell)
        lipinski_pass=$(tail -n +2 "$INPUT_CSV" | awk -F',' '
            {
                mw=$7; logp=$8; hbd=$13; hba=$11;
                if (mw!="N/A" && logp!="N/A" && hbd!="N/A" && hba!="N/A") {
                    if (mw<=500 && logp<=5 && hbd<=5 && hba<=10) pass++;
                }
            }
            END {print pass}
        ')
        
        lipinski_fail=$((total_count - lipinski_pass))
        
        echo "  Compounds passing: $lipinski_pass"
        echo "  Compounds failing: $lipinski_fail"
        echo "  Compliance rate: $(echo "scale=1; $lipinski_pass * 100 / $total_count" | bc)%"
        echo ""
        
        echo "========================================"
        echo "End of Report"
        echo "========================================"
        
    } > "$OUTPUT_FILE"
    
    # Display report
    cat "$OUTPUT_FILE"
    
    success "Summary report generated!"
    info "Report saved in: $OUTPUT_FILE"
}

# Run main function
main "$@"
