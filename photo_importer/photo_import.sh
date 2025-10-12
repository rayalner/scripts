#!/bin/bash

# Photo Import Script for Mac
# Imports photos from SD card with proper organization

#put your destination here
DESTINATION_ROOT="/Volumes/Rays Photos/Rays Photos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Function to find SD cards
find_sd_cards() {
    local cards=()
    
    # Get all mounted volumes
    for volume in /Volumes/*; do
        if [ -d "$volume" ] && [ "$(basename "$volume")" != "Macintosh HD" ] && [ "$(basename "$volume")" != "Rays Photos" ]; then
            # Check for DCIM folder (typical camera structure)
            if [ -d "$volume/DCIM" ]; then
                cards+=("$volume")
            else
                # Only include volumes that actually contain media files
                if find "$volume" -maxdepth 5 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.awr" -o -iname "*.cr2" -o -iname "*.nef" \) -print -quit 2>/dev/null | grep -q .; then
                    cards+=("$volume")
                fi
            fi
        fi
    done
    
    printf '%s\n' "${cards[@]}"
}

# Function to get file type based on extension
get_file_type() {
    local file="$1"
    local extension="${file##*.}"
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    
    case "$extension" in
        mp4|mov|avi|mkv|m4v|3gp|mts|m2ts)
            echo "video"
            ;;
        awr|cr2|cr3|nef|arw|dng|raw|orf|rw2)
            echo "raw"
            ;;
        jpg|jpeg|png|tiff|tif|heic|webp)
            echo "photo"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# Function to get file creation date in MM-DD-YY format
get_file_date() {
    local file="$1"
    # Use stat to get file modification time and format it
    local file_date=$(stat -f "%Sm" -t "%m-%d-%y" "$file" 2>/dev/null)
    echo "$file_date"
}

# Function to get file year
get_file_year() {
    local file="$1"
    # Use stat to get file modification time and format it as year
    local file_year=$(stat -f "%Sm" -t "%Y" "$file" 2>/dev/null)
    echo "$file_year"
}

# Function to scan for all unique dates on the card
scan_dates() {
    local source_volume="$1"
    local temp_dates="/tmp/dates_scan_$$"
    
    print_status "Scanning for file dates..." >&2
    
    # Find all media files and get their dates (suppress permission errors)
    find "$source_volume" -type f ! -name ".*" ! -path "*/.*" 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local extension="${filename##*.}"
            extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
            
            # Skip system/metadata files (camera and DJI files)
            case "$extension" in
                ind|thm|xml|bdm|bin|int|bnp|inp|scr|db|lrf)
                    continue
                    ;;
            esac
            
            # Get file date and add to list
            local file_date=$(get_file_date "$file")
            if [ -n "$file_date" ]; then
                echo "$file_date"
            fi
        fi
    done | sort -u
}

# Function to get shoot names for each date
get_shoot_names() {
    local dates=("$@")
    
    echo "Found photos from ${#dates[@]} different date(s):"
    for date in "${dates[@]}"; do
        echo "  $date"
    done
    echo
    
    # Use simple approach instead of associative arrays
    for date in "${dates[@]}"; do
        while true; do
            read -p "Enter shoot name for $date: " shoot_name
            if [ -n "$shoot_name" ]; then
                echo "$date=$shoot_name"
                break
            else
                print_warning "Shoot name cannot be empty."
            fi
        done
    done
}

# Function to create destination folder for a specific date
create_date_destination() {
    local date="$1"
    local shoot_name="$2"
    local year="$3"
    local folder_name="${date} ${shoot_name}"
    local destination="$DESTINATION_ROOT/$year/$folder_name"
    
    # Create year folder and main folder
    mkdir -p "$destination"
    
    echo "$destination"
}

