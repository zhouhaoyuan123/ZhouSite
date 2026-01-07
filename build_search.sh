#!/bin/bash

# ============================================
# Static Website Search Index Generator
# ============================================
# This script creates a search index for static websites
# Usage: ./generate-search-index.sh [scan_directory] [output_file] [options]
# ============================================

# Default configuration
DEFAULT_SITE_DIR="."
DEFAULT_OUTPUT_FILE="search-index.json"
BASE_URL=""  # Optional: Set if you need absolute URLs (e.g., "https://example.com")

# Default exclusions
DEFAULT_EXCLUDE_PATTERNS=(
    "*/node_modules/*"
    "*/.git/*"
    "*/.svn/*"
    "*/.hg/*"
    "*/CVS/*"
    "*/.DS_Store"
    "*/Thumbs.db"
    "*/.idea/*"
    "*/.vscode/*"
    "*/build/*"
    "*/.cache/*"
    "*/__pycache__/*"
    "*/test/*"
    "*/tests/*"
    "*/coverage/*"
    "*/tmp/*"
    "*/temp/*"
    "*/cache/*"
    "*/.env*"
    "*/package-lock.json"
    "*/yarn.lock"
    "*/Gemfile.lock"
    "*/composer.lock"
    "*.log"
    "*.tmp"
    "*.swp"
    "*.swo"
    "*.bak"
    "*.backup"
    "*~"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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
SKIP_CLEANUP=false

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

# Show usage information
show_usage() {
    cat << EOF
${BOLD}Static Website Search Index Generator${NC}
${DIM}============================================${NC}

${BOLD}Usage:${NC}
  $0 [scan_directory] [output_file] [options]

${BOLD}Arguments:${NC}
  scan_directory    Directory to scan for HTML files (default: .)
  output_file       Output JSON file path (default: search-index.json)

${BOLD}Options:${NC}
  -b, --base-url URL    Set base URL for absolute links
  -e, --exclude PATTERN Exclude files/directories matching PATTERN
                        (can be used multiple times, supports wildcards)
  -f, --exclude-file FILE Read exclusion patterns from FILE (one per line)
  -F, --force           Overwrite output file if it exists
  -q, --quiet           Quiet mode (minimal output)
  -v, --verbose         Verbose mode (detailed output)
  -s, --skip-cleanup    Keep temporary files
  -h, --help           Show this help message
  --version            Show version information

${BOLD}Examples:${NC}
  $0                            # Scan current directory, output to search-index.json
  $0 ./site ./search.json       # Scan ./site, output to ./search.json
  $0 ./site -e "*/node_modules/*" -e "*/.git/*"
  $0 ./site ./output.json -f .searchignore
  $0 ./site -b "https://example.com" -F
  $0 -v ./site ./search.json
  $0 -q ./site                  # Quiet mode

${BOLD}Default Exclusions:${NC}
  Common development and system directories are excluded by default
  Use -e to add additional patterns or override defaults

${BOLD}Version:${NC} 1.2.0
EOF
}

# Show version
show_version() {
    echo "Static Website Search Index Generator v1.2.0"
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
    
    # Read exclude patterns from file
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        # Skip empty lines and comments
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

# Print info message (unless quiet)
info() {
    if [ "$QUIET" = false ]; then
        echo -e "${CYAN}ℹ${NC} $*"
    fi
}

# Build find command with exclusions
build_find_command() {
    local dir="$1"
    
    # Start with basic find command
    local find_cmd="find \"$dir\" -type f -name \"*.html\""
    
    # Add exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        # Convert pattern to find's -path format
        if [[ "$pattern" == *\** ]]; then
            # Pattern contains wildcard
            find_cmd+=" ! -path \"$pattern\""
        else
            # Exact match
            find_cmd+=" ! -path \"*/$pattern\" ! -path \"$pattern\""
        fi
    done
    
    # Sort by modification time (newest first)
    find_cmd+=" -printf \"%T@ %p\\n\" | sort -nr | cut -d' ' -f2-"
    
    echo "$find_cmd"
}

# Extract meta description from HTML file
extract_description() {
    local file="$1"
    
    # Try to get meta description
    local description=$(grep -i '<meta.*description.*content="[^"]*"' "$file" 2>/dev/null | \
        head -1 | \
        sed -n 's/.*content="\([^"]*\)".*/\1/p')
    
    # If no meta description, try Open Graph description
    if [ -z "$description" ]; then
        description=$(grep -i '<meta.*property="og:description".*content="[^"]*"' "$file" 2>/dev/null | \
            head -1 | \
            sed -n 's/.*content="\([^"]*\)".*/\1/p')
    fi
    
    # Clean up description
    if [ -n "$description" ]; then
        # Remove extra whitespace
        description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Escape special characters for JSON
        description=$(echo "$description" | jq -R . | sed 's/^"//;s/"$//')
    fi
    
    echo "$description"
}

# Extract page title
extract_title() {
    local file="$1"
    local title=$(grep -i '<title>[^<]*</title>' "$file" 2>/dev/null | \
        head -1 | \
        sed 's/<title>//;s/<\/title>//' | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -z "$title" ]; then
        # Use filename as fallback title
        title=$(basename "$file" .html)
        title=$(basename "$title" .htm)
    fi
    
    # Escape for JSON
    title=$(echo "$title" | jq -R . | sed 's/^"//;s/"$//')
    echo "$title"
}

# Generate search index
generate_index() {
    local site_dir="$1"
    local output_file="$2"
    local temp_file="${output_file}.tmp"
    
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}🔍 Starting search index generation...${NC}"
        echo -e "${BLUE}📁 Scanning directory:${NC} $site_dir"
        echo -e "${BLUE}📄 Output file:${NC} $output_file"
        
        if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
            echo -e "${BLUE}🚫 Excluding patterns:${NC}"
            for pattern in "${EXCLUDE_PATTERNS[@]:0:10}"; do
                echo -e "  ${DIM}•${NC} $pattern"
            done
            if [ ${#EXCLUDE_PATTERNS[@]} -gt 10 ]; then
                echo -e "  ${DIM}... and $(( ${#EXCLUDE_PATTERNS[@]} - 10 )) more${NC}"
            fi
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
    
    # Check if site directory exists
    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site directory '$site_dir' not found${NC}" >&2
        exit 1
    fi
    
    # Check if output directory exists
    local output_dir=$(dirname "$output_file")
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir"
        if [ "$QUIET" = false ]; then
            echo -e "${CYAN}📁 Created output directory: $output_dir${NC}"
        fi
    fi
    
    # Build find command
    local find_cmd
    find_cmd=$(build_find_command "$site_dir")
    verbose "Find command: $find_cmd"
    
    # Start JSON array
    echo "[" > "$temp_file"
    
    local first_entry=true
    local file_count=0
    local skipped_count=0
    local start_time
    start_time=$(date +%s)
    
    # Process files
    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi
        
        # Skip if file is empty
        if [ ! -s "$file" ]; then
            verbose "Skipping empty file: $file"
            skipped_count=$((skipped_count + 1))
            continue
        fi
        
        # Get relative path
        local rel_path="${file#$site_dir/}"
        if [ "$rel_path" = "$file" ]; then
            rel_path=$(basename "$file")
        fi
        
        # Remove leading ./ if present
        rel_path="${rel_path#./}"
        
        # Construct URL
        local url="$rel_path"
        if [ -n "$BASE_URL" ]; then
            # Remove leading slash from BASE_URL if present in rel_path
            if [[ "$rel_path" =~ ^/ ]]; then
                rel_path="${rel_path:1}"
            fi
            url="${BASE_URL%/}/$rel_path"
        fi
        
        # Extract data
        local title
        title=$(extract_title "$file")
        local description
        description=$(extract_description "$file")
        
        # Use URL as fallback description
        if [ -z "$description" ]; then
            description="$url"
        fi
        
        # Create JSON entry
        if [ "$first_entry" = true ]; then
            first_entry=false
        else
            echo "," >> "$temp_file"
        fi
        
        cat >> "$temp_file" << EOF
  {
    "url": "$url",
    "title": "$title",
    "description": "$description",
    "path": "$rel_path",
    "filename": "$(basename "$file")"
  }
EOF
        
        file_count=$((file_count + 1))
        if [ "$QUIET" = false ] && [ $((file_count % 10)) -eq 0 ]; then
            echo -ne "${YELLOW}⏳ Indexed $file_count pages...${NC}\r"
        fi
    done < <(eval "$find_cmd")
    
    # Close JSON array
    echo -e "\n]" >> "$temp_file"
    
    # Check if we found any files
    if [ "$file_count" -eq 0 ]; then
        echo -e "${RED}Error: No HTML files found in '$site_dir'${NC}" >&2
        echo -e "${YELLOW}Check your exclusion patterns if you expected files to be found.${NC}"
        rm -f "$temp_file"
        exit 1
    fi
    
    # Format JSON and save
    if [ "$(wc -l < "$temp_file")" -gt 1 ]; then
        jq '.' "$temp_file" > "$output_file"
        
        if [ "$SKIP_CLEANUP" = false ]; then
            rm -f "$temp_file"
        else
            info "Keeping temporary file: $temp_file"
        fi
    else
        echo -e "${RED}Error: No valid files found or empty index generated${NC}" >&2
        rm -f "$temp_file"
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    
    if [ "$QUIET" = false ]; then
        echo -e "\n${GREEN}✅ Search index generated successfully!${NC}"
        echo -e "${BLUE}📊 Statistics:${NC}"
        echo -e "  ${GREEN}✓${NC} Pages indexed: $file_count"
        if [ "$skipped_count" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠${NC}  Files skipped: $skipped_count"
        fi
        echo -e "  ${BLUE}⏱${NC}  Time elapsed: ${elapsed_time}s"
        echo -e "  ${BLUE}📦${NC}  Index size: $(du -h "$output_file" 2>/dev/null | cut -f1 || echo "N/A")"
        
        if [ "$VERBOSE" = true ]; then
            echo -e "\n${CYAN}📋 Sample entry:${NC}"
            jq '.[0]' "$output_file" 2>/dev/null || echo "Unable to display sample"
        fi
        
        echo -e "\n${YELLOW}📋 Next steps:${NC}"
        echo "1. Place '$output_file' in your website's directory"
        echo "2. Update the searchIndexPath in search.html if needed"
        echo "3. Add search.html to your website navigation"
    fi
}

# Parse command line arguments
parse_arguments() {
    # Default values
    SITE_DIR=""
    OUTPUT_FILE=""
    EXCLUDE_PATTERNS=("${DEFAULT_EXCLUDE_PATTERNS[@]}")
    
    # Parse positional arguments first
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
            -*)
                # It's an option, break and parse options later
                break
                ;;
            *)
                # It's a positional argument
                if [ -z "$SITE_DIR" ]; then
                    SITE_DIR="$1"
                elif [ -z "$OUTPUT_FILE" ]; then
                    OUTPUT_FILE="$1"
                else
                    echo -e "${YELLOW}Warning: Extra argument ignored: $1${NC}" >&2
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
                VERBOSE=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                QUIET=false
                shift
                ;;
            -s|--skip-cleanup)
                SKIP_CLEANUP=true
                shift
                ;;
            -*)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                echo -e "Use -h or --help for usage information." >&2
                exit 1
                ;;
            *)
                # Should not happen, but handle it
                echo -e "${YELLOW}Warning: Extra argument ignored: $1${NC}" >&2
                shift
                ;;
        esac
    done
    
    # Set defaults if not provided
    SITE_DIR="${SITE_DIR:-$DEFAULT_SITE_DIR}"
    OUTPUT_FILE="${OUTPUT_FILE:-$DEFAULT_OUTPUT_FILE}"
    
    # Convert relative paths to absolute
    SITE_DIR=$(realpath -m "$SITE_DIR")
    OUTPUT_FILE=$(realpath -m "$OUTPUT_FILE")
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check dependencies
    check_dependencies
    
    # Show configuration summary
    if [ "$QUIET" = false ]; then
        echo -e "${BOLD}${BLUE}⚙  Configuration Summary${NC}"
        echo -e "${DIM}══════════════════════════════════════════════${NC}"
        echo -e "Scan directory:  ${CYAN}$SITE_DIR${NC}"
        echo -e "Output file:     ${CYAN}$OUTPUT_FILE${NC}"
        echo -e "Exclude patterns: ${#EXCLUDE_PATTERNS[@]}"
        if [ -n "$BASE_URL" ]; then
            echo -e "Base URL:        ${CYAN}$BASE_URL${NC}"
        else
            echo -e "Base URL:        ${DIM}<not set>${NC}"
        fi
        echo -e "Force overwrite: ${CYAN}$FORCE${NC}"
        echo -e "${DIM}══════════════════════════════════════════════${NC}"
        echo ""
    fi
    
    # Generate index
    generate_index "$SITE_DIR" "$OUTPUT_FILE"
}

# Run main function
main "$@"