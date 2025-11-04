#!/bin/bash

# ====================================
# Lightroom Classic Backup Script
# ====================================
# Backs up Lightroom Classic presets, masks, exports, and settings

# Configuration - Edit this path to your desired backup location
BACKUP_ROOT="/Users/rayalner/Sparkbytes Dropbox/Ray Alner/0Pictures/0 Lightroom Files/Watermark&Presets/Backups"

# ====================================
# DO NOT EDIT BELOW THIS LINE
# ====================================

# Lightroom source directory
LR_SOURCE="$HOME/Library/Application Support/Adobe/Lightroom"

# Create timestamped backup folder
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/LR_Backup_$TIMESTAMP"

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Lightroom Classic Backup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Lightroom directory exists
if [ ! -d "$LR_SOURCE" ]; then
    echo -e "${RED}ERROR: Lightroom directory not found at:${NC}"
    echo -e "${RED}$LR_SOURCE${NC}"
    echo ""
    echo "Please verify Lightroom Classic is installed."
    exit 1
fi

# Create backup root directory if it doesn't exist
if [ ! -d "$BACKUP_ROOT" ]; then
    echo -e "${YELLOW}Creating backup root directory...${NC}"
    mkdir -p "$BACKUP_ROOT"
fi

# Create timestamped backup directory
echo -e "${YELLOW}Creating backup directory:${NC}"
echo -e "  $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
echo ""

# Function to backup a directory
backup_directory() {
    local source_dir="$1"
    local dir_name="$2"
    local dest_dir="$BACKUP_DIR/$dir_name"

    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}${NC} Backing up: $dir_name"
        mkdir -p "$dest_dir"
        cp -R "$source_dir"/* "$dest_dir/" 2>/dev/null

        # Count files copied
        local file_count=$(find "$dest_dir" -type f | wc -l | tr -d ' ')
        echo -e "  ${BLUE}�${NC} $file_count files copied"
    else
        echo -e "${YELLOW}�${NC} Skipping: $dir_name (directory not found)"
    fi
}

echo -e "${BLUE}Starting backup process...${NC}"
echo ""

# Backup all important Lightroom directories
backup_directory "$LR_SOURCE/Develop Presets" "Develop Presets"
backup_directory "$LR_SOURCE/Export Presets" "Export Presets"
backup_directory "$LR_SOURCE/Local Adjustment Presets" "Local Adjustment Presets (Masks)"
backup_directory "$LR_SOURCE/Metadata Presets" "Metadata Presets"
backup_directory "$LR_SOURCE/Filename Templates" "Filename Templates"
backup_directory "$LR_SOURCE/Text Templates" "Text Templates"
backup_directory "$LR_SOURCE/Watermark Presets" "Watermark Presets"
backup_directory "$LR_SOURCE/Filter Presets" "Filter Presets"
backup_directory "$LR_SOURCE/Slideshow Templates" "Slideshow Templates"
backup_directory "$LR_SOURCE/Print Templates" "Print Templates"
backup_directory "$LR_SOURCE/Web Galleries" "Web Galleries"
backup_directory "$LR_SOURCE/Lightroom Settings" "Lightroom Settings"

# Create a backup info file
INFO_FILE="$BACKUP_DIR/backup_info.txt"
{
    echo "Lightroom Classic Backup"
    echo "========================"
    echo ""
    echo "Backup Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Source: $LR_SOURCE"
    echo "Destination: $BACKUP_DIR"
    echo ""
    echo "System Information:"
    echo "  macOS Version: $(sw_vers -productVersion)"
    echo "  Computer Name: $(scutil --get ComputerName)"
    echo ""
    echo "Backup Contents:"
    find "$BACKUP_DIR" -type f | sed "s|$BACKUP_DIR/||" | sort
} > "$INFO_FILE"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN} Backup completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Backup location:"
echo -e "  ${GREEN}$BACKUP_DIR${NC}"
echo ""

# Calculate total size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | awk '{print $1}')
echo -e "Total backup size: ${GREEN}$TOTAL_SIZE${NC}"
echo ""

# Count total files
TOTAL_FILES=$(find "$BACKUP_DIR" -type f -not -name "backup_info.txt" | wc -l | tr -d ' ')
echo -e "Total files backed up: ${GREEN}$TOTAL_FILES${NC}"
echo ""

echo -e "${YELLOW}Tip:${NC} Old backups in $BACKUP_ROOT can be manually deleted to save space."
echo ""