# Function to copy files with organization by date
copy_files_by_date() {
    local source_volume="$1"
    shift
    local shoot_names=("$@")
    local temp_log="/tmp/photo_import_$$"
    
    # Function to get shoot name for a date
    get_shoot_name_for_date() {
        local target_date="$1"
        for entry in "${shoot_names[@]}"; do
            local date="${entry%=*}"
            local name="${entry#*=}"
            if [ "$date" = "$target_date" ]; then
                echo "$name"
                return
            fi
        done
    }
    
    print_status "Scanning files for copy..." >&2

    # First pass: count total files to copy
    local temp_file_list="/tmp/file_list_$$"
    find "$source_volume" -type f ! -name ".*" ! -path "*/.*" 2>/dev/null > "$temp_file_list"

    local total_files=0
    while read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local extension="${filename##*.}"
            extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

            # Skip system/metadata files in count
            case "$extension" in
                ind|thm|xml|bdm|bin|int|bnp|inp)
                    continue
                    ;;
            esac
            ((total_files++))
        fi
    done < "$temp_file_list"

    if [ "$total_files" -eq 0 ]; then
        print_warning "No files found to copy." >&2
        rm -f "$temp_file_list"
        echo "$temp_log"
        return
    fi

    print_status "Copying $total_files files to date-specific folders..." >&2

    # Clear the log file
    > "$temp_log"

    # Second pass: copy files with progress
    local current_file=0
    while read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local extension="${filename##*.}"
            extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
            
            # Skip system/metadata files (camera and DJI files)
            case "$extension" in
                ind|thm|xml|bdm|bin|int|bnp|inp|scr|db|lrf)
                    continue
                    ;;
            esac

            ((current_file++))

            # Calculate and display progress
            local percent=$((current_file * 100 / total_files))
            local progress_bar=""
            local filled=$((percent / 2))
            local empty=$((50 - filled))

            for ((i=0; i<filled; i++)); do
                progress_bar+="█"
            done
            for ((i=0; i<empty; i++)); do
                progress_bar+="░"
            done

            # Show progress (simplified for debugging)
            if [ $((current_file % 10)) -eq 0 ] || [ "$current_file" -eq "$total_files" ]; then
                printf "\r\033[2K${BLUE}[INFO]${NC} Progress: %d%% (%d/%d)" "$percent" "$current_file" "$total_files"
            fi

            # Get file date, year and corresponding destination
            local file_date=$(get_file_date "$file")
            local file_year=$(get_file_year "$file")
            local shoot_name=$(get_shoot_name_for_date "$file_date")
            
            if [ -z "$shoot_name" ]; then
                print_warning "No shoot name found for date $file_date, skipping $filename"
                continue
            fi
            
            local destination=$(create_date_destination "$file_date" "$shoot_name" "$file_year")
            local file_type=$(get_file_type "$filename")
            
            # Determine destination subfolder
            if [ "$file_type" = "other" ]; then
                local dest_dir="$destination"
            else
                local dest_dir="$destination/$file_type"
                
                # Create subfolder only when needed
                if [ ! -d "$dest_dir" ]; then
                    mkdir -p "$dest_dir"
                    print_status "Created $file_type folder in $(basename "$destination")" >&2
                fi
            fi
            
            # Handle duplicate filenames
            local dest_file="$dest_dir/$filename"
            local counter=1
            while [ -f "$dest_file" ]; do
                local name_without_ext="${filename%.*}"
                local ext="${filename##*.}"
                if [ "$name_without_ext" != "$filename" ]; then
                    dest_file="$dest_dir/${name_without_ext}_${counter}.${ext}"
                else
                    dest_file="$dest_dir/${filename}_${counter}"
                fi
                ((counter++))
            done
            
            # Copy file silently to avoid interfering with progress bar
            if cp -p "$file" "$dest_file"; then
                echo "$file|$dest_file" >> "$temp_log"
            else
                printf "\n" >&2
                print_error "Failed to copy $file" >&2
                exit 1
            fi
        fi
    done < "$temp_file_list"

    # Clear progress line and show completion
    printf "\n" >&2
    print_success "Completed copying $total_files files!" >&2

    # Clean up temp file
    rm -f "$temp_file_list"

    echo "$temp_log"
}

# Function to verify copied files
verify_files() {
    local log_file="$1"
    local failed_count=0
    
    print_status "Verifying copied files..."
    
    while IFS='|' read -r source dest; do
        if [ ! -f "$dest" ]; then
            print_error "Missing file: $dest"
            ((failed_count++))
            continue
        fi
        
        # Compare file sizes (faster than checksums for basic verification)
        local source_size=$(stat -f%z "$source" 2>/dev/null)
        local dest_size=$(stat -f%z "$dest" 2>/dev/null)
        
        if [ "$source_size" != "$dest_size" ]; then
            print_error "Size mismatch: $(basename "$dest")"
            ((failed_count++))
        fi
    done < "$log_file"
    
    return $failed_count
}

