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
   - `.IND`, `.THM`, `.XML`, `.BDM`, `.BIN`, `.INT`, `.BNP`, `.INP` files

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

**Usage:**
```bash
./photo_import.sh
```

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
6. Verification and safe ejection

## Features

- ✅ Auto-detects SD cards/removable media
- ✅ Scans file dates and asks for shoot names per date  
- ✅ Creates year-based folder structure automatically
- ✅ Organizes by file type (photo/video/raw) only when needed
- ✅ Skips all camera system files
- ✅ Verifies copies before ejecting
- ✅ Read-only - never deletes source files
- ✅ Handles duplicate filenames
- ✅ Cross-platform support (Mac, Windows, Python)

## Notes

- Default destination can be modified in each script
- Scripts are designed to be safe - they never delete or modify source files
- File type folders are only created when files of that type are found
- Year folders are created automatically based on file creation dates
- All scripts include verification steps before ejection