#!/bin/bash

# ============================================
# Static Website Search Index Generator
# ============================================
# Outputs minified JSON for better performance
# Usage: ./generate-search-index.sh [scan_directory] [output_file] [options]
# ============================================

# Default configuration
DEFAULT_SITE_DIR="."
DEFAULT_OUTPUT_FILE="search-index.json"
BASE_URL=""

# Default exclusions
DEFAULT_EXCLUDE_PATTERNS=(
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Variables
SITE_DIR=""
OUTPUT_FILE=""
EXCLUDE_PATTERNS=()
QUIET=false
VERBOSE=false
FORCE=false
BATCH_SIZE=1000
TEMP_DIR="/tmp/static-search-$$"

# Performance counters
FILE_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    exit "${1:-0}"
}

# Error handler
error_handler() {
    echo -e "\n${RED}✗ Script interrupted or failed${NC}"
    cleanup 1
}

trap error_handler INT TERM ERR
trap 'cleanup 0' EXIT

# Check for required tools
check_dependencies() {
    local deps=("find" "grep" "sed" "awk" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        for dep in "${missing[@]}"; do
            echo -e "  ${YELLOW}✗${NC} $dep"
        done
        echo -e "\nInstall missing dependencies and try again."
        exit 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
${BOLD}Static Website Search Index Generator${NC}
${DIM}Outputs minified JSON for better performance${NC}

${BOLD}Usage:${NC}
  $0 [scan_directory] [output_file] [options]

${BOLD}Arguments:${NC}
  scan_directory    Directory to scan for HTML files (default: .)
  output_file       Output JSON file path (default: search-index.json)

${BOLD}Options:${NC}
  -b, --base-url URL    Set base URL for absolute links
  -e, --exclude PATTERN Exclude files/directories (wildcards supported)
  -f, --exclude-file FILE Read exclusion patterns from FILE
  -F, --force           Overwrite output file without confirmation
  -q, --quiet           Quiet mode (minimal output)
  -v, --verbose         Verbose mode (detailed output)
  -p, --pretty          Output pretty-printed JSON (default: minified)
  -h, --help           Show this help message
  --version            Show version information

${BOLD}Examples:${NC}
  $0 ./website ./search.json
  $0 ./website -e "*/node_modules/*" -e "*/vendor/*"
  $0 -p ./website ./search.json  # Pretty-printed JSON
  $0 ./website ./output.json -f .searchignore -b "https://example.com"

${BOLD}Version:${NC} 3.1.0
EOF
}

# Show version
show_version() {
    echo "Static Website Search Index Generator v3.1.0 (Minified JSON)"
}

# Load exclude patterns from file
load_exclude_file() {
    local exclude_file="$1"
    
    if [ ! -f "$exclude_file" ]; then
        echo -e "${RED}Error: Exclude file '$exclude_file' not found${NC}" >&2
        return 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}📄 Loading exclude patterns from: $exclude_file${NC}"
    fi
    
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        pattern=$(echo "$pattern" | sed 's/[[:space:]]*$//')
        [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
        
        EXCLUDE_PATTERNS+=("$pattern")
    done < "$exclude_file"
    
    return 0
}

# Print verbose message
verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${DIM}[VERBOSE]${NC} $*"
    fi
}

# Print progress
print_progress() {
    if [ "$QUIET" = false ]; then
        local current="$1"
        local total="$2"
        local width=50
        local percent=$((current * 100 / total))
        local completed=$((percent * width / 100))
        local remaining=$((width - completed))
        
        printf "\r${YELLOW}⏳ Processing:${NC} ["
        printf "%${completed}s" | tr ' ' '#'
        printf "%${remaining}s" | tr ' ' '-'
        printf "] %3d%% (%d/%d files)" "$percent" "$current" "$total"
    fi
}

