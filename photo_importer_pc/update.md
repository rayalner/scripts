OK using this folder, I want to create a new desktop app for windows that has a UI that can allow me to import photos, I want to be able to select remember pre-selected locations and also let me select the removable media to import. I want it relatively easy and also provide me with a progress bar with how long it will be to move.

---

## Questions

1. **File Organization**: When importing photos, do you want them organized in a specific folder structure (e.g., by date, by camera model, etc.) or just copied as-is to the destination?
Follow the photo_import.sh script for that information.

2. **Duplicate Handling**: How should the app handle duplicate files? Should it skip, overwrite, rename, or ask each time?
Follow the photo_import.sh script for that information.

3. **File Types**: Should it import only specific image formats (JPG, RAW, PNG, etc.) or all files from the removable media? Should it also handle videos?
Follow the photo_import.sh script for that information.

4. **Import Action**: Do you want to MOVE files (delete from source) or COPY files (keep on removable media)?
Follow the photo_import.sh script for that information.

5. **Pre-selected Locations**: Should these be:
   - Destination folders where photos will be imported TO?
   - Source folders on the removable media to import FROM?
   - Both?
Those should be asked on the UI, so the user can select where it is, or add a link where it should upload.

6. **Technology Stack**: Do you have a preference for the technology used to build this Windows desktop app (e.g., Electron, .NET/WPF, Python with Tkinter/PyQt)?
NO specific technology, but want it to be simple to build, simple to maintain.

7. **Progress Information**: Besides the progress bar, what other information would you like displayed during import (e.g., current file name, files processed count, estimated time remaining, transfer speed)?
- Progress bar
- which files are being copied
- time remaining
- time running
- transfer speed

8. **Settings Persistence**: Should the app remember your settings (pre-selected locations, preferences) between sessions?
Yes

9.  **Error Handling**: How should the app handle errors (e.g., corrupted files, insufficient disk space, write-protected files)? Show a log, skip and continue, or stop the import?
stop the import and show the alert

10. **Additional Features**: Are there any other features you'd like (e.g., preview thumbnails, metadata display, auto-eject removable media when done)?
auto eject media, follow photo_import.sh

---

## Final Questions Before Building

1. **Windows Paths**: The script uses Mac paths like `/Volumes/Rays Photos/Rays Photos` and `/Volumes/RaysMedia`. For Windows, should these be configured as:
   - `E:\Rays Photos` (external drive)
   - `\\NAS_IP\RaysMedia` (network share)
   - Or should the user configure these in the UI?
Let the user configure them on the UI, but remember last used location(or locations)

2. **Technology Choice**: Based on "simple to build, simple to maintain," I recommend **Python with PyQt5** or **Electron with React**:
   - **Python + PyQt5**: Faster to build, native-looking, smaller package size, easier maintenance
   - **Electron**: More modern UI, easier to make pretty, larger package size, more dependencies

   Which would you prefer?
   Lets go with python, if it doesnt work we can pivot to electron. I find electron very kludgy.

3. **Drive Detection on Windows**: On Windows, removable media shows up as drive letters (D:, E:, F:, etc.). Should the app:
   - Auto-detect all removable drives (USB, SD cards)?
   - Let you manually select any drive letter?
   - Both?
Let the user select the drive letter, but remember last known selection.

4. **Date Grouping UI**: The script asks for a "shoot name" for each date found on the card. Should this be:
   - A table/list where you enter shoot names for each date?
   - One-by-one prompts for each date?
   - Option to use a default name for all dates?
Follow the same naming scheme, should always be date then ask for the shoot name.

5. **Installation**: Do you want:
   - A standalone .exe file (no installation needed)?
   - An installer that puts it in Program Files?
   - Just a script you run?
standalone .exe i think will be the easiest, but may pivot to a script if its too complicated to create.