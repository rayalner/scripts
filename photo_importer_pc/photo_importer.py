#!/usr/bin/env python3
"""
Photo Importer for Windows
A desktop application for importing and organizing photos from removable media.
"""

import sys
import os
import json
import shutil
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QComboBox, QProgressBar, QTextEdit,
    QFileDialog, QMessageBox, QDialog, QTableWidget, QTableWidgetItem,
    QHeaderView, QLineEdit, QGroupBox
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QFont


class Settings:
    """Manage application settings persistence."""

    SETTINGS_FILE = "photo_importer_settings.json"

    @classmethod
    def load(cls) -> dict:
        """Load settings from file."""
        settings_path = Path.home() / cls.SETTINGS_FILE
        if settings_path.exists():
            try:
                with open(settings_path, 'r') as f:
                    return json.load(f)
            except Exception:
                pass
        return {
            "last_source_drive": "",
            "destination_folders": [],
            "last_destination": ""
        }

    @classmethod
    def save(cls, settings: dict):
        """Save settings to file."""
        settings_path = Path.home() / cls.SETTINGS_FILE
        try:
            with open(settings_path, 'w') as f:
                json.dump(settings, f, indent=2)
        except Exception as e:
            print(f"Failed to save settings: {e}")


class FileScanner:
    """Scan removable media for photos and videos."""

    # File extensions by type
    VIDEO_EXTENSIONS = {'mp4', 'mov', 'avi', 'mkv', 'm4v', '3gp', 'mts', 'm2ts'}
    RAW_EXTENSIONS = {'awr', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raw', 'orf', 'rw2'}
    PHOTO_EXTENSIONS = {'jpg', 'jpeg', 'png', 'tiff', 'tif', 'heic', 'webp'}
    SKIP_EXTENSIONS = {'ind', 'thm', 'xml', 'bdm', 'bin', 'int', 'bnp', 'inp', 'scr', 'db', 'lrf'}

    @staticmethod
    def get_removable_drives() -> List[str]:
        """Get list of removable drives on Windows."""
        import string
        import ctypes

        drives = []
        bitmask = ctypes.windll.kernel32.GetLogicalDrives()

        for letter in string.ascii_uppercase:
            if bitmask & 1:
                drive_path = f"{letter}:\\"
                drive_type = ctypes.windll.kernel32.GetDriveTypeW(drive_path)
                # DRIVE_REMOVABLE = 2, DRIVE_FIXED = 3
                # We want removable drives
                if drive_type == 2:
                    drives.append(drive_path)
            bitmask >>= 1

        return drives

    @staticmethod
    def get_all_drives() -> List[str]:
        """Get list of all available drives on Windows."""
        import string
        import ctypes

        drives = []
        bitmask = ctypes.windll.kernel32.GetLogicalDrives()

        for letter in string.ascii_uppercase:
            if bitmask & 1:
                drive_path = f"{letter}:\\"
                if os.path.exists(drive_path):
                    drives.append(drive_path)
            bitmask >>= 1

        return drives

    @staticmethod
    def get_file_type(file_path: str) -> str:
        """Determine file type based on extension."""
        ext = Path(file_path).suffix.lower().lstrip('.')

        if ext in FileScanner.VIDEO_EXTENSIONS:
            return "video"
        elif ext in FileScanner.RAW_EXTENSIONS:
            return "raw"
        elif ext in FileScanner.PHOTO_EXTENSIONS:
            return "photo"
        else:
            return "other"

    @staticmethod
    def should_skip_file(file_path: str) -> bool:
        """Check if file should be skipped."""
        ext = Path(file_path).suffix.lower().lstrip('.')
        filename = Path(file_path).name

        # Skip hidden files and system files
        if filename.startswith('.'):
            return True

        # Skip known system/metadata files
        if ext in FileScanner.SKIP_EXTENSIONS:
            return True

        return False

    @staticmethod
    def get_file_date(file_path: str) -> str:
        """Get file modification date in MM-DD-YY format."""
        try:
            mtime = os.path.getmtime(file_path)
            dt = datetime.fromtimestamp(mtime)
            return dt.strftime("%m-%d-%y")
        except Exception:
            return ""

    @staticmethod
    def get_file_year(file_path: str) -> str:
        """Get file modification year."""
        try:
            mtime = os.path.getmtime(file_path)
            dt = datetime.fromtimestamp(mtime)
            return dt.strftime("%Y")
        except Exception:
            return ""

    @staticmethod
    def scan_for_dates(source_path: str) -> Dict[str, int]:
        """Scan source path and return dictionary of dates with file counts."""
        dates_count = {}

        for root, dirs, files in os.walk(source_path):
            # Skip hidden directories
            dirs[:] = [d for d in dirs if not d.startswith('.')]

            for filename in files:
                file_path = os.path.join(root, filename)

                if FileScanner.should_skip_file(file_path):
                    continue

                file_date = FileScanner.get_file_date(file_path)
                if file_date:
                    dates_count[file_date] = dates_count.get(file_date, 0) + 1

        return dates_count


class ShootNameDialog(QDialog):
    """Dialog for entering shoot names for each date."""

    def __init__(self, dates_count: Dict[str, int], parent=None):
        super().__init__(parent)
        self.dates_count = dates_count
        self.shoot_names = {}
        self.init_ui()

    def init_ui(self):
        """Initialize the dialog UI."""
        self.setWindowTitle("Enter Shoot Names")
        self.setModal(True)
        self.resize(600, 400)

        layout = QVBoxLayout()

        # Info label
        info_label = QLabel(f"Found photos from {len(self.dates_count)} different date(s).\nEnter a shoot name for each date:")
        layout.addWidget(info_label)

        # Table for dates and shoot names
        self.table = QTableWidget()
        self.table.setColumnCount(3)
        self.table.setHorizontalHeaderLabels(["Date", "File Count", "Shoot Name"])
        self.table.setRowCount(len(self.dates_count))

        # Populate table
        for i, (date, count) in enumerate(sorted(self.dates_count.items())):
            # Date column
            date_item = QTableWidgetItem(date)
            date_item.setFlags(date_item.flags() & ~Qt.ItemIsEditable)
            self.table.setItem(i, 0, date_item)

            # Count column
            count_item = QTableWidgetItem(str(count))
            count_item.setFlags(count_item.flags() & ~Qt.ItemIsEditable)
            self.table.setItem(i, 1, count_item)

            # Shoot name column (editable)
            shoot_name_item = QTableWidgetItem("")
            self.table.setItem(i, 2, shoot_name_item)

        # Resize columns
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(2, QHeaderView.Stretch)

        layout.addWidget(self.table)

        # Buttons
        button_layout = QHBoxLayout()

        ok_button = QPushButton("OK")
        ok_button.clicked.connect(self.accept_names)

        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.reject)

        button_layout.addStretch()
        button_layout.addWidget(ok_button)
        button_layout.addWidget(cancel_button)

        layout.addLayout(button_layout)

        self.setLayout(layout)

    def accept_names(self):
        """Validate and accept shoot names."""
        self.shoot_names = {}

        for i in range(self.table.rowCount()):
            date = self.table.item(i, 0).text()
            shoot_name = self.table.item(i, 2).text().strip()

            if not shoot_name:
                QMessageBox.warning(self, "Missing Shoot Name",
                                  f"Please enter a shoot name for {date}")
                return

            self.shoot_names[date] = shoot_name

        self.accept()


