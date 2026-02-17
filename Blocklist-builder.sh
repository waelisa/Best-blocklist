#!/bin/bash

#############################################################################################################################
#
# Wael Isa - www.wael.name
# Blacklist for P2P network
# Ver (super-list) 1.0.1
# Build Date: 02/18/2026
# I remove some IP'S from this list because we don't need it,
# Only i list IP'S that report your IP for copyright,
# So keep shiring and have fun,
# if you have any ideas please report here
# https://github.com/waelisa/Best-blocklist
#
#############################################################################################################################
# P2P Blocklist Orchestrator - Industrial Version
# Merges multiple sources, cleans IPs, and updates Transmission
# Features:
#   ✓ Multi-source aggregation (P2P lists, security lists, infrastructure)
#   ✓ Automatic decompression of gzipped files
#   ✓ Advanced data cleaning and deduplication
#   ✓ ZIP archive creation for distribution (auto-installs if missing)
#   ✓ Dynamic Transmission directory detection
#   ✓ Multiple Transmission config paths supported
#   ✓ Multi-distribution support (Debian, Ubuntu, RHEL, Fedora, Arch, Alpine, SUSE)
#   ✓ Automatic dependency installation (curl, gzip, zip)
#   ✓ Fallback to script directory if no Transmission found
#   ✓ Color-coded progress output
#   ✓ Step-by-step execution tracking
#   ✓ Temporary work folder management
#   ✓ Error handling with graceful fallbacks
#   ✓ Automatic work folder cleanup (keeps only final files)
#############################################################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/blocklist-work"
FINAL_LIST_NAME="wael.list.p2p"
FINAL_LIST="${WORK_DIR}/${FINAL_LIST_NAME}"
FINAL_PLAIN="${SCRIPT_DIR}/${FINAL_LIST_NAME}"  # Final plain file in script dir
FINAL_ZIP="${SCRIPT_DIR}/${FINAL_LIST_NAME}.zip"
TEMP_RAW=$(mktemp)
LOG_FILE="${WORK_DIR}/blocklist-build.log"
AUTO_INSTALL_DEPS=true  # Changed to true by default

# Possible Transmission blocklist directories (in order of preference)
TRANSMISSION_PATHS=(
    "${HOME}/.config/transmission-daemon/blocklists"           # User daemon
    "${HOME}/.config/transmission/blocklists"                  # User client
    "/var/lib/transmission-daemon/info/blocklists"             # System daemon
    "${HOME}/.local/share/transmission/blocklists"             # Flatpak/user local
    "/usr/local/etc/transmission/blocklists"                    # Manual compile
)

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_LIKE=$ID_LIKE
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
    elif [ -f /etc/SuSE-release ]; then
        OS="suse"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    echo "$OS"
}

# Get package manager and install command
get_package_manager() {
    local distro=$1

    case $distro in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
            echo "apt-get install -y"
            ;;
        fedora)
            echo "dnf install -y"
            ;;
        rhel|centos|rocky|almalinux|ol|amzn)
            if command -v dnf &> /dev/null; then
                echo "dnf install -y"
            else
                echo "yum install -y"
            fi
            ;;
        arch|manjaro|endeavouros|artix)
            echo "pacman -S --noconfirm"
            ;;
        alpine)
            echo "apk add"
            ;;
        opensuse*|suse|sles)
            echo "zypper install -y"
            ;;
        void)
            echo "xbps-install -y"
            ;;
        gentoo)
            echo "emerge -v"
            ;;
        slackware)
            echo "slackpkg install"
            ;;
        macos)
            if command -v brew &> /dev/null; then
                echo "brew install"
            elif command -v port &> /dev/null; then
                echo "port install"
            else
                echo "unknown"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "root"
    else
        echo "user"
    fi
}

