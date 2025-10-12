#!/usr/bin/env python3
"""
FontAwesome SVG Color Changer
Changes colors in FontAwesome SVG files for primary and secondary colors.
"""

import os
import re
import argparse
import glob
from pathlib import Path

def change_svg_color(svg_content, primary_color=None, secondary_color=None):
    """
    Change colors in SVG content.
    
    Args:
        svg_content (str): The SVG file content
        primary_color (str): New primary color (hex format like #ff0000)
        secondary_color (str): New secondary color (hex format like #00ff00)
    
    Returns:
        str: Modified SVG content
    """
    # Common FontAwesome color patterns
    fa_primary_colors = ['#572AFF', '#000000', '#000', 'blue']
    fa_secondary_colors = ['#E90096', '#999999', '#999', 'gray', 'pink']
    
    modified_content = svg_content
    
    # Change primary colors
    if primary_color:
        for old_color in fa_primary_colors:
            # Replace fill attributes
            modified_content = re.sub(
                rf'fill="{re.escape(old_color)}"',
                f'fill="{primary_color}"',
                modified_content,
                flags=re.IGNORECASE
            )
            # Replace stroke attributes
            modified_content = re.sub(
                rf'stroke="{re.escape(old_color)}"',
                f'stroke="{primary_color}"',
                modified_content,
                flags=re.IGNORECASE
            )
            # Replace style attributes
            modified_content = re.sub(
                rf'fill:{re.escape(old_color)}',
                f'fill:{primary_color}',
                modified_content,
                flags=re.IGNORECASE
            )
    
    # Change secondary colors
    if secondary_color:
        for old_color in fa_secondary_colors:
            # Replace fill attributes
            modified_content = re.sub(
                rf'fill="{re.escape(old_color)}"',
                f'fill="{secondary_color}"',
                modified_content,
                flags=re.IGNORECASE
            )
            # Replace stroke attributes
            modified_content = re.sub(
                rf'stroke="{re.escape(old_color)}"',
                f'stroke="{secondary_color}"',
                modified_content,
                flags=re.IGNORECASE
            )
            # Replace style attributes
            modified_content = re.sub(
                rf'fill:{re.escape(old_color)}',
                f'fill:{secondary_color}',
                modified_content,
                flags=re.IGNORECASE
            )
    
    return modified_content

def process_svg_file(file_path, primary_color=None, secondary_color=None, output_dir=None):
    """
    Process a single SVG file.
    
    Args:
        file_path (str): Path to the SVG file
        primary_color (str): New primary color
        secondary_color (str): New secondary color
        output_dir (str): Output directory (if None, overwrites original)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        modified_content = change_svg_color(content, primary_color, secondary_color)
        
        if output_dir:
            output_path = Path(output_dir) / Path(file_path).name
            output_path.parent.mkdir(parents=True, exist_ok=True)
        else:
            output_path = file_path
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(modified_content)
        
        print(f"Processed: {file_path} -> {output_path}")
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description='Change colors in FontAwesome SVG files')
    parser.add_argument('files', nargs='*', help='SVG files to process (supports wildcards)')
    parser.add_argument('-p', '--primary', help='Primary color (e.g., #ff0000)')
    parser.add_argument('-s', '--secondary', help='Secondary color (e.g., #00ff00)')
    parser.add_argument('-d', '--directory', help='Process all SVG files in directory')
    parser.add_argument('-o', '--output', help='Output directory (default: overwrite originals)')
    parser.add_argument('--preview', action='store_true', help='Preview changes without saving')
    
    args = parser.parse_args()
    
    # Validate colors
    if args.primary and not re.match(r'^#[0-9a-fA-F]{6}$', args.primary):
        print("Error: Primary color must be in hex format (e.g., #ff0000)")
        return
    
    if args.secondary and not re.match(r'^#[0-9a-fA-F]{6}$', args.secondary):
        print("Error: Secondary color must be in hex format (e.g., #00ff00)")
        return
    
    if not args.primary and not args.secondary:
        print("Error: You must specify at least one color (--primary or --secondary)")
        return
    
    # Collect files to process
    files_to_process = []
    
    if args.directory:
        files_to_process.extend(glob.glob(os.path.join(args.directory, '*.svg')))
    
    if args.files:
        for file_pattern in args.files:
            files_to_process.extend(glob.glob(file_pattern))
    
    if not files_to_process:
        print("No SVG files found to process")
        return
    
    print(f"Found {len(files_to_process)} SVG files to process")
    if args.primary:
        print(f"Primary color: {args.primary}")
    if args.secondary:
        print(f"Secondary color: {args.secondary}")
    print()
    
    # Process files
    for file_path in files_to_process:
        if args.preview:
            print(f"Would process: {file_path}")
        else:
            process_svg_file(file_path, args.primary, args.secondary, args.output)

if __name__ == '__main__':
    main()