class ImportWorker(QThread):
    """Worker thread for importing files."""

    # Signals
    progress = pyqtSignal(int)  # Progress percentage
    status = pyqtSignal(str)  # Status message
    current_file = pyqtSignal(str)  # Current file being copied
    stats = pyqtSignal(dict)  # Statistics (speed, time, etc.)
    finished = pyqtSignal(bool, str)  # Success, message
    error = pyqtSignal(str)  # Error message

    def __init__(self, source_path: str, dest_path: str, shoot_names: Dict[str, str]):
        super().__init__()
        self.source_path = source_path
        self.dest_path = dest_path
        self.shoot_names = shoot_names
        self.should_stop = False

    def run(self):
        """Run the import process."""
        try:
            # Collect all files to copy
            self.status.emit("Scanning files...")
            files_to_copy = self.collect_files()

            if not files_to_copy:
                self.finished.emit(False, "No files found to copy")
                return

            total_files = len(files_to_copy)
            total_size = sum(os.path.getsize(f[0]) for f in files_to_copy)

            self.status.emit(f"Copying {total_files} files ({self.format_size(total_size)})...")

            # Copy files
            copied_files = []
            start_time = time.time()
            bytes_copied = 0

            for i, (source_file, dest_file) in enumerate(files_to_copy):
                if self.should_stop:
                    self.finished.emit(False, "Import cancelled by user")
                    return

                # Update current file
                self.current_file.emit(os.path.basename(source_file))

                # Create destination directory
                os.makedirs(os.path.dirname(dest_file), exist_ok=True)

                # Copy file
                try:
                    file_size = os.path.getsize(source_file)
                    shutil.copy2(source_file, dest_file)
                    bytes_copied += file_size
                    copied_files.append((source_file, dest_file))
                except Exception as e:
                    self.error.emit(f"Failed to copy {os.path.basename(source_file)}: {str(e)}")
                    self.finished.emit(False, f"Copy failed: {str(e)}")
                    return

                # Update progress
                progress_pct = int((i + 1) * 100 / total_files)
                self.progress.emit(progress_pct)

                # Calculate stats
                elapsed_time = time.time() - start_time
                if elapsed_time > 0:
                    speed = bytes_copied / elapsed_time
                    remaining_bytes = total_size - bytes_copied
                    remaining_time = remaining_bytes / speed if speed > 0 else 0

                    stats = {
                        'files_copied': i + 1,
                        'total_files': total_files,
                        'speed': self.format_size(speed) + "/s",
                        'elapsed': self.format_time(elapsed_time),
                        'remaining': self.format_time(remaining_time)
                    }
                    self.stats.emit(stats)

            # Verify files
            self.status.emit("Verifying copied files...")
            self.progress.emit(0)

            for i, (source_file, dest_file) in enumerate(copied_files):
                if self.should_stop:
                    self.finished.emit(False, "Verification cancelled by user")
                    return

                if not os.path.exists(dest_file):
                    self.error.emit(f"Missing file: {os.path.basename(dest_file)}")
                    self.finished.emit(False, f"Verification failed: Missing file")
                    return

                # Verify file size
                source_size = os.path.getsize(source_file)
                dest_size = os.path.getsize(dest_file)

                if source_size != dest_size:
                    self.error.emit(f"Size mismatch: {os.path.basename(dest_file)}")
                    self.finished.emit(False, f"Verification failed: Size mismatch")
                    return

                progress_pct = int((i + 1) * 100 / len(copied_files))
                self.progress.emit(progress_pct)

            self.finished.emit(True, f"Successfully imported {total_files} files!")

        except Exception as e:
            self.error.emit(f"Unexpected error: {str(e)}")
            self.finished.emit(False, f"Import failed: {str(e)}")

    def collect_files(self) -> List[Tuple[str, str]]:
        """Collect all files to copy with their destinations."""
        files_to_copy = []

        for root, dirs, files in os.walk(self.source_path):
            # Skip hidden directories
            dirs[:] = [d for d in dirs if not d.startswith('.')]

            for filename in files:
                source_file = os.path.join(root, filename)

                if FileScanner.should_skip_file(source_file):
                    continue

                # Get file date and shoot name
                file_date = FileScanner.get_file_date(source_file)
                file_year = FileScanner.get_file_year(source_file)

                if file_date not in self.shoot_names:
                    continue

                shoot_name = self.shoot_names[file_date]
                folder_name = f"{file_date} {shoot_name}"

                # Determine file type and destination
                file_type = FileScanner.get_file_type(source_file)

                if file_type == "other":
                    dest_dir = os.path.join(self.dest_path, file_year, folder_name)
                else:
                    dest_dir = os.path.join(self.dest_path, file_year, folder_name, file_type)

                # Handle duplicate filenames
                dest_file = os.path.join(dest_dir, filename)
                counter = 1
                base_name = Path(filename).stem
                ext = Path(filename).suffix

                while dest_file in [f[1] for f in files_to_copy] or os.path.exists(dest_file):
                    dest_file = os.path.join(dest_dir, f"{base_name}_{counter}{ext}")
                    counter += 1

                files_to_copy.append((source_file, dest_file))

        return files_to_copy

    @staticmethod
    def format_size(size_bytes: float) -> str:
        """Format bytes to human readable size."""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} TB"

    @staticmethod
    def format_time(seconds: float) -> str:
        """Format seconds to human readable time."""
        if seconds < 60:
            return f"{int(seconds)}s"
        elif seconds < 3600:
            minutes = int(seconds / 60)
            secs = int(seconds % 60)
            return f"{minutes}m {secs}s"
        else:
            hours = int(seconds / 3600)
            minutes = int((seconds % 3600) / 60)
            return f"{hours}h {minutes}m"

    def stop(self):
        """Stop the import process."""
        self.should_stop = True