# Install missing dependencies
install_deps() {
    local missing_packages=("$@")
    local distro=$(detect_distro)
    local install_cmd=$(get_package_manager "$distro")
    local sudo_cmd=""

    print_warning "Missing packages: ${missing_packages[*]}"

    # Check if we need sudo (not root and not on macOS with brew)
    if [ "$(check_root)" != "root" ] && [ "$distro" != "macos" ]; then
        sudo_cmd="sudo"
    fi

    print_info "Attempting to install missing packages using $distro package manager..."

    case $distro in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
            $sudo_cmd apt-get update
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        fedora|rhel|centos|rocky|almalinux|ol|amzn)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        arch|manjaro|endeavouros|artix)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        alpine)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        opensuse*|suse|sles)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        void)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        gentoo)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        slackware)
            $sudo_cmd $install_cmd "${missing_packages[@]}"
            ;;
        macos)
            if [ "$install_cmd" != "unknown" ]; then
                $install_cmd "${missing_packages[@]}"
            else
                print_error "Homebrew or MacPorts not found. Please install manually."
                return 1
            fi
            ;;
        *)
            print_error "Unsupported distribution for auto-install"
            print_info "Please manually install: ${missing_packages[*]}"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        print_success "Successfully installed packages"
        return 0
    else
        print_error "Failed to install packages"
        return 1
    fi
}

# Find existing Transmission blocklist directory or use fallback
find_transmission_dir() {
    local found_dir=""

    print_step "2/11" "Detecting Transmission blocklist directory..."

    for dir in "${TRANSMISSION_PATHS[@]}"; do
        if [ -d "$dir" ]; then
            found_dir="$dir"
            print_success "Found Transmission directory: $found_dir"
            break
        fi
    done

    if [ -n "$found_dir" ]; then
        TRANSMISSION_BLOCKLIST_DIR="$found_dir"
    else
        TRANSMISSION_BLOCKLIST_DIR="$SCRIPT_DIR"
        print_warning "No Transmission directory found, using script directory as fallback"
        print_info "  Blocklist will be available at: $TRANSMISSION_BLOCKLIST_DIR"
    fi

    # Create directory if it doesn't exist (for fallback)
    mkdir -p "$TRANSMISSION_BLOCKLIST_DIR"
}

# 🌐 Curated 2026 Sources
SOURCES=(
    # --- PRIMARY P2P LISTS (Copyright Trolls & Monitoring) ---
    "https://github.com/Naunter/BT_BlockLists/raw/master/list_1.txt"       # Global P2P Blocklist
    "https://github.com/Naunter/BT_BlockLists/raw/master/list_2.txt"       # Extended P2P
    "https://raw.githubusercontent.com/mxdpeep/p2p-blocklist-creator/master/blocklist.p2p"

    # --- SECURITY & MALWARE ---
    "https://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz" # I-Blocklist Level 1
    "https://list.iblocklist.com/?list=bt_spyware&fileformat=p2p&archiveformat=gz" # Known Spyware

    # --- INFRASTRUCTURE & BOGONS (Non-routable IPs) ---
    "https://list.iblocklist.com/?list=bt_bogon&fileformat=p2p&archiveformat=gz"

    # --- NIGHTLY COMMUNITY LISTS ---
    "https://www.ipfilter.app/nightly/ipfilter.dat.gz"
    "https://github.com/sefinek/Sefinek-Blocklist-Collection/raw/main/p2p/p2p-blocklist.p2p"
)

