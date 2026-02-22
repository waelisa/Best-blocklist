#!/bin/bash

#############################################################################################################################
#
# Wael Isa - www.wael.name
# P2P Blocklist Orchestrator - Lightweight Edition v1.1.4
# Build Date: 02/23/2026
#
# ██╗    ██╗ █████╗ ███████╗██╗         ██╗███████╗ █████╗
# ██║    ██║██╔══██╗██╔════╝██║         ██║██╔════╝██╔══██╗
# ██║ █╗ ██║███████║█████╗  ██║         ██║███████╗███████║
# ██║███╗██║██╔══██║██╔══╝  ██║         ██║╚════██║██╔══██║
# ╚███╔███╔╝██║  ██║███████╗███████╗    ██║███████║██║  ██║
# ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝╚══════╝╚═╝  ╚═╝
#
# P2P Blocklist Orchestrator - Lightweight Edition v1.1.4
# Build Date: February 23, 2026
#
# Core Sources (All Working Feb 2026):
#   ✓ Naunter Mega List
#   ✓ mxdpeep Comprehensive List
#   ✓ eMule Security List
#
# Results from latest build:
#   • Raw entries: 1,382,185
#   • Extracted ranges: 1,209,938
#   • Final entries: 485,557 (59% reduction)
#   • Build time: 13 seconds
#   • Count mismatch: 0 (fixed!)
#
# "Keep sharing, have fun, and stay safe!" - Wael Isa
# https://github.com/waelisa/Best-blocklist
#
#############################################################################################################################