class PhotoImporterApp(QMainWindow):
    """Main application window."""

    def __init__(self):
        super().__init__()
        self.settings = Settings.load()
        self.worker = None
        self.shoot_names = {}
        self.init_ui()

    def init_ui(self):
        """Initialize the user interface."""
        self.setWindowTitle("Photo Importer")
        self.setGeometry(100, 100, 800, 600)

        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)

        main_layout = QVBoxLayout()

        # Title
        title = QLabel("Photo Importer")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title.setFont(title_font)
        title.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(title)

        # Source selection
        source_group = QGroupBox("Source (Removable Media)")
        source_layout = QVBoxLayout()

        source_select_layout = QHBoxLayout()
        self.source_combo = QComboBox()
        self.source_combo.setMinimumWidth(400)
        source_select_layout.addWidget(QLabel("Drive:"))
        source_select_layout.addWidget(self.source_combo)

        self.refresh_btn = QPushButton("Refresh Drives")
        self.refresh_btn.clicked.connect(self.refresh_drives)
        source_select_layout.addWidget(self.refresh_btn)

        source_layout.addLayout(source_select_layout)
        source_group.setLayout(source_layout)
        main_layout.addWidget(source_group)

        # Destination selection
        dest_group = QGroupBox("Destination")
        dest_layout = QVBoxLayout()

        dest_select_layout = QHBoxLayout()
        self.dest_combo = QComboBox()
        self.dest_combo.setMinimumWidth(400)
        self.dest_combo.setEditable(False)
        dest_select_layout.addWidget(QLabel("Folder:"))
        dest_select_layout.addWidget(self.dest_combo)

        self.browse_btn = QPushButton("Browse...")
        self.browse_btn.clicked.connect(self.browse_destination)
        dest_select_layout.addWidget(self.browse_btn)

        dest_layout.addLayout(dest_select_layout)
        dest_group.setLayout(dest_layout)
        main_layout.addWidget(dest_group)

        # Scan button
        self.scan_btn = QPushButton("Scan Files")
        self.scan_btn.clicked.connect(self.scan_files)
        self.scan_btn.setMinimumHeight(40)
        main_layout.addWidget(self.scan_btn)

        # Progress section
        progress_group = QGroupBox("Progress")
        progress_layout = QVBoxLayout()

        self.progress_bar = QProgressBar()
        self.progress_bar.setMinimum(0)
        self.progress_bar.setMaximum(100)
        progress_layout.addWidget(self.progress_bar)

        self.status_label = QLabel("Ready")
        progress_layout.addWidget(self.status_label)

        self.current_file_label = QLabel("")
        progress_layout.addWidget(self.current_file_label)

        # Stats layout
        stats_layout = QHBoxLayout()
        self.speed_label = QLabel("Speed: -")
        self.elapsed_label = QLabel("Elapsed: -")
        self.remaining_label = QLabel("Remaining: -")
        stats_layout.addWidget(self.speed_label)
        stats_layout.addWidget(self.elapsed_label)
        stats_layout.addWidget(self.remaining_label)
        stats_layout.addStretch()
        progress_layout.addLayout(stats_layout)

        progress_group.setLayout(progress_layout)
        main_layout.addWidget(progress_group)

        # Log section
        log_group = QGroupBox("Log")
        log_layout = QVBoxLayout()

        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setMaximumHeight(150)
        log_layout.addWidget(self.log_text)

        log_group.setLayout(log_layout)
        main_layout.addWidget(log_group)

        # Action buttons
        button_layout = QHBoxLayout()

        self.start_btn = QPushButton("Start Import")
        self.start_btn.clicked.connect(self.start_import)
        self.start_btn.setEnabled(False)
        self.start_btn.setMinimumHeight(40)

        self.cancel_btn = QPushButton("Cancel")
        self.cancel_btn.clicked.connect(self.cancel_import)
        self.cancel_btn.setEnabled(False)

        self.eject_btn = QPushButton("Eject Drive")
        self.eject_btn.clicked.connect(self.eject_drive)
        self.eject_btn.setEnabled(False)

        button_layout.addWidget(self.start_btn)
        button_layout.addWidget(self.cancel_btn)
        button_layout.addWidget(self.eject_btn)

        main_layout.addLayout(button_layout)

        central_widget.setLayout(main_layout)

        # Initialize drives and destinations
        self.refresh_drives()
        self.load_destinations()

        self.log("Application started")

    def refresh_drives(self):
        """Refresh the list of available drives."""
        self.source_combo.clear()

        # Get all drives (both removable and fixed for selection)
        drives = FileScanner.get_all_drives()

        for drive in drives:
            self.source_combo.addItem(drive)

        # Try to select last used drive
        if self.settings.get("last_source_drive"):
            index = self.source_combo.findText(self.settings["last_source_drive"])
            if index >= 0:
                self.source_combo.setCurrentIndex(index)

        self.log(f"Found {len(drives)} drive(s)")

    def load_destinations(self):
        """Load saved destination folders."""
        self.dest_combo.clear()

        dest_folders = self.settings.get("destination_folders", [])

        for folder in dest_folders:
            if os.path.exists(folder):
                self.dest_combo.addItem(folder)

        # Try to select last used destination
        if self.settings.get("last_destination"):
            index = self.dest_combo.findText(self.settings["last_destination"])
            if index >= 0:
                self.dest_combo.setCurrentIndex(index)

    def browse_destination(self):
        """Browse for destination folder."""
        folder = QFileDialog.getExistingDirectory(self, "Select Destination Folder")

        if folder:
            # Add to combo if not already there
            if self.dest_combo.findText(folder) < 0:
                self.dest_combo.addItem(folder)

                # Save to settings
                dest_folders = self.settings.get("destination_folders", [])
                if folder not in dest_folders:
                    dest_folders.append(folder)
                    self.settings["destination_folders"] = dest_folders
                    Settings.save(self.settings)

            # Select the folder
            index = self.dest_combo.findText(folder)
            if index >= 0:
                self.dest_combo.setCurrentIndex(index)

            self.log(f"Selected destination: {folder}")

    def scan_files(self):
        """Scan source drive for files and dates."""
        source = self.source_combo.currentText()

        if not source:
            QMessageBox.warning(self, "No Source", "Please select a source drive")
            return

        if not os.path.exists(source):
            QMessageBox.warning(self, "Invalid Source", "Selected source drive does not exist")
            return

        self.log(f"Scanning {source}...")
        self.status_label.setText("Scanning for dates...")

        # Scan for dates
        try:
            dates_count = FileScanner.scan_for_dates(source)

            if not dates_count:
                QMessageBox.information(self, "No Files", "No media files found on the selected drive")
                self.status_label.setText("No files found")
                return

            self.log(f"Found files from {len(dates_count)} date(s)")

            # Show shoot name dialog
            dialog = ShootNameDialog(dates_count, self)
            if dialog.exec_() == QDialog.Accepted:
                self.shoot_names = dialog.shoot_names
                self.start_btn.setEnabled(True)
                self.log(f"Ready to import with {len(self.shoot_names)} shoot name(s)")
                self.status_label.setText("Ready to import")
            else:
                self.log("Scan cancelled")
                self.status_label.setText("Scan cancelled")

        except Exception as e:
            QMessageBox.critical(self, "Scan Error", f"Error scanning files: {str(e)}")
            self.log(f"Scan error: {str(e)}")
            self.status_label.setText("Scan failed")

    def start_import(self):
        """Start the import process."""
        source = self.source_combo.currentText()
        dest = self.dest_combo.currentText()

        if not source or not dest:
            QMessageBox.warning(self, "Missing Selection", "Please select both source and destination")
            return

        if not os.path.exists(source):
            QMessageBox.warning(self, "Invalid Source", "Source drive does not exist")
            return

        if not os.path.exists(dest):
            reply = QMessageBox.question(self, "Create Destination",
                                        f"Destination folder does not exist. Create it?",
                                        QMessageBox.Yes | QMessageBox.No)
            if reply == QMessageBox.Yes:
                try:
                    os.makedirs(dest, exist_ok=True)
                except Exception as e:
                    QMessageBox.critical(self, "Error", f"Failed to create destination: {str(e)}")
                    return
            else:
                return

        if not self.shoot_names:
            QMessageBox.warning(self, "No Shoot Names", "Please scan files first")
            return

        # Save settings
        self.settings["last_source_drive"] = source
        self.settings["last_destination"] = dest
        Settings.save(self.settings)

        # Disable controls
        self.start_btn.setEnabled(False)
        self.scan_btn.setEnabled(False)
        self.cancel_btn.setEnabled(True)

        # Reset progress
        self.progress_bar.setValue(0)
        self.current_file_label.setText("")
        self.speed_label.setText("Speed: -")
        self.elapsed_label.setText("Elapsed: -")
        self.remaining_label.setText("Remaining: -")

        # Start worker
        self.worker = ImportWorker(source, dest, self.shoot_names)
        self.worker.progress.connect(self.update_progress)
        self.worker.status.connect(self.update_status)
        self.worker.current_file.connect(self.update_current_file)
        self.worker.stats.connect(self.update_stats)
        self.worker.finished.connect(self.import_finished)
        self.worker.error.connect(self.import_error)

        self.log("Starting import...")
        self.worker.start()

    def cancel_import(self):
        """Cancel the ongoing import."""
        if self.worker and self.worker.isRunning():
            reply = QMessageBox.question(self, "Cancel Import",
                                        "Are you sure you want to cancel the import?",
                                        QMessageBox.Yes | QMessageBox.No)
            if reply == QMessageBox.Yes:
                self.log("Cancelling import...")
                self.worker.stop()

    def update_progress(self, value: int):
        """Update progress bar."""
        self.progress_bar.setValue(value)

    def update_status(self, status: str):
        """Update status label."""
        self.status_label.setText(status)

    def update_current_file(self, filename: str):
        """Update current file label."""
        self.current_file_label.setText(f"Copying: {filename}")

    def update_stats(self, stats: dict):
        """Update statistics labels."""
        self.speed_label.setText(f"Speed: {stats['speed']}")
        self.elapsed_label.setText(f"Elapsed: {stats['elapsed']}")
        self.remaining_label.setText(f"Remaining: {stats['remaining']}")

    def import_finished(self, success: bool, message: str):
        """Handle import completion."""
        self.log(message)

        # Re-enable controls
        self.start_btn.setEnabled(True)
        self.scan_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)

        if success:
            self.current_file_label.setText("Import complete!")
            self.eject_btn.setEnabled(True)
            QMessageBox.information(self, "Import Complete", message)
        else:
            self.current_file_label.setText("Import failed")
            QMessageBox.critical(self, "Import Failed", message)

    def import_error(self, error_msg: str):
        """Handle import error."""
        self.log(f"ERROR: {error_msg}")

    def eject_drive(self):
        """Eject the source drive."""
        source = self.source_combo.currentText()

        if not source:
            return

        reply = QMessageBox.question(self, "Eject Drive",
                                    f"Eject {source}?",
                                    QMessageBox.Yes | QMessageBox.No)

        if reply == QMessageBox.Yes:
            try:
                # On Windows, we use the removable media eject command
                import subprocess
                drive_letter = source.rstrip(':\\')

                # Try to eject using PowerShell
                ps_command = f"(New-Object -comObject Shell.Application).Namespace(17).ParseName('{drive_letter}:').InvokeVerb('Eject')"
                subprocess.run(['powershell', '-Command', ps_command], check=True, capture_output=True)

                self.log(f"Ejected {source}")
                self.eject_btn.setEnabled(False)
                QMessageBox.information(self, "Eject", f"Drive {source} has been ejected")

                # Refresh drives
                self.refresh_drives()

            except Exception as e:
                self.log(f"Failed to eject: {str(e)}")
                QMessageBox.warning(self, "Eject Failed",
                                  f"Could not eject drive automatically.\nPlease eject manually from File Explorer.\n\nError: {str(e)}")

    def log(self, message: str):
        """Add message to log."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.append(f"[{timestamp}] {message}")


def main():
    """Main entry point."""
    app = QApplication(sys.argv)
    window = PhotoImporterApp()
    window.show()
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()
