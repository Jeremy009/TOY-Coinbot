#!/usr/bin/env python3
"""
Convert SVG files to PNG format while keeping all icons

This script finds all SVG files that were mislabeled as PNG and converts
them to actual PNG format using built-in tools.
"""

import subprocess
import os
from pathlib import Path
import shutil

def check_if_svg(file_path):
    """Check if a file is actually SVG"""
    try:
        result = subprocess.run(['file', str(file_path)], capture_output=True, text=True)
        return 'SVG' in result.stdout
    except:
        return False

def convert_svg_to_png(svg_path, png_path, size=100):
    """Convert SVG to PNG using built-in macOS tools"""
    try:
        # Try using qlmanage (built into macOS) for SVG to PNG conversion
        temp_dir = Path("/tmp/svg_convert")
        temp_dir.mkdir(exist_ok=True)
        
        # Copy SVG with proper extension
        temp_svg = temp_dir / f"temp_{os.getpid()}.svg"
        shutil.copy2(svg_path, temp_svg)
        
        # Use qlmanage to generate thumbnail (PNG format)
        cmd = [
            'qlmanage', '-t', '-s', str(size), '-o', str(temp_dir), str(temp_svg)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        # qlmanage creates filename.svg.png
        generated_png = temp_dir / f"{temp_svg.name}.png"
        
        if generated_png.exists():
            shutil.move(generated_png, png_path)
            temp_svg.unlink()  # Clean up
            return True
        else:
            # Fallback: try using sips (also built into macOS)
            cmd = ['sips', '-s', 'format', 'png', '-Z', str(size), str(temp_svg), '--out', str(png_path)]
            result = subprocess.run(cmd, capture_output=True, text=True)
            temp_svg.unlink()  # Clean up
            return png_path.exists()
            
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        return False

def restore_and_convert_icons():
    """Restore deleted icons and convert SVG files to PNG"""
    
    # First, let's restore all the icons by re-downloading only the ones we deleted
    print("🔄 Re-downloading missing icons...")
    
    # Get list of current icons
    icons_dir = Path("Coinbot/Assets.xcassets/CryptoIcons")
    current_icons = set()
    if icons_dir.exists():
        for imageset_dir in icons_dir.iterdir():
            if imageset_dir.is_dir() and imageset_dir.name.endswith('.imageset'):
                symbol = imageset_dir.name.replace('-icon.imageset', '').upper()
                current_icons.add(symbol)
    
    print(f"📊 Current icons: {len(current_icons)}")
    
    # Load our original mapping to see what we should have
    try:
        import json
        with open('symbol-icon-mapping.json', 'r') as f:
            data = json.load(f)
        original_mapping = data.get('mapping', {})
        print(f"📊 Original mapping: {len(original_mapping)} icons")
        
        missing_symbols = set(original_mapping.keys()) - current_icons
        print(f"📊 Missing icons: {len(missing_symbols)}")
        
        if missing_symbols:
            print("🔄 Re-downloading missing icons...")
            # Re-download missing icons
            import requests
            session = requests.Session()
            
            for symbol in sorted(missing_symbols):
                url = original_mapping[symbol]
                try:
                    print(f"⬇️  {symbol}", end=" ")
                    response = session.get(url, timeout=10)
                    response.raise_for_status()
                    
                    # Create imageset directory
                    imageset_dir = icons_dir / f"{symbol.lower()}-icon.imageset"
                    imageset_dir.mkdir(exist_ok=True)
                    
                    # Save the file (might be SVG or PNG)
                    temp_file = imageset_dir / f"{symbol.lower()}-icon.temp"
                    with open(temp_file, 'wb') as f:
                        f.write(response.content)
                    
                    # Check if it's SVG and convert if needed
                    png_file = imageset_dir / f"{symbol.lower()}-icon.png"
                    
                    if check_if_svg(temp_file):
                        print("(SVG->PNG)", end=" ")
                        if convert_svg_to_png(temp_file, png_file):
                            print("✅")
                        else:
                            print("❌ conversion failed")
                            continue
                    else:
                        # It's already a proper image, just rename
                        print("(PNG)", end=" ")
                        shutil.move(temp_file, png_file)
                        print("✅")
                    
                    # Remove temp file if it still exists
                    if temp_file.exists():
                        temp_file.unlink()
                    
                    # Create Contents.json
                    contents_json = {
                        "images": [
                            {
                                "filename": f"{symbol.lower()}-icon.png",
                                "idiom": "universal",
                                "scale": "1x"
                            }
                        ],
                        "info": {
                            "author": "xcode",
                            "version": 1
                        }
                    }
                    
                    with open(imageset_dir / "Contents.json", 'w') as f:
                        json.dump(contents_json, f, indent=2)
                        
                except Exception as e:
                    print(f"❌ {e}")
                    continue
        
    except Exception as e:
        print(f"❌ Could not load mapping: {e}")
        return
    
    # Now convert any remaining SVG files that are in current imagesets
    print("\n🔄 Converting existing SVG files to PNG...")
    converted_count = 0
    
    for imageset_dir in icons_dir.iterdir():
        if not imageset_dir.is_dir() or not imageset_dir.name.endswith('.imageset'):
            continue
            
        symbol = imageset_dir.name.replace('-icon.imageset', '').upper()
        png_file = imageset_dir / f"{symbol.lower()}-icon.png"
        
        if png_file.exists() and check_if_svg(png_file):
            print(f"🔄 Converting {symbol} SVG to PNG...", end=" ")
            temp_png = imageset_dir / f"{symbol.lower()}-icon-converted.png"
            
            if convert_svg_to_png(png_file, temp_png):
                # Replace the SVG with converted PNG
                png_file.unlink()
                shutil.move(temp_png, png_file)
                print("✅")
                converted_count += 1
            else:
                print("❌")
                if temp_png.exists():
                    temp_png.unlink()
    
    # Final count
    final_count = len(list(icons_dir.glob("*.imageset")))
    print(f"\n📊 Final Results:")
    print(f"✅ Total icons: {final_count}")
    print(f"🔄 Converted SVG files: {converted_count}")
    print(f"📁 Icons directory: {icons_dir}")

def main():
    print("🎨 Converting SVG icons to PNG format...")
    print("=" * 50)
    
    restore_and_convert_icons()
    
    print("=" * 50)
    print("✅ Conversion complete! All icons should now be proper PNG files.")
    print("Try building in Xcode again.")

if __name__ == "__main__":
    main()