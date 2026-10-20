#!/usr/bin/env python3
"""
Download cryptocurrency icons for bundling in iOS app

This script downloads high-quality PNG icons from reliable sources
and saves them with consistent naming for iOS bundle inclusion.
"""

import requests
import os
from pathlib import Path

# Create icons directory
icons_dir = Path("Coinbot/Assets.xcassets/CryptoIcons")
icons_dir.mkdir(parents=True, exist_ok=True)

# Icon sources - reliable CoinGecko URLs that we know work
icon_sources = {
    "BTC": "https://coin-images.coingecko.com/coins/images/1/large/bitcoin.png",
    "ETH": "https://coin-images.coingecko.com/coins/images/279/large/ethereum.png", 
    "SOL": "https://coin-images.coingecko.com/coins/images/4128/large/solana.png",
    "LUNA": "https://coin-images.coingecko.com/coins/images/8284/large/luna1557227471663.png",
    "ADA": "https://coin-images.coingecko.com/coins/images/975/large/cardano.png",
    "DOT": "https://coin-images.coingecko.com/coins/images/12171/large/polkadot.png",
    "LINK": "https://coin-images.coingecko.com/coins/images/877/large/chainlink-new-logo.png",
    "XRP": "https://coin-images.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png",
    "LTC": "https://coin-images.coingecko.com/coins/images/2/large/litecoin.png",
    "BNB": "https://coin-images.coingecko.com/coins/images/825/large/bnb-icon2_2x.png",
    "USDT": "https://coin-images.coingecko.com/coins/images/325/large/Tether.png",
    "USDC": "https://coin-images.coingecko.com/coins/images/6319/large/usdc.png",
    "AVAX": "https://coin-images.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png",
}

def download_icon(symbol, url):
    """Download and save icon with proper naming for iOS"""
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        # Create imageset directory
        imageset_dir = icons_dir / f"{symbol.lower()}-icon.imageset"
        imageset_dir.mkdir(exist_ok=True)
        
        # Save PNG file
        png_path = imageset_dir / f"{symbol.lower()}-icon.png"
        with open(png_path, 'wb') as f:
            f.write(response.content)
        
        # Create Contents.json for the imageset
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
        
        import json
        with open(imageset_dir / "Contents.json", 'w') as f:
            json.dump(contents_json, f, indent=2)
        
        print(f"✅ Downloaded {symbol} icon ({len(response.content)} bytes)")
        return True
        
    except Exception as e:
        print(f"❌ Failed to download {symbol}: {e}")
        return False

def main():
    print("📱 Downloading cryptocurrency icons for iOS bundle...")
    print("=" * 50)
    
    successful = 0
    total = len(icon_sources)
    
    for symbol, url in icon_sources.items():
        if download_icon(symbol, url):
            successful += 1
    
    print("=" * 50)
    print(f"✅ Downloaded {successful}/{total} icons successfully")
    print(f"📁 Icons saved to: {icons_dir}")
    print()
    print("Next steps:")
    print("1. Add the CryptoIcons folder to your Xcode project")
    print("2. Update CryptoLogoView to use Image() instead of AsyncImage")
    print("3. Use Image('btc-icon') for bundled icons")

if __name__ == "__main__":
    main()