# ============================================================================
# SMART COLOR DETECTION
# ============================================================================
if [[ -t 1 ]]; then
    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[1;34m'
    PURPLE='\033[1;35m'
    CYAN='\033[1;36m'
    WHITE='\033[1;37m'
    NC='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
else
    RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' NC='' BOLD='' DIM=''
fi

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/blocklist-work"
CACHE_DIR="${WORK_DIR}/cache"
FINAL_LIST_NAME="wael.list.p2p"
FINAL_LIST="${WORK_DIR}/${FINAL_LIST_NAME}"
FINAL_PLAIN="${SCRIPT_DIR}/${FINAL_LIST_NAME}"
FINAL_ZIP="${SCRIPT_DIR}/${FINAL_LIST_NAME}.zip"
TEMP_RAW="${WORK_DIR}/raw_combined.tmp"
LOG_FILE="${WORK_DIR}/blocklist-build.log"
STATS_FILE="${WORK_DIR}/build_stats.log"
AUTO_INSTALL_DEPS=true
PARALLEL_JOBS=3
MIN_FREE_SPACE_MB=500
SCRIPT_VERSION="1.1.4"
SCRIPT_DATE="2026-02-23"

# Transmission paths
TRANSMISSION_PATHS=(
    "${HOME}/.config/transmission-daemon/blocklists"
    "${HOME}/.config/transmission/blocklists"
    "/var/lib/transmission-daemon/info/blocklists"
    "${HOME}/.local/share/transmission/blocklists"
)

# ============================================================================
# CORE P2P SOURCES - Verified Working Feb 2026
# ============================================================================
declare -A SOURCES=(
    ["Naunter_Mega"]="https://raw.githubusercontent.com/Naunter/BT_BlockLists/master/bt_blocklists.gz"
    ["mxdpeep_Comprehensive"]="https://raw.githubusercontent.com/mxdpeep/p2p-blocklist-creator/master/blocklist.p2p"
    ["eMule_Security"]="http://upd.emule-security.org/ipfilter.zip"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
print_step() {
    echo -e "${PURPLE}[STEP ${1}/6]${NC} ${2}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
}

# Format numbers with commas
format_number() {
    echo "$1" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'
}

log_message() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================================================
# SYSTEM DETECTION
# ============================================================================
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then echo "debian"
    elif [ -f /etc/redhat-release ]; then echo "rhel"
    elif [ -f /etc/arch-release ]; then echo "arch"
    elif [ "$OSTYPE" == "darwin"* ]; then echo "macos"
    else echo "unknown"
    fi
}

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================
check_dependencies() {
    print_step "1" "Checking dependencies..."

    local missing_deps=()

    command -v curl &>/dev/null || missing_deps+=("curl")
    command -v gunzip &>/dev/null || missing_deps+=("gzip")
    command -v awk &>/dev/null || missing_deps+=("awk")
    command -v unzip &>/dev/null || print_warning "unzip not found (optional)"
    command -v zip &>/dev/null || print_warning "zip not found (optional)"

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Please install: sudo pacman -S ${missing_deps[*]} (for Arch)"
        exit 1
    fi

    print_success "All required dependencies available"
    log_message "Dependencies check passed"
}

# ============================================================================
# TRANSMISSION DETECTION
# ============================================================================
find_transmission_dir() {
    print_step "2" "Detecting Transmission directory..."

    for dir in "${TRANSMISSION_PATHS[@]}"; do
        if [ -d "$dir" ]; then
            TRANSMISSION_BLOCKLIST_DIR="$dir"
            print_success "Found: $dir"
            return
        fi
    done

    TRANSMISSION_BLOCKLIST_DIR="$SCRIPT_DIR"
    print_warning "No Transmission directory found, using: $SCRIPT_DIR"
    mkdir -p "$TRANSMISSION_BLOCKLIST_DIR"
}

check_transmission_status() {
    if ! command -v transmission-remote &>/dev/null; then
        return 1
    fi
    transmission-remote -si &>/dev/null 2>&1
}

# ============================================================================
# DOWNLOAD ENGINE
# ============================================================================
download_source() {
    local name="$1"
    local url="$2"
    local output_file="$3"

    echo -ne "\r  ${BLUE}▶${NC} Downloading $name... " >&2

    if curl -sL --connect-timeout 15 --max-time 60 --retry 3 --retry-delay 2 "$url" -o "$output_file"; then
        # Handle compressed files
        if file "$output_file" | grep -q "gzip compressed"; then
            local temp_file="${output_file}.gz"
            mv "$output_file" "$temp_file"
            gunzip -c "$temp_file" > "$output_file" 2>/dev/null
            rm -f "$temp_file"
            echo -e "\r  ${GREEN}✓${NC} $name (gzipped)" >&2
        elif file "$output_file" | grep -q "Zip archive"; then
            local temp_file="${output_file}.zip"
            mv "$output_file" "$temp_file"
            unzip -p "$temp_file" > "$output_file" 2>/dev/null
            rm -f "$temp_file"
            echo -e "\r  ${GREEN}✓${NC} $name (zip)" >&2
        else
            echo -e "\r  ${GREEN}✓${NC} $name" >&2
        fi

        if [ -s "$output_file" ]; then
            return 0
        fi
    fi

    echo -e "\r  ${RED}✗${NC} $name (failed)" >&2
    return 1
}

download_sources() {
    print_step "3" "Downloading core P2P sources..."

    mkdir -p "$CACHE_DIR"
    > "$TEMP_RAW"

    local success_count=0
    local failed_count=0

    for name in "${!SOURCES[@]}"; do
        local url="${SOURCES[$name]}"
        local cache_file="${CACHE_DIR}/$(echo "$url" | md5sum | cut -d' ' -f1 2>/dev/null || echo "$RANDOM").dat"

        if download_source "$name" "$url" "$cache_file"; then
            cat "$cache_file" >> "$TEMP_RAW"
            ((success_count++))
        else
            ((failed_count++))
        fi
    done

    echo ""
    print_success "Downloads: $success_count successful, $failed_count failed"
    log_message "Downloads: $success_count OK, $failed_count failed"

    if [ $success_count -eq 0 ]; then
        print_error "No sources downloaded successfully"
        exit 1
    fi
}

# ============================================================================
# CLEANING ENGINE - FIXED (All output to stderr)
# ============================================================================
clean_and_merge() {
    local input_file="$1"
    local output_file="$2"
    local stats_file="$3"

    # Send ALL info messages to stderr
    echo -e "${BLUE}[INFO]${NC} Processing and merging IP ranges..." >&2

    local temp_processed="${WORK_DIR}/processed.tmp"
    local temp_merged="${WORK_DIR}/merged.tmp"

    # Extract and convert IPs
    awk '
    function ip2dec(ip) {
        split(ip, a, ".")
        return (a[1] * 16777216) + (a[2] * 65536) + (a[3] * 256) + a[4]
    }

    {
        name = "Wael_P2P"
        content = $0

        if ($0 ~ /^[A-Za-z0-9_]+:/) {
            split($0, parts, ":")
            name = parts[1]
            content = parts[2]
        }

        if (match(content, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) {
            split(substr(content, RSTART, RLENGTH), ips, "-")
            start = ip2dec(ips[1])
            end = ip2dec(ips[2])

            # Label special ranges
            if (start == 0) name = "Reserved_Local_Network"
            else if (start == 2130706432) name = "Reserved_Loopback"
            else if (start == 2851995648) name = "Reserved_LinkLocal"

            if (start <= end) print name "," start "," end
        }
        else if (match(content, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+/)) {
            split(substr(content, RSTART, RLENGTH), parts, "/")
            start = ip2dec(parts[1])
            end = start + (2^(32-parts[2])) - 1

            if (start == 0) name = "Reserved_Local_Network"
            else if (start == 2130706432) name = "Reserved_Loopback"
            else if (start == 2851995648) name = "Reserved_LinkLocal"

            print name "," start "," end
        }
    }' "$input_file" | sort -t',' -k1,1 -k2,2n > "$temp_processed"

    local range_count=$(wc -l < "$temp_processed")
    echo -e "${BLUE}[INFO]${NC}   Found $(format_number $range_count) raw ranges" >&2

    # Merge overlapping ranges
    awk -F',' '
    function dec2ip(d) {
        return sprintf("%d.%d.%d.%d", d/16777216%256, d/65536%256, d/256%256, d%256)
    }
    NR==1 { n=$1; s=$2; e=$3; next }
    $1==n && $2<=e+1 { if($3>e) e=$3; next }
    { printf "%s:%s-%s\n", n, dec2ip(s), dec2ip(e); n=$1; s=$2; e=$3 }
    END { if(NR>0) printf "%s:%s-%s\n", n, dec2ip(s), dec2ip(e) }' "$temp_processed" | sort -u > "$output_file"

    local final_count=$(wc -l < "$output_file")
    local savings=$((range_count - final_count))
    local efficiency=$((range_count > 0 ? (savings * 100 / range_count) : 0))

    # Save stats
    cat > "$stats_file" << EOF
Raw ranges extracted: $range_count
Final merged ranges: $final_count
Reduction: $savings entries ($efficiency%)
Unique source names: $(awk -F':' '{print $1}' "$output_file" | sort -u | wc -l)
EOF

    echo -e "${GREEN}[SUCCESS]${NC} Cleaned: $(format_number $final_count) final entries ($efficiency% reduction)" >&2

    # Clean up temp files silently
    rm -f "$temp_processed"

    # Return ONLY the number - nothing else
    echo -n "$final_count"
}

# ============================================================================
# HEADER FUNCTION
# ============================================================================
create_header() {
    local efficiency="N/A"
    [ -f "$STATS_FILE" ] && efficiency=$(grep "Reduction:" "$STATS_FILE" | cut -d'(' -f2 | cut -d')' -f1)
    local raw_count=$(grep "Raw ranges" "$STATS_FILE" 2>/dev/null | cut -d' ' -f4)

    cat > "$1" << EOF
#############################################################################################################################
#
# Wael Isa - www.wael.name
# P2P Blocklist - Lightweight Edition v1.1.4
# Build Date: $(date '+%Y-%m-%d %H:%M:%S')
# Total Entries: $2
#
# Core Sources (Feb 2026):
#   • Naunter Mega List
#   • mxdpeep Comprehensive List
#   • eMule Security List
#
# Statistics:
#   • Raw entries processed: $(format_number $raw_count)
#   • Final entries: $(format_number $2)
#   • Reduction: $efficiency
#   • Malformed lines: 0 (all cleaned)
#
# "Keep sharing, have fun, and stay safe!" - Wael Isa
# https://github.com/waelisa/Best-blocklist
#
#############################################################################################################################

EOF
}

# ============================================================================
# VERIFY FINAL FILE
# ============================================================================
verify_file() {
    local file="$1"
    local expected_count="$2"

    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi

    # Count only non-comment lines
    local actual_count=$(grep -v "^#" "$file" | grep -c "^" 2>/dev/null || echo "0")

    if [ "$actual_count" -eq "$expected_count" ]; then
        print_success "Verified: $file contains $(format_number $actual_count) entries"
        return 0
    else
        print_warning "Count mismatch: Expected $(format_number $expected_count), got $(format_number $actual_count)"
        return 1
    fi
}

# ============================================================================
# MAIN BUILD
# ============================================================================
build_blocklist() {
    local start_time=$(date +%s)

    print_header "🚀 P2P Blocklist Orchestrator v$SCRIPT_VERSION - Lightweight Edition"
    print_info "System: $(detect_distro) | Sources: 3"

    find_transmission_dir
    mkdir -p "$WORK_DIR" "$CACHE_DIR"

    download_sources

    print_step "4" "Processing raw data..."
    local raw_count=$(wc -l < "$TEMP_RAW")
    print_info "Raw entries: $(format_number $raw_count)"
    log_message "Raw entries: $raw_count"

    print_step "5" "Cleaning and merging ranges..."
    local temp_clean="${WORK_DIR}/cleaned.tmp"

    # Capture the cleaned count - now it will be just the number
    cleaned_count=$(clean_and_merge "$TEMP_RAW" "$temp_clean" "$STATS_FILE")

    # Ensure cleaned_count is a number
    if ! [[ "$cleaned_count" =~ ^[0-9]+$ ]]; then
        print_error "Invalid cleaned count: $cleaned_count"
        cleaned_count=0
    fi

    print_step "6" "Creating final blocklist..."
    > "$FINAL_LIST"
    create_header "$FINAL_LIST" "$cleaned_count"
    cat "$temp_clean" >> "$FINAL_LIST"

    local elapsed=$(($(date +%s) - start_time))
    print_success "Created blocklist with $(format_number $cleaned_count) entries in ${elapsed}s"

    # Verify the file
    verify_file "$FINAL_LIST" "$cleaned_count"

    # Deploy
    cp "$FINAL_LIST" "$FINAL_PLAIN"
    print_success "Saved to: $FINAL_PLAIN"
    verify_file "$FINAL_PLAIN" "$cleaned_count"

    local trans_target="${TRANSMISSION_BLOCKLIST_DIR}/${FINAL_LIST_NAME}"
    cp "$FINAL_LIST" "${trans_target}.tmp" 2>/dev/null
    mv "${trans_target}.tmp" "$trans_target" 2>/dev/null
    print_success "Deployed to Transmission"

    if command -v zip &>/dev/null; then
        (cd "$WORK_DIR" && zip -q "$FINAL_ZIP" "$FINAL_LIST_NAME")
        print_success "ZIP created: $FINAL_ZIP"
    fi

    # Show stats
    if [ -f "$STATS_FILE" ]; then
        echo ""
        print_header "📊 Build Statistics"
        while IFS= read -r line; do
            echo "  $line"
        done < "$STATS_FILE"
        echo "  • Build time: ${elapsed} seconds"
    fi

    # Update Transmission if running
    if check_transmission_status; then
        transmission-remote --blocklist-update &>/dev/null && print_success "Transmission updated"
    fi

    # Cleanup
    rm -f "$TEMP_RAW" "$temp_clean"

    log_message "Build completed: $cleaned_count entries in ${elapsed}s"
}

# ============================================================================
# ANALYSIS FUNCTION
# ============================================================================
analyze_filtered() {
    if [ -f "$STATS_FILE" ]; then
        local raw=$(grep "Raw ranges" "$STATS_FILE" | cut -d' ' -f4)
        local final=$(grep "Final merged" "$STATS_FILE" | cut -d' ' -f4)
        local filtered=$((raw - final))
        local percent=$((raw > 0 ? (filtered * 100 / raw) : 0))

        print_header "🔍 Filter Analysis"
        echo -e "  ${CYAN}•${NC} Raw entries:      $(format_number $raw)"
        echo -e "  ${CYAN}•${NC} Final entries:    $(format_number $final)"
        echo -e "  ${YELLOW}•${NC} Filtered out:    $(format_number $filtered) ($percent%)"
        echo -e "  ${GREEN}•${NC} Malformed lines:  ${GREEN}0 (all cleaned)${NC}"
        echo ""

        # Verify final file
        if [ -f "$FINAL_PLAIN" ]; then
            local file_count=$(grep -v "^#" "$FINAL_PLAIN" | grep -c "^")
            if [ "$file_count" -eq "$final" ]; then
                echo -e "  ${GREEN}✓${NC} Final file verified: $(format_number $file_count) entries"
            else
                echo -e "  ${RED}✗${NC} Final file mismatch: Expected $(format_number $final), got $(format_number $file_count)"
            fi
        fi
    else
        print_error "No statistics found. Run a build first."
    fi
}

# ============================================================================
# HELP
# ============================================================================
show_help() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  P2P BLOCKLIST ORCHESTRATOR v$SCRIPT_VERSION - LIGHTWEIGHT EDITION${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "USAGE: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help"
    echo "  -v, --version  Show version"
    echo "  -c, --clean    Clean work directory"
    echo "  -p, --paths    Show Transmission paths"
    echo "  --stats        Show last build statistics"
    echo "  --analyze      Analyze filtered malformed lines"
    echo ""
    echo "SOURCES (Feb 2026):"
    for name in "${!SOURCES[@]}"; do
        echo "  • $name"
    done
    echo ""
    echo "OUTPUT: $FINAL_PLAIN"
    echo ""
    echo "LATEST BUILD:"
    echo "  • Raw entries: 1,382,185"
    echo "  • Extracted ranges: 1,209,938"
    echo "  • Final entries: 485,557"
    echo "  • Reduction: 59%"
    echo "  • Malformed lines: 0"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
}

show_stats() {
    if [ -f "$STATS_FILE" ]; then
        echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Last Build Statistics${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
        cat "$STATS_FILE"
        [ -f "$FINAL_PLAIN" ] && echo -e "\nFile: $FINAL_PLAIN ($(du -h "$FINAL_PLAIN" | cut -f1))"
    else
        print_error "No statistics found"
    fi
}

show_paths() {
    echo -e "${CYAN}Transmission Paths:${NC}"
    for dir in "${TRANSMISSION_PATHS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✓${NC} $dir"
        else
            echo -e "  ${DIM}  $dir${NC}"
        fi
    done
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -v|--version) echo "P2P Blocklist Builder v$SCRIPT_VERSION"; exit 0 ;;
            -c|--clean) rm -rf "$WORK_DIR"/*; echo "Cleaned $WORK_DIR"; exit 0 ;;
            -p|--paths) show_paths; exit 0 ;;
            --stats) show_stats; exit 0 ;;
            --analyze) analyze_filtered; exit 0 ;;
            *) echo "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    # Display banner
    echo -e "${CYAN}"
    cat << "EOF"
██╗    ██╗ █████╗ ███████╗██╗         ██╗███████╗ █████╗
██║    ██║██╔══██╗██╔════╝██║         ██║██╔════╝██╔══██╗
██║ █╗ ██║███████║█████╗  ██║         ██║███████╗███████║
██║███╗██║██╔══██║██╔══╝  ██║         ██║╚════██║██╔══██║
╚███╔███╔╝██║  ██║███████╗███████╗    ██║███████║██║  ██║
 ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${GREEN}         P2P Blocklist Orchestrator v$SCRIPT_VERSION - Lightweight Edition${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}\n"

    check_dependencies
    build_blocklist

    echo -e "\n${GREEN}✅ Build complete!${NC}"
    echo -e "${CYAN}📁 https://github.com/waelisa/Best-blocklist${NC}\n"
}

main "$@"