# Print colored output functions
print_step() {
    echo -e "${PURPLE}[STEP ${1}]${NC} ${2}"
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

print_footer() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to check dependencies with auto-install
check_dependencies() {
    print_step "1/11" "Checking dependencies..."

    local missing_deps=()
    local all_packages=()

    # Required dependencies
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
        all_packages+=("curl")
    fi

    if ! command -v gunzip &> /dev/null; then
        # gunzip is part of gzip package
        missing_deps+=("gzip")
        all_packages+=("gzip")
    fi

    if ! command -v zip &> /dev/null; then
        missing_deps+=("zip")
        all_packages+=("zip")
        print_warning "zip not found - will attempt to install"
    fi

    if ! command -v transmission-remote &> /dev/null; then
        print_info "transmission-remote not found - will skip Transmission update"
        # Not adding to missing_deps as it's optional
    fi

    # Handle missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_warning "Missing packages: ${missing_deps[*]}"

        if [ "$AUTO_INSTALL_DEPS" = true ]; then
            print_info "Auto-install is enabled, attempting to install missing packages..."

            if install_deps "${all_packages[@]}"; then
                print_success "All dependencies installed successfully"

                # Verify installations
                local failed=()
                for pkg in "${missing_deps[@]}"; do
                    case $pkg in
                        curl)
                            if ! command -v curl &> /dev/null; then
                                failed+=("$pkg")
                            fi
                            ;;
                        gzip)
                            if ! command -v gunzip &> /dev/null; then
                                failed+=("$pkg")
                            fi
                            ;;
                        zip)
                            if ! command -v zip &> /dev/null; then
                                failed+=("$pkg")
                            fi
                            ;;
                    esac
                done

                if [ ${#failed[@]} -gt 0 ]; then
                    print_error "Failed to install: ${failed[*]}"
                    print_info "Please install manually and try again"
                    exit 1
                fi
            else
                print_error "Failed to install dependencies"
                exit 1
            fi
        else
            print_error "Missing required dependencies"
            print_info "Please install: ${missing_deps[*]}"
            local distro=$(detect_distro)
            local install_cmd=$(get_package_manager "$distro")

            if [ "$install_cmd" != "unknown" ]; then
                print_info "For $distro, use: sudo $install_cmd ${all_packages[*]}"
            fi
            exit 1
        fi
    fi

    # Show final status
    print_success "All required dependencies are available"

    # Show optional package status
    if command -v transmission-remote &> /dev/null; then
        print_info "transmission-remote: available"
    fi

    log_message "Dependencies check passed"
}

# Function to create header in the blocklist file
create_header() {
    local list_file="$1"
    local entry_count="$2"

    cat > "$list_file" << EOF
#############################################################################################################################
#
# Wael Isa - www.wael.name
# Blacklist for P2P network
# Ver (super-list) 1.0.1
# Build Date: $(date '+%Y/%m/%d')
# Total Entries: ${entry_count}
#
# I remove some IP'S from this list because we don't need it,
# Only i list IP'S that report your IP for copyright,
# So keep sharing and have fun,
# if you have any ideas please report here
# https://github.com/waelisa/Best-blocklist
#
#############################################################################################################################

EOF
}

# Function to add footer to the blocklist file
add_footer() {
    local list_file="$1"

    cat >> "$list_file" << EOF

#############################################################################################################################
# END
#############################################################################################################################
EOF
}

# Function to check Transmission status
check_transmission_status() {
    local transmission_running=false
    local transmission_remote_found=false

    if command -v transmission-remote &> /dev/null; then
        transmission_remote_found=true
        # Check if Transmission daemon is responding
        if transmission-remote -si &> /dev/null 2>&1; then
            transmission_running=true
        fi
    fi

    if [ "$transmission_running" = true ]; then
        echo "running"
    elif [ "$transmission_remote_found" = true ]; then
        echo "daemon_not_running"
    else
        echo "not_installed"
    fi
}

# Main build function
build_blocklist() {
    print_header "🚀 Starting Master Blocklist Build - Version 1.0.1"
    print_info "Detected OS: $(detect_distro)"
    log_message "Starting blocklist build process on $(detect_distro)"

    # Step 2: Detect Transmission directory
    find_transmission_dir

    # Step 3: Clean work directory but keep the directory itself
    print_step "3/11" "Preparing work directory..."
    rm -rf "$WORK_DIR"/* 2>/dev/null
    mkdir -p "$WORK_DIR"
    print_success "Work directory cleaned: $WORK_DIR"

    # Step 4: Download sources
    print_step "4/11" "Downloading ${#SOURCES[@]} blocklist sources..."
    local source_count=0
    local success_count=0

    > "$TEMP_RAW"  # Clear temp file

    for url in "${SOURCES[@]}"; do
        source_count=$((source_count + 1))
        echo -ne "\r  Downloading source ${source_count}/${#SOURCES[@]}: $(basename "$url")... "

        # Handle both GZipped and plain text files
        if [[ "$url" == *.gz* ]] || [[ "$url" == *ipfilter.dat* ]]; then
            if curl -sL --connect-timeout 10 --max-time 30 "$url" | gunzip -c >> "$TEMP_RAW" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                success_count=$((success_count + 1))
            else
                # Fallback to direct download if gunzip fails
                if curl -sL --connect-timeout 10 --max-time 30 "$url" >> "$TEMP_RAW" 2>/dev/null; then
                    echo -e "${YELLOW}⚠ (fallback)${NC}"
                    success_count=$((success_count + 1))
                else
                    echo -e "${RED}✗${NC}"
                    print_warning "Failed to download: $url"
                fi
            fi
        else
            if curl -sL --connect-timeout 10 --max-time 30 "$url" >> "$TEMP_RAW" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                success_count=$((success_count + 1))
            else
                echo -e "${RED}✗${NC}"
                print_warning "Failed to download: $url"
            fi
        fi
    done

    echo ""
    print_success "Downloaded $success_count/$source_count sources successfully"
    log_message "Downloaded $success_count/$source_count sources"

    # Step 5: Count raw entries
    print_step "5/11" "Processing raw data..."
    local raw_count=$(wc -l < "$TEMP_RAW")
    print_info "Raw entries before cleaning: $raw_count"

    # Step 6: Data cleaning engine
    print_step "6/11" "Cleaning and deduplicating data..."

    # Create a temporary cleaned file
    local temp_clean="${WORK_DIR}/cleaned.tmp"

    # 1. Remove comments (#) and empty lines
    # 2. Ensure format has colon (Description:Start-End)
    # 3. Sort and remove duplicates
    grep -v '^#' "$TEMP_RAW" | \
        grep -v '^$' | \
        grep ':' | \
        sort -u > "$temp_clean"

    local cleaned_count=$(wc -l < "$temp_clean")
    print_success "Cleaned entries: $cleaned_count"
    log_message "Cleaned $cleaned_count entries from $raw_count raw entries"

    # Step 7: Create final list with header and footer in work directory
    print_step "7/11" "Creating final blocklist with header and footer..."

    # Start with a fresh file
    > "$FINAL_LIST"

    # Add header with entry count
    create_header "$FINAL_LIST" "$cleaned_count"

    # Add cleaned data
    cat "$temp_clean" >> "$FINAL_LIST"

    # Add footer
    add_footer "$FINAL_LIST"

    local final_count=$((cleaned_count))
    print_success "Final list created in work directory with $final_count unique IP ranges"

    # Step 8: Copy final files to destinations
    print_step "8/11" "Copying files to destinations..."

    # Copy plain file to script directory (always do this)
    cp "$FINAL_LIST" "$FINAL_PLAIN"
    print_success "Plain file copied to: $FINAL_PLAIN"

    # Copy to Transmission directory
    cp "$FINAL_LIST" "$TRANSMISSION_BLOCKLIST_DIR/"
    print_success "Copied to Transmission: $TRANSMISSION_BLOCKLIST_DIR/${FINAL_LIST_NAME}"

    # Create ZIP file (zip should be available now)
    if command -v zip &> /dev/null; then
        rm -f "$FINAL_ZIP" 2>/dev/null
        (cd "$WORK_DIR" && zip -q "$FINAL_ZIP" "$FINAL_LIST_NAME")
        print_success "Created ZIP archive: $FINAL_ZIP"
    else
        print_error "zip still not available after installation attempt"
        print_warning "Skipping ZIP creation"
    fi

    # Step 9: Trigger Transmission update
    print_step "9/11" "Checking Transmission status..."
    local trans_status=$(check_transmission_status)

    case "$trans_status" in
        "running")
            print_info "Transmission daemon is running, updating blocklist..."
            if transmission-remote --blocklist-update &> /dev/null; then
                print_success "Transmission blocklist update triggered successfully"
            else
                print_warning "Failed to update Transmission blocklist"
            fi
            ;;
        "daemon_not_running")
            print_warning "Transmission remote found but daemon not running"
            print_info "  Blocklist copied to: $TRANSMISSION_BLOCKLIST_DIR/${FINAL_LIST_NAME}"
            print_info "  Start Transmission and run: transmission-remote --blocklist-update"
            ;;
        "not_installed")
            print_info "Transmission not installed - blocklist saved to script directory only"
            ;;
    esac

    # Step 10: Clean up work directory (keep only log file)
    print_step "10/11" "Cleaning up work directory..."

    # Remove all files except the log file
    find "$WORK_DIR" -type f -not -name "$(basename "$LOG_FILE")" -delete

    # Also remove empty directories if any
    find "$WORK_DIR" -type d -empty -delete 2>/dev/null

    # Recreate work directory if it was deleted
    mkdir -p "$WORK_DIR"

    print_success "Work directory cleaned (kept only log file)"

    # Step 11: Final verification
    print_step "11/11" "Verifying output files..."

    if [ -f "$FINAL_PLAIN" ]; then
        local final_size=$(du -h "$FINAL_PLAIN" | cut -f1)
        print_success "Plain file: $FINAL_PLAIN ($final_size)"
    fi

    if [ -f "$FINAL_ZIP" ]; then
        local zip_size=$(du -h "$FINAL_ZIP" | cut -f1)
        print_success "ZIP file: $FINAL_ZIP ($zip_size)"
    fi

    # Clean up temporary files
    rm -f "$TEMP_RAW" "$temp_clean"

    # Final summary
    print_header "📊 Build Summary"
    echo -e "${GREEN}  ✓ Final plain file:${NC} $FINAL_PLAIN"
    if [ -f "$FINAL_ZIP" ]; then
        echo -e "${GREEN}  ✓ ZIP archive:${NC} $FINAL_ZIP"
    else
        echo -e "${YELLOW}  ⚠ ZIP archive:${NC} Not created"
    fi
    echo -e "${GREEN}  ✓ Transmission copy:${NC} $TRANSMISSION_BLOCKLIST_DIR/${FINAL_LIST_NAME}"
    echo -e "${GREEN}  ✓ Entries:${NC} $final_count unique IP ranges"
    echo -e "${GREEN}  ✓ Work directory:${NC} $WORK_DIR (empty except log file)"
    echo -e "${GREEN}  ✓ Log file:${NC} $LOG_FILE"
    print_footer

    log_message "Build completed successfully with $final_count entries"

    # Final message
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Blocklist build complete! Share and have fun!${NC}"

    if [ "$TRANSMISSION_BLOCKLIST_DIR" = "$SCRIPT_DIR" ]; then
        echo -e "${YELLOW}  ⚠ No Transmission directory found - files saved to script folder${NC}"
    fi

    if [ ! -f "$FINAL_ZIP" ]; then
        echo -e "${YELLOW}  ⚠ ZIP file not created - check zip installation${NC}"
    fi

    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to show help
show_help() {
    echo -e "${CYAN}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean work directory and exit"
    echo "  -v, --version  Show version information"
    echo "  -p, --paths    Show detected Transmission paths"
    echo "  --no-install   Disable auto-install of dependencies"
    echo ""
    echo "Description:"
    echo "  Builds a comprehensive P2P blocklist from multiple sources"
    echo "  and updates Transmission's blocklist if found."
    echo "  Automatically installs missing dependencies (curl, gzip, zip)."
    echo ""
    echo "Files:"
    echo "  Work directory: $WORK_DIR"
    echo "  Final plain:    $FINAL_PLAIN"
    echo "  ZIP archive:    $FINAL_ZIP"
    echo "  Log file:       $LOG_FILE"
    echo ""
    echo "Supported Distributions:"
    echo "  - Debian/Ubuntu (apt)"
    echo "  - Fedora/RHEL/CentOS (dnf/yum)"
    echo "  - Arch/Manjaro (pacman)"
    echo "  - Alpine (apk)"
    echo "  - openSUSE (zypper)"
    echo "  - Void Linux (xbps)"
    echo "  - Gentoo (emerge)"
    echo "  - Slackware (slackpkg)"
    echo "  - macOS (Homebrew/MacPorts)"
}

# Function to show paths
show_paths() {
    echo -e "${CYAN}Transmission Path Detection:${NC}"
    echo ""
    echo "Checking common Transmission paths:"

    for dir in "${TRANSMISSION_PATHS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✓${NC} $dir ${GREEN}(exists)${NC}"
        else
            echo -e "  ${RED}✗${NC} $dir"
        fi
    done

    echo ""
    find_transmission_dir
    echo -e "\n${GREEN}Selected directory:${NC} $TRANSMISSION_BLOCKLIST_DIR"
}

# Main execution
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                echo "Cleaning work directory: $WORK_DIR"
                rm -rf "$WORK_DIR"/*
                echo "Done"
                exit 0
                ;;
            -v|--version)
                echo "P2P Blocklist Builder version 1.0.1"
                echo "Author: Wael Isa - www.wael.name"
                exit 0
                ;;
            -p|--paths)
                show_paths
                exit 0
                ;;
            --no-install)
                AUTO_INSTALL_DEPS=false
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h for help"
                exit 1
                ;;
        esac
    done

    # Welcome message
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Wael's P2P Blocklist Builder v1.0.1${NC}"
    echo -e "${GREEN}  Auto-install: ${AUTO_INSTALL_DEPS}${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Check dependencies (with auto-install)
    check_dependencies

    # Build the blocklist
    build_blocklist

    # Final footer
    cat << "EOF"

    ╔══════════════════════════════════════════════════════════════╗
    ║  Thank you for using Wael's P2P Blocklist Builder            ║
    ║  Remember: Keep sharing, have fun, and stay safe!           ║
    ║  https://github.com/waelisa/Best-blocklist                   ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
}

# Run main function with all arguments
main "$@"
