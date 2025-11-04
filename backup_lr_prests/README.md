# Lightroom Classic Backup Script

A bash script to automatically backup all your Lightroom Classic presets, masks, export settings, and templates.

## What Gets Backed Up

This script backs up all important Lightroom Classic data including:

- **Develop Presets** - Your custom editing presets
- **Export Presets** - Export settings and configurations
- **Local Adjustment Presets (Masks)** - Saved masking presets
- **Metadata Presets** - Copyright, keywords, and other metadata templates
- **Filename Templates** - Custom filename patterns
- **Text Templates** - Text overlay templates
- **Watermark Presets** - Watermark configurations
- **Filter Presets** - Library filter settings
- **Slideshow Templates** - Slideshow configurations
- **Print Templates** - Print layout templates
- **Web Galleries** - Web gallery templates
- **Lightroom Settings** - Application settings

## Setup

1. Open the script in a text editor:
   ```bash
   nano backup_lr.sh
   ```

2. Edit the `BACKUP_ROOT` variable at the top to your preferred backup location:
   ```bash
   BACKUP_ROOT="/path/to/your/backup/folder"
   ```

3. Save and exit

## Usage

Run the script from the terminal:

```bash
./backup_lr.sh
```

Or from anywhere:
```bash
~/path/to/backup_lr.sh
```

## Features

- **Timestamped backups** - Each backup is saved with a timestamp (e.g., `LR_Backup_20251103_224340`)
- **Non-destructive** - Creates new backup folders, never overwrites existing backups
- **Detailed output** - Shows progress and file counts for each category
- **Backup info file** - Creates a `backup_info.txt` with details about what was backed up
- **Smart skipping** - Automatically skips categories you don't have
- **Size reporting** - Shows total backup size and file count

## Output Example

```
========================================
Lightroom Classic Backup Script
========================================

Creating backup directory:
  /Users/you/Documents/LR_Backups/LR_Backup_20251103_224340

Starting backup process...

✓ Backing up: Develop Presets
  → 15 files copied
✓ Backing up: Export Presets
  → 5 files copied
✓ Backing up: Local Adjustment Presets (Masks)
  → 29 files copied

========================================
✓ Backup completed successfully!
========================================

Backup location:
  /Users/you/Documents/LR_Backups/LR_Backup_20251103_224340

Total backup size: 252K
Total files backed up: 62
```

## Recommended Usage

- Run before major Lightroom updates
- Run monthly as part of your backup routine
- Run before trying new presets or making major changes
- Run before reinstalling Lightroom or macOS

## Restoring from Backup

To restore presets from a backup:

1. Navigate to the backup folder
2. Copy the desired preset folders
3. Paste into `~/Library/Application Support/Adobe/Lightroom/`
4. Restart Lightroom Classic

## Managing Backups

Backups are timestamped and stored separately, so they won't overwrite each other. You can manually delete old backups to save space.

## Requirements

- macOS
- Lightroom Classic installed
- Bash shell (default on macOS)

## Troubleshooting

**"Lightroom directory not found"**
- Verify Lightroom Classic is installed
- Check that the installation is at the default location

**Some categories show "0 files copied"**
- This is normal if you haven't created presets in that category
- Only categories you use will have files

**Permission errors**
- Make sure the script is executable: `chmod +x backup_lr.sh`
- Ensure you have write permissions to the backup destination

## License

Free to use and modify as needed.
