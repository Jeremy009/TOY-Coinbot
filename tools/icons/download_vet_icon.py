#!/usr/bin/env python3
"""
Try to download a VET icon from alternative sources
"""

import requests
import json
import os
from pathlib import Path

# Try different VET icon sources
vet_sources = [
    "https://cryptologos.cc/logos/vechain-vet-logo.png",
    "https://assets.coingecko.com/coins/images/1167/large/VeChain-Logo-Icon.png",
    "https://s2.coinmarketcap.com/static/img/coins/64x64/3077.png",
]

def create_vet_imageset(image_data):
    """Create VET imageset for iOS"""
    icons_dir = Path("Coinbot/Assets.xcassets/CryptoIcons")
    imageset_dir = icons_dir / "vet-icon.imageset"
    imageset_dir.mkdir(exist_ok=True)
    
    # Save PNG file
    png_path = imageset_dir / "vet-icon.png"
    with open(png_path, 'wb') as f:
        f.write(image_data)
    
    # Create Contents.json
    contents_json = {
        "images": [
            {
                "filename": "vet-icon.png",
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
    
    print(f"✅ Created VET icon imageset ({len(image_data)} bytes)")

def main():
    print("🔍 Trying to download VET icon from alternative sources...")
    
    for i, url in enumerate(vet_sources, 1):
        try:
            print(f"Trying source {i}: {url}")
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            
            if len(response.content) > 1000:  # Reasonable size check
                create_vet_imageset(response.content)
                return True
                
        except Exception as e:
            print(f"❌ Source {i} failed: {e}")
            continue
    
    print("❌ All VET icon sources failed - will use fallback 'V' circle")
    return False

if __name__ == "__main__":
    main()