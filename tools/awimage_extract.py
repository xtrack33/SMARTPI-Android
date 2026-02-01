#!/usr/bin/env python3
"""
Allwinner IMAGEWTY Extractor for SmartPi Android Project
Extracts partitions and configuration files from Allwinner firmware images.

Based on linux-sunxi documentation and awimage specifications.
"""

import struct
import os
import sys
from pathlib import Path

class AWImageExtractor:
    """Extract Allwinner IMAGEWTY format firmware images."""

    MAGIC_IMAGEWTY = b'IMAGEWTY'
    HEADER_SIZE = 0x400  # 1024 bytes

    def __init__(self, image_path, output_dir):
        self.image_path = Path(image_path)
        self.output_dir = Path(output_dir)
        self.items = []

    def read_header(self, data):
        """Parse IMAGEWTY header."""
        if data[:8] != self.MAGIC_IMAGEWTY:
            raise ValueError("Not a valid IMAGEWTY image")

        # Header structure (simplified)
        header = {
            'magic': data[:8],
            'header_version': struct.unpack('<I', data[8:12])[0],
            'header_size': struct.unpack('<I', data[12:16])[0],
            'image_size': struct.unpack('<I', data[16:20])[0],
            'item_count': struct.unpack('<I', data[0x38:0x3C])[0],
        }
        return header

    def find_partitions(self, data):
        """Find partition data in image by searching for known signatures."""
        partitions = []

        # Search for known partition signatures
        signatures = {
            b'ANDROID!': 'boot.img',
            b'ANDROID-BOOT': 'boot_alt.img',
            b'\x1f\x8b\x08': 'compressed.gz',
            b'hsqs': 'squashfs.img',
            b'\x53\xef': 'ext4_superblock',
            b'bootlogo': 'bootlogo.bmp',
        }

        # Search for FEX configuration
        fex_markers = [b'[product]', b'[platform]', b'[target]', b'[power_sply]']

        offset = 0
        while offset < len(data):
            # Look for boot.img
            if data[offset:offset+8] == b'ANDROID!':
                # Parse Android boot image header
                kernel_size = struct.unpack('<I', data[offset+8:offset+12])[0]
                ramdisk_size = struct.unpack('<I', data[offset+16:offset+20])[0]
                page_size = struct.unpack('<I', data[offset+36:offset+40])[0]
                if page_size == 0:
                    page_size = 2048

                # Calculate total size
                total_size = page_size  # header
                total_size += ((kernel_size + page_size - 1) // page_size) * page_size
                total_size += ((ramdisk_size + page_size - 1) // page_size) * page_size

                partitions.append({
                    'type': 'boot.img',
                    'offset': offset,
                    'size': min(total_size, 64*1024*1024),  # Max 64MB
                    'name': 'boot.img'
                })

            # Look for sparse images (system, vendor, etc.)
            if data[offset:offset+4] == b'\x3a\xff\x26\xed':
                # Sparse image magic
                partitions.append({
                    'type': 'sparse',
                    'offset': offset,
                    'size': 0,  # Will determine later
                    'name': f'sparse_{offset:08x}.img'
                })

            offset += 512  # Search every 512 bytes

        return partitions

    def extract_strings(self, data, min_length=20):
        """Extract readable strings for analysis."""
        strings = []
        current = b''

        for byte in data:
            if 32 <= byte < 127:
                current += bytes([byte])
            else:
                if len(current) >= min_length:
                    try:
                        strings.append(current.decode('ascii'))
                    except:
                        pass
                current = b''

        return strings

    def extract_fex_configs(self, data):
        """Extract .fex configuration files."""
        configs = []

        # Look for FEX file markers
        markers = [b'[product]', b'[platform]', b'[target]']

        for marker in markers:
            offset = 0
            while True:
                pos = data.find(marker, offset)
                if pos == -1:
                    break

                # Find the end of the config (next binary data or EOF)
                end = pos
                while end < len(data) and end - pos < 100000:
                    if data[end:end+4] in [b'\x00\x00\x00\x00', b'\xff\xff\xff\xff']:
                        consecutive_nulls = 0
                        for i in range(min(16, len(data) - end)):
                            if data[end+i] == 0 or data[end+i] == 0xff:
                                consecutive_nulls += 1
                        if consecutive_nulls > 8:
                            break
                    end += 1

                if end > pos + 100:  # Minimum valid config size
                    configs.append({
                        'offset': pos,
                        'size': end - pos,
                        'data': data[pos:end]
                    })

                offset = end

        return configs

    def extract(self):
        """Main extraction routine."""
        print(f"Extracting: {self.image_path}")
        print(f"Output dir: {self.output_dir}")

        self.output_dir.mkdir(parents=True, exist_ok=True)

        with open(self.image_path, 'rb') as f:
            data = f.read()

        print(f"Image size: {len(data):,} bytes ({len(data)/1024/1024:.1f} MB)")

        # Parse header
        try:
            header = self.read_header(data)
            print(f"Header version: {header['header_version']}")
            print(f"Item count: {header['item_count']}")
        except ValueError as e:
            print(f"Warning: {e}")

        # Extract build properties
        print("\n=== Extracting build.prop ===")
        build_prop_start = data.find(b'ro.build.id=')
        if build_prop_start != -1:
            # Find reasonable end
            build_prop_end = build_prop_start
            while build_prop_end < len(data) and build_prop_end - build_prop_start < 10000:
                if data[build_prop_end:build_prop_end+2] == b'\x00\x00':
                    break
                build_prop_end += 1

            build_prop = data[build_prop_start:build_prop_end]
            # Clean up
            build_prop = build_prop.replace(b'\x00', b'\n')

            build_prop_path = self.output_dir / 'build.prop'
            with open(build_prop_path, 'wb') as f:
                f.write(build_prop)
            print(f"Saved: {build_prop_path}")

        # Extract FEX configurations
        print("\n=== Extracting FEX configs ===")
        configs = self.extract_fex_configs(data)
        for i, config in enumerate(configs):
            config_path = self.output_dir / f'sys_config_{i}.fex'
            with open(config_path, 'wb') as f:
                f.write(config['data'])
            print(f"Saved: {config_path} ({config['size']} bytes)")

        # Find and list partitions
        print("\n=== Searching for partitions ===")
        partitions = self.find_partitions(data)
        for part in partitions:
            print(f"Found: {part['type']} at offset 0x{part['offset']:08x}")

            if part['type'] == 'boot.img' and part['size'] > 0:
                boot_path = self.output_dir / 'boot.img'
                with open(boot_path, 'wb') as f:
                    f.write(data[part['offset']:part['offset']+part['size']])
                print(f"Saved: {boot_path}")

        # Extract important strings for analysis
        print("\n=== Extracting version info ===")
        version_strings = []
        for s in self.extract_strings(data, 30):
            if any(x in s.lower() for x in ['version', 'android', 'kernel', 'mali', 'allwinner', 'build']):
                version_strings.append(s)

        info_path = self.output_dir / 'image_info.txt'
        with open(info_path, 'w') as f:
            f.write("=== Allwinner Image Analysis ===\n\n")
            f.write(f"Source: {self.image_path.name}\n")
            f.write(f"Size: {len(data):,} bytes\n\n")
            f.write("=== Version Strings ===\n")
            for s in sorted(set(version_strings))[:100]:
                f.write(f"{s}\n")
        print(f"Saved: {info_path}")

        # Create partition map
        print("\n=== Creating partition analysis ===")
        self.analyze_image_structure(data)

        return True

    def analyze_image_structure(self, data):
        """Analyze and document image structure."""
        analysis = []
        analysis.append("=== Allwinner Image Structure Analysis ===\n")

        # Known Allwinner partition table offsets
        # The image usually contains: boot0, boot1 (u-boot), boot.img, system, etc.

        # Search for u-boot
        null_byte = b'\x00'
        uboot_offset = data.find(b'U-Boot ')
        if uboot_offset != -1:
            uboot_version = data[uboot_offset:uboot_offset+50]
            version_str = uboot_version.split(null_byte)[0].decode('ascii', errors='ignore')
            analysis.append(f"U-Boot found at: 0x{uboot_offset:08x}")
            analysis.append(f"Version: {version_str}\n")

        # Search for kernel
        kernel_offset = data.find(b'Linux version')
        if kernel_offset != -1:
            kernel_version = data[kernel_offset:kernel_offset+100]
            version_str = kernel_version.split(null_byte)[0].decode('ascii', errors='ignore')
            analysis.append(f"Kernel found at: 0x{kernel_offset:08x}")
            analysis.append(f"Version: {version_str}\n")

        # Search for Android info
        android_offset = data.find(b'ro.build.version.release=')
        if android_offset != -1:
            version = data[android_offset:android_offset+50]
            version_str = version.split(null_byte)[0].decode('ascii', errors='ignore')
            analysis.append(f"Android version info at: 0x{android_offset:08x}")
            analysis.append(f"{version_str}\n")

        # Save analysis
        analysis_path = self.output_dir / 'structure_analysis.txt'
        with open(analysis_path, 'w') as f:
            f.write('\n'.join(analysis))
        print(f"Saved: {analysis_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: awimage_extract.py <image.img> [output_dir]")
        print("\nExtracts partitions and configs from Allwinner IMAGEWTY firmware.")
        sys.exit(1)

    image_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else './extracted'

    extractor = AWImageExtractor(image_path, output_dir)
    extractor.extract()
    print("\nExtraction complete!")


if __name__ == '__main__':
    main()
