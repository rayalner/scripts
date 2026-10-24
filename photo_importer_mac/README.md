# Photo Import Tool

A set of scripts to import photos from SD cards with automatic organization by date and file type.

## Original Request

Create a script that can import photos from an SD card on Mac and put them in `my_photos` in a new folder with the date formatted as MM-DD-YY [shoot name] where [shoot name] is requested by the script.

### Key Requirements

1. **File Organization**: Detect each type of file and put them in different folders:
   - Video files → `video/` folder
   - .awr (raw) files → `raw/` folder  
   - .jpg files → `photo/` folder

2. **System File Filtering**: Skip unwanted camera system files:
   - Camera files: `.IND`, `.THM`, `.XML`, `.BDM`, `.BIN`, `.INT`, `.BNP`, `.INP`
   - DJI files: `.SCR`, `.DB`, `.LRF`

3. **Date-Based Folder Creation**: 
   - Read file creation dates from photos
   - Create separate folders for each unique date found
   - Ask user for shoot name for each date
   - Format: `MM-DD-YY [shoot name]`

4. **Year-Based Organization**:
   - Automatically detect file years
   - Create year folders under `my_photos`
   - Structure: `my_photos\photos`

5. **Safety Features**:
   - Verify files were copied correctly before ejecting
   - Read-only operations on source (never delete from SD card)
   - Only create file type folders when needed
   - Handle duplicate filenames automatically

6. **SD Card Management**:
   - Auto-detect SD cards/removable media
   - Safe ejection after successful copy and verification

## Available Scripts

### Mac Version: `photo_import.sh`
Bash script for macOS using native disk utilities.

**Configuration:**
Edit the destination paths at the top of the script (lines 8-12):
```bash
DESTINATIONS=(
    "External Drive (Rays Photos)|/Volumes/Rays Photos/Rays Photos"
    "NAS (RaysMedia)|/Volumes/RaysMedia"
    "2wheelmilly|/Volumes/2wheelmilly"
)
```

To add a new destination, simply add a new line in the format:
```bash
"Display Name|/path/to/destination"
```

**Usage:**
```bash
./photo_import.sh
```

The script will automatically:
- Iterate through all defined destinations and check which are mounted
- If only one is available, use it automatically
- If multiple are available, prompt you to choose
- If none are available, display all defined destinations and wait for you to connect storage

### Windows Version: `photo_import.ps1`
PowerShell script for Windows with WMI integration.

**Usage:**
```powershell
.\photo_import.ps1
```

**Or with custom destination:**
```powershell
.\photo_import.ps1 -DestinationRoot "E:\My Photos\My Photos"
```

### Python Version: `photo_import.py`
Cross-platform Python script with MD5 verification.

**Usage:**
```bash
python3 photo_import.py
```

## Workflow Example

1. Insert SD card
2. Run script
3. Script detects card and scans for file dates
4. User provides shoot names for each date found:
   ```
   Found photos from 2 different date(s):
     01-15-25
     01-16-25

   Enter shoot name for 01-15-25: Wedding Prep
   Enter shoot name for 01-16-25: Wedding Ceremony
   ```
5. Script creates folders and copies files:
   ```
   volume/01-15-25 Wedding Prep/
   ├── photo/
   ├── video/
   └── raw/

   volume/2025/01-16-25 Wedding Ceremony/
   ├── photo/
   └── video/
   ```
6. Copy summary shows what was processed:
   ```
   Completed processing 150 files!
   Copied: 45 files
   Skipped (already exists): 105 files
   ```
7. Verification confirms all files copied correctly:
   ```
   Verified 45 newly copied files
   105 files were already present and skipped
   ```
8. Safe ejection of SD card

## Multi-Camera Workflow

For shoots using multiple cameras (e.g., DJI Pocket 3 + Sony), run the script separately for each SD card:

1. **First Camera (e.g., DJI)**:
   ```
   Insert DJI SD card → Run script → Enter "Wedding Ceremony" for 01-16-25
   ```

2. **Second Camera (e.g., Sony)**:
   ```
   Insert Sony SD card → Run script → Enter "Wedding Ceremony" for 01-16-25
   ```

3. **Result** - Files merged automatically:
   ```
   my_photos/2025/01-16-25 Wedding Ceremony/
   ├── photo/    (JPGs from both DJI and Sony)
   ├── video/    (MP4s from both cameras)
   └── raw/      (Sony RAW files)
   ```

**Key Benefits**:
- ✅ Automatically merges files into existing folders
- ✅ No overwrites - duplicate filenames get counters (IMG_1234.jpg, IMG_1234_1.jpg)
- ✅ Skips DJI system files (.SCR, .DB, .LRF) and camera metadata files
- ✅ Same shoot name ensures files go to identical folder structure

## Features

- ✅ Auto-detects SD cards/removable media
- ✅ Scans file dates and asks for shoot names per date
- ✅ Creates year-based folder structure automatically
- ✅ Organizes by file type (photo/video/raw) only when needed
- ✅ Skips all camera system files (including DJI files)
- ✅ Verifies copies before ejecting
- ✅ Read-only - never deletes source files
- ✅ Handles duplicate filenames automatically
- ✅ Real-time progress bar during file copying
- ✅ Multi-camera support (merge files from different cameras)
- ✅ Improved SD card ejection with multiple fallback methods
- ✅ Enhanced file verification before ejection
- ✅ Cross-platform support (Mac, Windows, Python)
- ✅ Smart duplicate detection (skips already-copied files)
- ✅ Detailed copy summary (copied vs skipped counts)

## Recent Updates

### v3.1 Features:
- **Smart Duplicate Detection**: Automatically detects if files have already been copied (checks filename and size)
- **Skip Already-Copied Files**: Won't re-copy files that already exist with the same size at the destination
- **Detailed Copy Summary**: Shows how many files were copied vs skipped
- **Enhanced Verification**: Only verifies newly copied files, reports on both copied and skipped files

### v3.0 Features:
- **Dynamic Destination Management**: Destinations are now defined in a simple array that the script iterates through
- **Easy Configuration**: Add or remove destinations by editing a single array - no need to modify the selection logic
- **Scalable**: Add unlimited destinations without changing any code beyond the configuration array

### v2.0 Features:
- **Enhanced Progress Tracking**: Real-time progress bar showing percentage and file count
- **Improved SD Card Detection**: More selective detection (only shows drives with actual media files)
- **Robust Ejection**: Multiple fallback methods for reliable SD card ejection
- **DJI Support**: Added exclusion for DJI system files (.SCR, .DB, .LRF, .THM)
- **Multi-Camera Workflow**: Seamless merging of files from multiple cameras for the same shoot
- **Better Error Handling**: Improved debugging and error messages

## Notes

- Destinations can be easily added/removed by editing the DESTINATIONS array at the top of the script
- Scripts are designed to be safe - they never delete or modify source files
- File type folders are only created when files of that type are found
- Year folders are created automatically based on file creation dates
- All scripts include verification steps before ejection
- Progress bar updates every 10 files for optimal performance
- The script dynamically checks which destinations are mounted and only shows available options
- **Duplicate Handling**: Files are considered duplicates if they have the same name AND size - perfect for re-running imports without copying everything again
- If a file exists with the same name but different size, it will be copied with a numbered suffix (e.g., IMG_1234_1.jpg)