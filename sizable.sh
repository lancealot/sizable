#!/bin/bash

# filesystem_analyzer.sh
# A parallel filesystem crawler that provides detailed statistics about files and directories
#
# Author: Your Name
# Date: December 22, 2024

set -euo pipefail

# Default values
PARALLEL_PROCS=8
VERBOSE=false
SAMPLE_SIZE=1000
TARGET_PATH=""
TEMP_DIR="/tmp/fs_analyzer_$$"

# Function to display help
show_help() {
    cat << EOF
Usage: $(basename "$0") -p <path> [OPTIONS]

A parallel filesystem analyzer that provides detailed statistics about files and directories.

Required:
    -p <path>    Specify the filesystem path to analyze

Options:
    -j <num>     Number of parallel processes (default: 8)
    -v           Enable verbose logging
    -s <num>     Sample size for calculating file size ranges (default: 1000)
    -h           Show this help message

Example:
    $(basename "$0") -p /home/user/data -j 4 -v
EOF
    exit 0
}

# Function for verbose logging
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Function to clean up temporary files
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Set up cleanup trap
trap cleanup EXIT

# Function to get file size in bytes
get_file_size() {
    stat --format=%s "$1" 2>/dev/null || echo "0"
}

# Function to calculate dynamic size ranges from sample
calculate_ranges() {
    local sample_file="$1"
    
    # Check if sample file is empty
    if [[ ! -s "$sample_file" ]]; then
        # Output default ranges if no files found
        echo "1024"      # 1KB
        echo "102400"    # 100KB
        echo "1048576"   # 1MB
        return
    fi

    awk -F'\n' '{
        sizes[NR] = $1
    }
    END {
        if (NR == 0) {
            print "1024"    # 1KB
            print "102400"  # 100KB
            print "1048576" # 1MB
            exit
        }
        
        n = asort(sizes)
        
        # Calculate quartiles (handle small n)
        q1 = (n >= 4) ? int(sizes[int(n/4)]) : 1024
        q2 = (n >= 2) ? int(sizes[int(n/2)]) : 102400
        q3 = (n >= 4) ? int(sizes[int(3*n/4)]) : 1048576
        
        # Output ranges in bytes
        print q1
        print q2
        print q3
    }' "$sample_file"
}

# Function to analyze a batch of files
analyze_files() {
    local dir="$1"
    local ranges_file="$2"
    local output_file="$3"
    
    # Check if ranges file exists and is not empty
    if [[ ! -s "$ranges_file" ]]; then
        echo "0 0 0 0 0 0" > "$output_file"
        return
    fi
    
    # Read ranges
    local -a ranges
    mapfile -t ranges < "$ranges_file"
    
    # Initialize output file in case no files are found
    echo "0 0 0 0 0 0" > "$output_file"
    
    find "$dir" -type f -print0 | while IFS= read -r -d '' file; do
        size=$(get_file_size "$file")
        echo "$size"
    done | awk -v q1="${ranges[0]:-1024}" -v q2="${ranges[1]:-102400}" -v q3="${ranges[2]:-1048576}" '{
        total_size += $1
        count++
        if ($1 < q1) range1++
        else if ($1 < q2) range2++
        else if ($1 < q3) range3++
        else range4++
    }
    END {
        if (count > 0) {
            printf "%d %d %d %d %d %.2f\n", count, range1, range2, range3, range4, total_size/count
        }
    }' > "$output_file"
}

# Parse command line arguments
while getopts "hp:j:vs:" opt; do
    case $opt in
        h)
            show_help
            ;;
        p)
            TARGET_PATH="$OPTARG"
            ;;
        j)
            PARALLEL_PROCS="$OPTARG"
            ;;
        v)
            VERBOSE=true
            ;;
        s)
            SAMPLE_SIZE="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TARGET_PATH" ]]; then
    echo "Error: Path argument (-p) is required." >&2
    show_help
fi

if [[ ! -d "$TARGET_PATH" ]]; then
    echo "Error: Specified path '$TARGET_PATH' does not exist or is not a directory." >&2
    exit 1
fi

# Export functions so they're available to parallel processes
export -f get_file_size analyze_files log

