# Quick Start Guide - Photo Importer for Windows

## For Users (Running the App)

### Option 1: Use the Standalone Executable (Easiest)
1. Download `Photo Importer.exe`
2. Double-click to run
3. That's it! No installation needed.

### Option 2: Run from Python Source
1. Install Python 3.8 or higher from https://www.python.org/
2. Open Command Prompt in the app folder
3. Run:
   ```
   pip install -r requirements.txt
   python photo_importer.py
   ```

## For Developers (Building the Executable)

### On Windows:
1. Install Python 3.8+ if not already installed
2. Double-click `build.bat`
3. The executable will be created in the `dist` folder

### Manual Build:
```bash
pip install -r requirements.txt
pyinstaller --onefile --windowed --name="Photo Importer" photo_importer.py
```

## How to Use the App

1. **Launch the Application**
   - Run the executable or Python script

2. **Select Source Drive**
   - Choose the removable drive (SD card, USB) from the dropdown
   - Click "Refresh Drives" if your drive doesn't appear

3. **Select Destination Folder**
   - Click "Browse..." to select where you want to import photos
   - The app remembers your previous selections

4. **Scan Files**
   - Click "Scan Files"
   - The app will analyze all media files and group them by date

5. **Enter Shoot Names**
   - A table will appear showing each date found
   - Enter a descriptive name for each shoot
   - Example: For 01-15-25, enter "Wedding Prep"

6. **Start Import**
   - Click "Start Import"
   - Watch the progress bar and stats
   - The app shows:
     - Progress percentage
     - Current file being copied
     - Transfer speed
     - Time elapsed
     - Time remaining

7. **Wait for Verification**
   - After copying, the app verifies all files
   - This ensures nothing was corrupted during transfer

8. **Eject Drive (Optional)**
   - Click "Eject Drive" to safely remove your SD card
   - Or manually eject from File Explorer

## File Organization

Your photos will be organized as:
```
Your Destination/
└── 2025/
    ├── 01-15-25 Wedding Prep/
    │   ├── photo/
    │   │   └── IMG_1234.jpg
    │   ├── video/
    │   │   └── VID_5678.mp4
    │   └── raw/
    │       └── DSC_9012.ARW
    └── 01-16-25 Wedding Ceremony/
        ├── photo/
        └── video/
```

## Supported File Types

- **Photos**: JPG, JPEG, PNG, TIFF, TIF, HEIC, WEBP
- **Videos**: MP4, MOV, AVI, MKV, M4V, 3GP, MTS, M2TS
- **RAW**: AWR, CR2, CR3, NEF, ARW, DNG, RAW, ORF, RW2

## Troubleshooting

### Drive Not Detected
- Click "Refresh Drives"
- Make sure the SD card is properly inserted
- Try removing and reinserting the card

### Import Failed
- Check that you have enough disk space
- Make sure the destination folder is writable
- Check the log for specific error messages

### Can't Eject Drive
- Close any File Explorer windows showing the drive
- Wait a few seconds and try again
- Manually eject from File Explorer if needed

### Settings Reset
- Settings are saved in: `C:\Users\[YourName]\photo_importer_settings.json`
- Delete this file to reset all settings

## Tips

- The app remembers your last used drives and folders
- You can add multiple destination folders and switch between them
- Duplicate files are automatically renamed (IMG_1234.jpg → IMG_1234_1.jpg)
- System files and camera metadata are automatically skipped
- The app never deletes files from your SD card (read-only)
