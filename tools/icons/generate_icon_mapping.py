#!/usr/bin/env python3
"""
Coinbot Icon Mapping Generator

This script:
1. Fetches all cryptocurrency symbols from Bitvavo API
2. Checks Elbstream API for available icons for each symbol
3. Tries variations for symbols without direct matches
4. Generates a symbol-icon-mapping.json file for Swift to use

Usage: python3 generate_icon_mapping.py
"""

import requests
import json
import time
import os
from typing import Dict, List, Optional

# Configuration
BITVAVO_API_BASE = "https://api.bitvavo.com/v2"
ELBSTREAM_API_BASE = "https://api.elbstream.com/logos/crypto"
OUTPUT_FILE = "Coinbot/symbol-icon-mapping.json"
RATE_LIMIT_DELAY = 0.1  # 100ms delay between requests

class IconMappingGenerator:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Coinbot-IconMapper/1.0'
        })
        self.mapping = {}
        self.not_found = []
        
    def log(self, message: str):
        """Print timestamped log message"""
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] {message}")
        
    def fetch_bitvavo_symbols(self) -> List[str]:
        """Fetch all available symbols from Bitvavo API"""
        self.log("📡 Fetching symbols from Bitvavo API...")
        
        try:
            # Get all assets
            response = self.session.get(f"{BITVAVO_API_BASE}/assets")
            response.raise_for_status()
            assets = response.json()
            
            symbols = [asset['symbol'] for asset in assets]
            self.log(f"✅ Found {len(symbols)} symbols from Bitvavo")
            return symbols
            
        except requests.RequestException as e:
            self.log(f"❌ Error fetching Bitvavo symbols: {e}")
            return []
    
    def check_elbstream_icon(self, symbol: str) -> bool:
        """Check if icon exists for given symbol on Elbstream API"""
        url = f"{ELBSTREAM_API_BASE}/{symbol}"
        
        try:
            response = self.session.head(url, timeout=5)  # HEAD request is faster
            if response.status_code == 200:
                return True
            elif response.status_code == 404:
                return False
            else:
                self.log(f"⚠️ Unexpected status {response.status_code} for {symbol}")
                return False
                
        except requests.RequestException as e:
            self.log(f"❌ Error checking {symbol}: {e}")
            return False
    
    def generate_symbol_variations(self, symbol: str) -> List[str]:
        """Generate possible variations for a symbol"""
        variations = []
        
        # Common variations to try
        if symbol.endswith('2'):
            # LUNA2 -> LUNA
            variations.append(symbol[:-1])
        
        if symbol.startswith('W'):
            # WBTC -> BTC, WETH -> ETH
            variations.append(symbol[1:])
            
        if 'USD' in symbol:
            # BUSD -> BNB, TUSD -> TUSD (try without USD)
            variations.append(symbol.replace('USD', ''))
            
        # Try lowercase
        variations.append(symbol.lower())
        
        # Try common abbreviations
        abbreviation_map = {
            'BITCOIN': 'BTC',
            'ETHEREUM': 'ETH',
            'LITECOIN': 'LTC',
            'RIPPLE': 'XRP',
            'CARDANO': 'ADA',
            'POLKADOT': 'DOT',
            'CHAINLINK': 'LINK',
            'BINANCECOIN': 'BNB',
            'SOLANA': 'SOL',
            'VECHAIN': 'VET'
        }
        
        for full_name, abbrev in abbreviation_map.items():
            if symbol.upper() == full_name:
                variations.append(abbrev)
        
        return list(set(variations))  # Remove duplicates
    
    def find_icon_for_symbol(self, symbol: str) -> Optional[str]:
        """Find icon URL for symbol, trying variations if needed"""
        
        # Try direct symbol first
        if self.check_elbstream_icon(symbol):
            url = f"{ELBSTREAM_API_BASE}/{symbol}"
            self.log(f"✅ Found icon for {symbol}")
            return url
        
        # Try variations
        variations = self.generate_symbol_variations(symbol)
        for variation in variations:
            time.sleep(RATE_LIMIT_DELAY)  # Rate limiting
            
            if self.check_elbstream_icon(variation):
                url = f"{ELBSTREAM_API_BASE}/{variation}"
                self.log(f"✅ Found icon for {symbol} using variation {variation}")
                return url
        
        # No icon found
        self.log(f"❌ No icon found for {symbol} (tried {len(variations)} variations)")
        return None
    
    def generate_mapping(self):
        """Generate the complete symbol-to-icon mapping"""
        
        # Get all symbols from Bitvavo
        symbols = self.fetch_bitvavo_symbols()
        if not symbols:
            self.log("❌ Failed to fetch symbols, exiting")
            return
        
        # Process each symbol
        self.log(f"🔍 Checking icons for {len(symbols)} symbols...")
        processed = 0
        
        for symbol in symbols:
            processed += 1
            
            if processed % 50 == 0:
                self.log(f"📊 Progress: {processed}/{len(symbols)} symbols processed")
            
            # Skip EUR as it's handled specially
            if symbol == 'EUR':
                continue
                
            icon_url = self.find_icon_for_symbol(symbol)
            
            if icon_url:
                self.mapping[symbol] = icon_url
            else:
                self.not_found.append(symbol)
            
            # Rate limiting
            time.sleep(RATE_LIMIT_DELAY)
        
        # Summary
        self.log(f"📊 Final results:")
        self.log(f"   ✅ Icons found: {len(self.mapping)}")
        self.log(f"   ❌ Icons not found: {len(self.not_found)}")
        
        # Print symbols without icons
        if self.not_found:
            self.log(f"🚫 Symbols without icons:")
            for symbol in sorted(self.not_found):
                self.log(f"   - {symbol}")
    
    def save_mapping(self):
        """Save the mapping to JSON file"""
        
        output_data = {
            "metadata": {
                "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                "total_symbols_checked": len(self.mapping) + len(self.not_found),
                "icons_found": len(self.mapping),
                "icons_not_found": len(self.not_found),
                "api_base": ELBSTREAM_API_BASE
            },
            "mapping": self.mapping,
            "not_found": self.not_found
        }
        
        try:
            with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
                json.dump(output_data, f, indent=2, sort_keys=True)
            
            self.log(f"💾 Saved mapping to {OUTPUT_FILE}")
            self.log(f"📁 File size: {os.path.getsize(OUTPUT_FILE)} bytes")
            
        except IOError as e:
            self.log(f"❌ Error saving mapping: {e}")

def main():
    """Main execution function"""
    generator = IconMappingGenerator()
    
    print("=" * 60)
    print("🚀 Coinbot Icon Mapping Generator")
    print("=" * 60)
    
    try:
        generator.generate_mapping()
        generator.save_mapping()
        
        print("=" * 60)
        print("✅ Icon mapping generation completed successfully!")
        print(f"📁 Output file: {OUTPUT_FILE}")
        print("=" * 60)
        
    except KeyboardInterrupt:
        generator.log("⚠️ Process interrupted by user")
    except Exception as e:
        generator.log(f"❌ Unexpected error: {e}")
        raise

if __name__ == "__main__":
    main()