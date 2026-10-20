#!/usr/bin/env python3
"""
Download as many cryptocurrency icons as possible for iOS bundle

Uses the symbol-icon-mapping.json we generated earlier to download
all available icons from Elbstream API that actually work.
"""

import requests
import json
import os
import time
from pathlib import Path

# Load our previously generated mapping
def load_mapping():
    try:
        with open('symbol-icon-mapping.json', 'r') as f:
            data = json.load(f)
        return data.get('mapping', {})
    except Exception as e:
        print(f"❌ Could not load symbol-icon-mapping.json: {e}")
        return {}

def create_imageset(symbol, image_data):
    """Create iOS imageset for a symbol"""
    icons_dir = Path("Coinbot/Assets.xcassets/CryptoIcons")
    icons_dir.mkdir(parents=True, exist_ok=True)
    
    imageset_dir = icons_dir / f"{symbol.lower()}-icon.imageset"
    imageset_dir.mkdir(exist_ok=True)
    
    # Save image file
    filename = f"{symbol.lower()}-icon.png"
    image_path = imageset_dir / filename
    with open(image_path, 'wb') as f:
        f.write(image_data)
    
    # Create Contents.json
    contents_json = {
        "images": [
            {
                "filename": filename,
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
    
    return True

def download_icon(symbol, url, session):
    """Download icon from URL and create imageset"""
    try:
        response = session.get(url, timeout=10)
        response.raise_for_status()
        
        # Check if it's a reasonable size (avoid error pages)
        if len(response.content) < 500:
            return False, "Too small"
        
        # Check if it's actually an image (basic check)
        content_type = response.headers.get('content-type', '').lower()
        if not any(img_type in content_type for img_type in ['image/', 'application/octet-stream']):
            # Some APIs don't set content-type correctly, so check file signature
            if not (response.content.startswith(b'\x89PNG') or  # PNG
                   response.content.startswith(b'<svg') or      # SVG
                   response.content.startswith(b'\xff\xd8')):   # JPEG
                return False, f"Not an image: {content_type}"
        
        create_imageset(symbol, response.content)
        return True, f"Success ({len(response.content)} bytes)"
        
    except requests.RequestException as e:
        return False, str(e)
    except Exception as e:
        return False, f"Unexpected error: {e}"

def main():
    print("🚀 Downloading ALL available cryptocurrency icons...")
    print("=" * 60)
    
    # Load our mapping
    mapping = load_mapping()
    if not mapping:
        print("❌ No mapping data available. Run generate_icon_mapping.py first.")
        return
    
    print(f"📊 Found {len(mapping)} icons to attempt downloading")
    print("=" * 60)
    
    # Create session for connection reuse
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Coinbot-IconDownloader/1.0'
    })
    
    successful = 0
    failed = 0
    failed_symbols = []
    
    # Process all symbols in mapping
    symbols = list(mapping.keys())
    for i, symbol in enumerate(symbols, 1):
        url = mapping[symbol]
        
        print(f"[{i:3d}/{len(symbols)}] {symbol:8s} ", end="", flush=True)
        
        success, message = download_icon(symbol, url, session)
        
        if success:
            print(f"✅ {message}")
            successful += 1
        else:
            print(f"❌ {message}")
            failed += 1
            failed_symbols.append(symbol)
        
        # Rate limiting - be nice to the API
        time.sleep(0.1)
        
        # Progress update every 50 symbols
        if i % 50 == 0:
            print(f"📊 Progress: {successful} successful, {failed} failed")
    
    print("=" * 60)
    print(f"🎉 Download complete!")
    print(f"✅ Successfully downloaded: {successful} icons")
    print(f"❌ Failed downloads: {failed} icons")
    print(f"📈 Success rate: {successful/(successful+failed)*100:.1f}%")
    
    if failed_symbols:
        print(f"\n🚫 Failed symbols ({len(failed_symbols)}):")
        for i in range(0, len(failed_symbols), 10):
            chunk = failed_symbols[i:i+10]
            print(f"   {', '.join(chunk)}")
    
    print(f"\n📁 Icons saved to: Coinbot/Assets.xcassets/CryptoIcons/")
    print(f"🔧 Next: Update bundledIcons set in Swift to include all successful symbols")

if __name__ == "__main__":
    main()