# Handle GNU Parallel citation
if ! parallel --citation > /dev/null 2>&1; then
    echo "Please run 'parallel --citation' once to silence the citation notice"
    exit 1
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Main execution
log "Starting filesystem analysis of $TARGET_PATH"

# Check if target directory is empty
if [[ -z "$(find "$TARGET_PATH" -type f -print -quit)" ]]; then
    echo "Warning: No files found in specified directory."
    echo "Total Files: 0"
    echo "Size Distribution:"
    echo "  Small Files (<Q1): 0"
    echo "  Medium-Small Files (Q1-Q2): 0"
    echo "  Medium-Large Files (Q2-Q3): 0"
    echo "  Large Files (>Q3): 0"
    echo "Average File Size: 0 bytes"
    echo "Total Directories: 0"
    exit 0
fi

# Get initial sample for size ranges
log "Collecting sample for size range calculation..."
find "$TARGET_PATH" -type f -print0 | \
    shuf -z -n "$SAMPLE_SIZE" | \
    while IFS= read -r -d '' file; do
        get_file_size "$file"
    done > "$TEMP_DIR/sample"

# Calculate size ranges
log "Calculating size ranges..."
calculate_ranges "$TEMP_DIR/sample" > "$TEMP_DIR/ranges"

# Get top-level directories for parallel processing
log "Finding top-level directories..."
find "$TARGET_PATH" -mindepth 1 -maxdepth 1 -type d > "$TEMP_DIR/directories"

# Process directories in parallel
log "Processing directories in parallel (using $PARALLEL_PROCS processes)..."
while IFS= read -r dir; do
    echo "bash -c 'analyze_files \"$dir\" \"$TEMP_DIR/ranges\" \"$TEMP_DIR/stats_${RANDOM}\"'"
done < "$TEMP_DIR/directories" | parallel -j "$PARALLEL_PROCS"

# Handle case where no subdirectories exist
if [[ ! -s "$TEMP_DIR/directories" ]]; then
    log "No subdirectories found, analyzing root directory..."
    analyze_files "$TARGET_PATH" "$TEMP_DIR/ranges" "$TEMP_DIR/stats_root"
fi

# Combine results
log "Combining results..."
cat "$TEMP_DIR"/stats_* 2>/dev/null | awk -v q1="$(head -1 "$TEMP_DIR/ranges")" \
                                        -v q2="$(head -2 "$TEMP_DIR/ranges" | tail -1)" \
                                        -v q3="$(tail -1 "$TEMP_DIR/ranges")" '
function round_to_power_of_2(bytes) {
    power = 1
    while (power < bytes) power *= 2
    return power
}

function human_readable(bytes) {
    if (bytes < 1024) return bytes " B"
    if (bytes < 1048576) return sprintf("%d KB", bytes/1024)
    if (bytes < 1073741824) return sprintf("%d MB", bytes/1048576)
    return sprintf("%d GB", bytes/1073741824)
}

{
    total_files += $1
    range1 += $2
    range2 += $3
    range3 += $4
    range4 += $5
    if ($1 > 0) {
        weighted_avg = $6 * $1
        files_processed += $1
        total_weighted_avg += weighted_avg
    }
}
END {
    avg_size = files_processed > 0 ? total_weighted_avg/files_processed : 0
    q1_rounded = round_to_power_of_2(q1)
    q2_rounded = round_to_power_of_2(q2)
    q3_rounded = round_to_power_of_2(q3)
    
    print "Total Files:", total_files
    print "\nSize Distribution:"
    print "  Files under", human_readable(q1_rounded) ":", range1
    print "  Files between", human_readable(q1_rounded), "and", human_readable(q2_rounded) ":", range2
    print "  Files between", human_readable(q2_rounded), "and", human_readable(q3_rounded) ":", range3
    print "  Files over", human_readable(q3_rounded) ":", range4
    print "\nAverage File Size:", human_readable(int(avg_size))
}'

# Directory count
dir_count=$(find "$TARGET_PATH" -type d | wc -l)
echo "Total Directories: $dir_count"

log "Analysis complete!"