# Function to eject volume
eject_volume() {
    local volume="$1"

    print_status "Ejecting $(basename "$volume")..."

    # Get the device identifier for more reliable ejection
    local device=$(diskutil info "$volume" 2>/dev/null | grep "Device Node:" | awk '{print $3}')

    if [ -n "$device" ]; then
        print_status "Found device: $device"
    fi

    # Try multiple ejection methods
    if [ -n "$device" ] && diskutil eject "$device" 2>/dev/null; then
        print_success "Successfully ejected $(basename "$volume") via device"
        return 0
    elif diskutil eject "$volume" 2>/dev/null; then
        print_success "Successfully ejected $(basename "$volume") via volume path"
        return 0
    elif diskutil unmount "$volume" 2>/dev/null; then
        print_success "Successfully unmounted $(basename "$volume")"
        return 0
    else
        print_error "Failed to eject $(basename "$volume")"
        print_error "You may need to eject manually from Finder"
        return 1
    fi
}

# Main function
main() {
    echo "=============================="
    echo "    Photo Import Tool (Mac)   "
    echo "=============================="
    echo
    
    # Check if destination root exists
    if [ ! -d "$DESTINATION_ROOT" ]; then
        print_error "Destination path does not exist: $DESTINATION_ROOT"
        exit 1
    fi
    
    # Find SD cards
    print_status "Scanning for removable media..."
    
    # Get SD cards using a temp file for compatibility
    local temp_file="/tmp/sd_cards_$$"
    find_sd_cards > "$temp_file"
    
    # Read into array
    sd_cards=()
    while IFS= read -r line; do
        sd_cards+=("$line")
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ ${#sd_cards[@]} -eq 0 ]; then
        print_error "No SD cards or removable media found."
        exit 1
    fi
    
    echo "Found ${#sd_cards[@]} removable volume(s):"
    for i in "${!sd_cards[@]}"; do
        echo "$((i+1)). $(basename "${sd_cards[i]}")"
    done
    echo
    
    # Select SD card
    local selected_card
    if [ ${#sd_cards[@]} -eq 1 ]; then
        selected_card="${sd_cards[0]}"
        print_status "Using: $(basename "$selected_card")"
    else
        while true; do
            read -p "Select card number (1-${#sd_cards[@]}): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#sd_cards[@]} ]; then
                selected_card="${sd_cards[$((choice-1))]}"
                break
            else
                print_warning "Invalid selection. Please enter a number between 1 and ${#sd_cards[@]}."
            fi
        done
    fi
    
    # Scan for dates on the card
    local temp_dates="/tmp/dates_$$"
    scan_dates "$selected_card" > "$temp_dates"
    
    unique_dates=()
    while IFS= read -r line; do
        unique_dates+=("$line")
    done < "$temp_dates"
    rm -f "$temp_dates"
    
    if [ ${#unique_dates[@]} -eq 0 ]; then
        print_error "No media files with valid dates found on the card."
        exit 1
    fi
    
    # Get shoot names for each date
    local temp_pairs="/tmp/pairs_$$"
    get_shoot_names "${unique_dates[@]}" > "$temp_pairs"
    
    shoot_name_pairs=()
    while IFS= read -r line; do
        shoot_name_pairs+=("$line")
    done < "$temp_pairs"
    rm -f "$temp_pairs"
    
    # Copy files organized by date
    print_status "Starting file copy..."
    log_file=$(copy_files_by_date "$selected_card" "${shoot_name_pairs[@]}")
    
    if [ $? -ne 0 ]; then
        print_error "File copy failed."
        exit 1
    fi
    
    # Count copied files
    if [ -f "$log_file" ]; then
        file_count=$(wc -l < "$log_file" 2>/dev/null || echo "0")
    else
        print_error "Log file not found: $log_file"
        file_count=0
    fi

    if [ "$file_count" -eq 0 ]; then
        print_warning "No files found to copy."
        rm -f "$log_file"
        exit 0
    fi
    
    print_success "Copied $file_count files."

    # Verify files
    print_status "Starting verification process..."
    if verify_files "$log_file"; then
        print_success "All files verified successfully!"

        # Clean up log file
        rm -f "$log_file"

        # Ask about ejection
        print_status "DEBUG: About to ask for ejection"
        echo
        read -p "Eject SD card? (y/n): " eject_choice
        case "$eject_choice" in
            [Yy]|[Yy][Ee][Ss])
                if eject_volume "$selected_card"; then
                    print_success "Import complete!"
                else
                    print_warning "Import complete, but manual ejection required."
                fi
                ;;
            *)
                print_success "Import complete. SD card not ejected."
                ;;
        esac
    else
        print_error "File verification failed. SD card will NOT be ejected."
        print_error "Please check the copied files manually."
        rm -f "$log_file"
        exit 1
    fi

    print_status "DEBUG: Script reached end of main function"
}

# Run main function
main "$@"