# Extract page title
extract_title() {
    local file="$1"
    
    # Method 1: Using awk
    local title=$(awk '
    BEGIN { RS="</title>"; IGNORECASE=1 }
    /<title[^>]*>/ {
        match($0, /<title[^>]*>([^<]*)<\/title>/, arr)
        if (arr[1] != "") {
            print arr[1]
            exit
        }
    }
    ' "$file" 2>/dev/null | head -1)
    
    # Method 2: Using grep
    if [ -z "$title" ]; then
        title=$(grep -i -z -o '<title[^>]*>[^<]*</title>' "$file" 2>/dev/null | \
            tr '\0' '\n' | \
            head -1 | \
            sed -E 's/<title[^>]*>([^<]*)<\/title>/\1/i' | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    # Method 3: Simple grep
    if [ -z "$title" ]; then
        title=$(grep -i '<title>' "$file" 2>/dev/null | \
            head -1 | \
            sed 's/<title>//i;s/<\/title>//i' | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    # Clean up
    if [ -n "$title" ]; then
        title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ')
        title=$(echo "$title" | cut -c 1-200)
    fi
    
    # Use filename as fallback
    if [ -z "$title" ] || [ "$title" = "" ]; then
        title=$(basename "$file" .html)
        title=$(basename "$title" .htm)
    fi
    
    echo "$title"
}

# Extract meta description
extract_description() {
    local file="$1"
    
    local description=""
    
    # Pattern 1: Standard meta description
    description=$(grep -i -E '<meta[^>]*name[[:space:]]*=[[:space:]]*["'\'']description["'\''][^>]*>' "$file" 2>/dev/null | \
        head -1 | \
        sed -E 's/.*content[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''].*/\1/i')
    
    # Pattern 2: Different attribute order
    if [ -z "$description" ]; then
        description=$(grep -i -E '<meta[^>]*content[[:space:]]*=[[:space:]]*["'\''][^"'\'']*["'\''][^>]*name[[:space:]]*=[[:space:]]*["'\'']description["'\''][^>]*>' "$file" 2>/dev/null | \
            head -1 | \
            sed -E 's/.*content[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''].*/\1/i')
    fi
    
    # Pattern 3: Open Graph description
    if [ -z "$description" ]; then
        description=$(grep -i -E '<meta[^>]*property[[:space:]]*=[[:space:]]*["'\'']og:description["'\''][^>]*>' "$file" 2>/dev/null | \
            head -1 | \
            sed -E 's/.*content[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''].*/\1/i')
    fi
    
    # Clean up
    if [ -n "$description" ]; then
        description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ')
        description=$(echo "$description" | cut -c 1-500)
    fi
    
    echo "$description"
}

# Safe JSON string
json_escape() {
    printf '%s' "$1" | jq -R -s '.'
}

# Process batch of files
process_batch() {
    local batch_dir="$1"
    local batch_num="$2"
    local output_file="$3"
    
    for file in "$batch_dir"/*; do
        [ -f "$file" ] || continue
        
        local file_path=$(cat "$file")
        
        # Skip empty files
        if [ ! -s "$file_path" ]; then
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        
        # Get relative path
        local rel_path="${file_path#$SITE_DIR/}"
        if [ "$rel_path" = "$file_path" ]; then
            rel_path=$(basename "$file_path")
        fi
        rel_path="${rel_path#./}"
        
        # Construct URL
        local url="$rel_path"
        if [ -n "$BASE_URL" ]; then
            if [[ "$rel_path" =~ ^/ ]]; then
                rel_path="${rel_path:1}"
            fi
            url="${BASE_URL%/}/$rel_path"
        fi
        
        # Extract data
        local title
        title=$(extract_title "$file_path")
        local description
        description=$(extract_description "$file_path")
        
        # Use URL as fallback description
        if [ -z "$description" ] || [ "$description" = "" ]; then
            description="$url"
        fi
        
        # Clean up for JSON
        title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Escape for JSON
        title=$(json_escape "$title")
        description=$(json_escape "$description")
        url=$(json_escape "$url")
        rel_path=$(json_escape "$rel_path")
        filename=$(json_escape "$(basename "$file_path")")
        
        # Write JSON entry
        if [ $FILE_COUNT -gt 0 ]; then
            echo "," >> "$output_file"
        fi
        
        # MINIFIED JSON OUTPUT
        cat >> "$output_file" << EOF
{"url":${url},"title":${title},"description":${description},"path":${rel_path},"filename":${filename}}
EOF
        
        FILE_COUNT=$((FILE_COUNT + 1))
    done
}

# Generate search index
generate_index() {
    local site_dir="$1"
    local output_file="$2"
    local pretty_print=false
    
    # Check for pretty print option
    for arg in "$@"; do
        if [ "$arg" = "-p" ] || [ "$arg" = "--pretty" ]; then
            pretty_print=true
            break
        fi
    done
    
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}🔍 Starting search index generation...${NC}"
        echo -e "${BLUE}📁 Scanning directory:${NC} $site_dir"
        echo -e "${BLUE}📄 Output file:${NC} $output_file"
        echo -e "${BLUE}📦 Output format:${NC} $(if [ "$pretty_print" = true ]; then echo "Pretty-printed JSON"; else echo "Minified JSON"; fi)"
        
        if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
            echo -e "${BLUE}🚫 Excluding patterns:${NC} ${#EXCLUDE_PATTERNS[@]} patterns"
        fi
        
        if [ -n "$BASE_URL" ]; then
            echo -e "${BLUE}🌐 Base URL:${NC} $BASE_URL"
        fi
        
        echo ""
    fi
    
    # Check if output file exists
    if [ -f "$output_file" ] && [ "$FORCE" = false ]; then
        echo -e "${YELLOW}⚠  Output file '$output_file' already exists.${NC}"
        echo -n "Overwrite? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Check site directory
    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site directory '$site_dir' not found${NC}" >&2
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Create output directory
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Build find command
    local find_cmd="find \"$site_dir\" -type f \( -name \"*.html\" -o -name \"*.htm\" \)"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$pattern" == *\** ]]; then
            find_cmd+=" ! -path \"$pattern\""
        else
            find_cmd+=" ! -path \"*/$pattern\" ! -path \"$pattern\""
        fi
    done
    
    verbose "Find command: $find_cmd"
    
    # Start timer
    local start_time=$(date +%s)
    
    # Find all HTML files
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}🔍 Finding HTML files...${NC}"
    fi
    
    eval "$find_cmd" > "$TEMP_DIR/all_files.txt"
    local total_files=$(wc -l < "$TEMP_DIR/all_files.txt")
    
    if [ "$total_files" -eq 0 ]; then
        echo -e "${RED}Error: No HTML files found in '$site_dir'${NC}" >&2
        exit 1
    fi
    
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}✓ Found $total_files HTML files${NC}"
    fi
    
    # Start JSON array
    echo "[" > "$output_file"
    
    # Process files in batches
    local batch_count=0
    local current_batch=0
    local batch_dir="$TEMP_DIR/batch_$current_batch"
    
    mkdir -p "$batch_dir"
    
    while IFS= read -r file; do
        echo "$file" > "$batch_dir/file_$batch_count"
        batch_count=$((batch_count + 1))
        
        if [ $batch_count -ge $BATCH_SIZE ]; then
            process_batch "$batch_dir" "$current_batch" "$output_file"
            
            if [ "$QUIET" = false ]; then
                print_progress "$FILE_COUNT" "$total_files"
            fi
            
            # Reset for next batch
            rm -rf "$batch_dir"
            current_batch=$((current_batch + 1))
            batch_dir="$TEMP_DIR/batch_$current_batch"
            mkdir -p "$batch_dir"
            batch_count=0
        fi
    done < "$TEMP_DIR/all_files.txt"
    
    # Process remaining files
    if [ $batch_count -gt 0 ]; then
        process_batch "$batch_dir" "$current_batch" "$output_file"
    fi
    
    # Close JSON array
    echo "]" >> "$output_file"
    
    # Format JSON
    if [ "$QUIET" = false ]; then
        if [ "$pretty_print" = true ]; then
            echo -e "\n${CYAN}📦 Formatting pretty JSON output...${NC}"
        else
            echo -e "\n${CYAN}📦 Minifying JSON output...${NC}"
        fi
    fi
    
    # MINIFIED JSON FORMATTING
    if [ "$pretty_print" = true ]; then
        jq '.' "$output_file" > "$output_file.formatted"
    else
        jq -c '.' "$output_file" > "$output_file.formatted"
    fi
    mv "$output_file.formatted" "$output_file"
    
    # Calculate statistics
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    local file_size=$(du -h "$output_file" 2>/dev/null | cut -f1 || echo "N/A")
    
    if [ "$QUIET" = false ]; then
        echo -e "\n${GREEN}✅ Search index generated successfully!${NC}"
        echo -e "${BLUE}📊 Statistics:${NC}"
        echo -e "  ${GREEN}✓${NC} Pages indexed: $FILE_COUNT"
        if [ "$SKIPPED_COUNT" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠${NC}  Files skipped: $SKIPPED_COUNT"
        fi
        echo -e "  ${BLUE}⏱${NC}  Time elapsed: ${elapsed_time}s"
        echo -e "  ${BLUE}📦${NC}  Index size: $file_size"
        if [ "$elapsed_time" -gt 0 ]; then
            echo -e "  ${BLUE}⚡${NC}  Speed: $((FILE_COUNT / elapsed_time)) pages/second"
        fi
        
        # Show compression ratio
        if [ -f "$TEMP_DIR/all_files.txt" ]; then
            local original_lines=$(wc -l < "$TEMP_DIR/all_files.txt")
            echo -e "  ${BLUE}📈${NC}  Index ratio: $((original_lines * 100 / FILE_COUNT))% coverage"
        fi
        
        echo -e "\n${YELLOW}📋 Next steps:${NC}"
        echo "1. Place '$output_file' in your website's directory"
        echo "2. Update search-index.json path in search.html if needed"
        echo "3. Test the search functionality"
        
        if [ "$FILE_COUNT" -gt 1000 ]; then
            echo -e "\n${CYAN}💡 Performance Tip:${NC}"
            echo "• Minified JSON loads faster in browsers"
            echo "• Smaller file size reduces bandwidth usage"
        fi
    fi
}

# Parse arguments
parse_arguments() {
    SITE_DIR=""
    OUTPUT_FILE=""
    EXCLUDE_PATTERNS=("${DEFAULT_EXCLUDE_PATTERNS[@]}")
    PRETTY_PRINT=false
    
    # Parse positional arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -p|--pretty)
                PRETTY_PRINT=true
                shift
                ;;
            -*)
                break
                ;;
            *)
                if [ -z "$SITE_DIR" ]; then
                    SITE_DIR="$1"
                elif [ -z "$OUTPUT_FILE" ]; then
                    OUTPUT_FILE="$1"
                else
                    echo -e "${YELLOW}Warning: Extra argument: $1${NC}" >&2
                fi
                shift
                ;;
        esac
    done
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--base-url)
                BASE_URL="$2"
                shift 2
                ;;
            -e|--exclude)
                EXCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            -f|--exclude-file)
                load_exclude_file "$2" || exit 1
                shift 2
                ;;
            -F|--force)
                FORCE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -p|--pretty)
                PRETTY_PRINT=true
                shift
                ;;
            -*)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set defaults
    SITE_DIR="${SITE_DIR:-$DEFAULT_SITE_DIR}"
    OUTPUT_FILE="${OUTPUT_FILE:-$DEFAULT_OUTPUT_FILE}"
    
    # Convert to absolute paths
    SITE_DIR=$(realpath -m "$SITE_DIR")
    OUTPUT_FILE=$(realpath -m "$OUTPUT_FILE")
}

# Main
main() {
    parse_arguments "$@"
    check_dependencies
    
    if [ "$QUIET" = false ]; then
        echo -e "${BOLD}${BLUE}⚙  Static Search Configuration${NC}"
        echo -e "${DIM}══════════════════════════════════════════════${NC}"
        echo -e "Scan directory:  ${CYAN}$SITE_DIR${NC}"
        echo -e "Output file:     ${CYAN}$OUTPUT_FILE${NC}"
        echo -e "Output format:   ${CYAN}$(if [ "$PRETTY_PRINT" = true ]; then echo "Pretty-printed JSON"; else echo "Minified JSON"; fi)${NC}"
        echo -e "Exclude patterns: ${#EXCLUDE_PATTERNS[@]}"
        [ -n "$BASE_URL" ] && echo -e "Base URL:        ${CYAN}$BASE_URL${NC}"
        echo -e "Force overwrite: ${CYAN}$FORCE${NC}"
        echo -e "${DIM}══════════════════════════════════════════════${NC}\n"
    fi
    
    generate_index "$SITE_DIR" "$OUTPUT_FILE" $(if [ "$PRETTY_PRINT" = true ]; then echo "-p"; fi)
}

# Run
main "$@"