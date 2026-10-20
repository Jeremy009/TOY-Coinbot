#!/usr/bin/env python3
"""
Fix Assets.xcassets by removing invalid SVG files that are mislabeled as PNG
"""

import os
import subprocess
import shutil
from pathlib import Path

def check_file_type(file_path):
    """Check if file is actually a PNG image"""
    try:
        result = subprocess.run(['file', str(file_path)], capture_output=True, text=True)
        return 'PNG image data' in result.stdout
    except:
        return False

def fix_crypto_icons():
    """Remove imagesets with invalid PNG files"""
    icons_dir = Path("Coinbot/Assets.xcassets/CryptoIcons")
    
    if not icons_dir.exists():
        print("❌ CryptoIcons directory not found")
        return
    
    removed_count = 0
    kept_count = 0
    
    for imageset_dir in icons_dir.iterdir():
        if not imageset_dir.is_dir() or not imageset_dir.name.endswith('.imageset'):
            continue
            
        symbol = imageset_dir.name.replace('-icon.imageset', '').upper()
        png_file = imageset_dir / f"{symbol.lower()}-icon.png"
        
        if png_file.exists() and check_file_type(png_file):
            print(f"✅ {symbol:8s} - Valid PNG, keeping")
            kept_count += 1
        else:
            print(f"❌ {symbol:8s} - Invalid PNG, removing")
            shutil.rmtree(imageset_dir)
            removed_count += 1
    
    print(f"\n📊 Results:")
    print(f"✅ Kept: {kept_count} valid PNG icons")
    print(f"❌ Removed: {removed_count} invalid SVG/corrupted files")
    
    return kept_count

def update_swift_code(valid_symbols):
    """Generate updated bundledIcons set for Swift"""
    if valid_symbols:
        symbols_str = '", "'.join(sorted(valid_symbols))
        print(f"\n🔧 Update Swift code with these {len(valid_symbols)} symbols:")
        print(f'private var bundledIcons: Set<String> = [')
        print(f'    "{symbols_str}"')
        print(f']')

def main():
    print("🔧 Fixing Assets.xcassets - removing invalid image files...")
    print("=" * 60)
    
    kept_count = fix_crypto_icons()
    
    print("=" * 60)
    print("✅ Asset cleanup complete!")
    print("Now try building in Xcode again.")

if __name__ == "__main__":
    main()