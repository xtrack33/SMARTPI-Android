#!/usr/bin/env python3
"""
Allwinner IMAGEWTY Full Extractor
Extracts all partitions and blobs from Allwinner firmware images.
"""

import struct
import os
import sys
import zlib
import lzma
from pathlib import Path

class AllwinnerImageExtractor:
    """Full extraction of Allwinner IMAGEWTY firmware."""

    MAGIC_IMAGEWTY = b'IMAGEWTY'
    MAGIC_SPARSE = b'\x3a\xff\x26\xed'
    MAGIC_ANDROID_BOOT = b'ANDROID!'
    MAGIC_EXT4 = b'\x53\xef'
    MAGIC_GZIP = b'\x1f\x8b'
    MAGIC_LZMA = b'\x5d\x00\x00'

    def __init__(self, image_path, output_dir):
        self.image_path = Path(image_path)
        self.output_dir = Path(output_dir)
        self.data = None

    def read_image(self):
        """Read entire image into memory."""
        print(f"Reading image: {self.image_path}")
        with open(self.image_path, 'rb') as f:
            self.data = f.read()
        print(f"Image size: {len(self.data):,} bytes ({len(self.data)/1024/1024:.1f} MB)")

    def find_all_partitions(self):
        """Find all partition offsets in the image."""
        partitions = []
        offset = 0

        while offset < len(self.data) - 16:
            # Android boot image
            if self.data[offset:offset+8] == self.MAGIC_ANDROID_BOOT:
                size = self._get_boot_img_size(offset)
                partitions.append({
                    'type': 'boot.img',
                    'offset': offset,
                    'size': size
                })
                print(f"  Found boot.img at 0x{offset:08x} ({size:,} bytes)")

            # Sparse image (system, vendor, etc.)
            elif self.data[offset:offset+4] == self.MAGIC_SPARSE:
                size = self._get_sparse_size(offset)
                partitions.append({
                    'type': 'sparse',
                    'offset': offset,
                    'size': size
                })
                print(f"  Found sparse image at 0x{offset:08x} ({size:,} bytes)")

            # GZIP compressed
            elif self.data[offset:offset+2] == self.MAGIC_GZIP:
                partitions.append({
                    'type': 'gzip',
                    'offset': offset,
                    'size': 0  # Unknown until decompressed
                })

            offset += 512  # Scan every 512 bytes

        return partitions

    def _get_boot_img_size(self, offset):
        """Calculate Android boot image size."""
        try:
            kernel_size = struct.unpack('<I', self.data[offset+8:offset+12])[0]
            ramdisk_size = struct.unpack('<I', self.data[offset+16:offset+20])[0]
            second_size = struct.unpack('<I', self.data[offset+24:offset+28])[0]
            page_size = struct.unpack('<I', self.data[offset+36:offset+40])[0]

            if page_size == 0:
                page_size = 2048

            def align(size, page):
                return ((size + page - 1) // page) * page

            total = page_size  # header
            total += align(kernel_size, page_size)
            total += align(ramdisk_size, page_size)
            total += align(second_size, page_size)

            return min(total, 64 * 1024 * 1024)  # Max 64MB
        except:
            return 16 * 1024 * 1024  # Default 16MB

    def _get_sparse_size(self, offset):
        """Get sparse image size from header."""
        try:
            # Sparse header: magic(4) + version(4) + header_size(2) + chunk_header_size(2) + block_size(4) + total_blocks(4) + total_chunks(4)
            total_blocks = struct.unpack('<I', self.data[offset+16:offset+20])[0]
            block_size = struct.unpack('<I', self.data[offset+12:offset+16])[0]
            return min(total_blocks * block_size, 1024 * 1024 * 1024)  # Max 1GB
        except:
            return 512 * 1024 * 1024  # Default 512MB

    def extract_libs_from_data(self):
        """Extract .so libraries directly from image data."""
        libs_dir = self.output_dir / 'extracted_libs'
        libs_dir.mkdir(parents=True, exist_ok=True)

        # Known library signatures and names
        lib_patterns = [
            (b'libGLES_mali.so', 'libGLES_mali.so'),
            (b'libMali.so', 'libMali.so'),
            (b'libUMP.so', 'libUMP.so'),
            (b'gralloc.sun8i.so', 'gralloc.sun8i.so'),
            (b'hwcomposer.sun8i.so', 'hwcomposer.sun8i.so'),
            (b'libcedarc.so', 'libcedarc.so'),
            (b'libcedarx.so', 'libcedarx.so'),
            (b'libcdc_base.so', 'libcdc_base.so'),
            (b'libaw_', 'libaw_mpeg2.so'),
            (b'libVE.so', 'libVE.so'),
            (b'libMemAdapter.so', 'libMemAdapter.so'),
        ]

        # Find ELF files
        elf_magic = b'\x7fELF'
        offset = 0
        elf_count = 0

        print("\n=== Searching for ELF libraries ===")

        while offset < len(self.data) - 100:
            if self.data[offset:offset+4] == elf_magic:
                # Check if it's a shared library (ET_DYN = 3)
                elf_type = struct.unpack('<H', self.data[offset+16:offset+18])[0]
                if elf_type == 3:  # Shared object
                    # Try to find the library name
                    lib_name = self._find_lib_name(offset)
                    if lib_name and any(pattern in lib_name for pattern in
                        [b'mali', b'Mali', b'cedar', b'gralloc', b'hwcomposer', b'VE', b'UMP', b'sun8i']):

                        # Estimate size (look for next ELF or reasonable boundary)
                        size = self._estimate_elf_size(offset)

                        lib_name_str = lib_name.decode('ascii', errors='ignore').strip('\x00')
                        output_path = libs_dir / lib_name_str

                        print(f"  Found: {lib_name_str} at 0x{offset:08x} (~{size:,} bytes)")

                        with open(output_path, 'wb') as f:
                            f.write(self.data[offset:offset+size])

                        elf_count += 1
                        offset += size
                        continue

            offset += 4

        print(f"\nExtracted {elf_count} libraries")
        return elf_count

    def _find_lib_name(self, offset):
        """Try to find library name near ELF header."""
        # Search in a window after the ELF header for .so names
        search_window = self.data[offset:offset+10000]

        # Look for common patterns
        patterns = [
            b'libGLES_mali.so',
            b'libMali.so',
            b'libUMP.so',
            b'gralloc.sun8i.so',
            b'gralloc.sun50i.so',
            b'hwcomposer.sun8i.so',
            b'hwcomposer.sun50i.so',
            b'libcedarc.so',
            b'libcedarx.so',
            b'libcdc_base.so',
            b'libcdc_vd_h264.so',
            b'libcdc_vd_h265.so',
            b'libcdc_vd_mpeg2.so',
            b'libcdc_vd_mpeg4.so',
            b'libVE.so',
            b'libMemAdapter.so',
            b'libvdecoder.so',
            b'libvencoder.so',
            b'audio.primary.sun8i.so',
        ]

        for pattern in patterns:
            if pattern in search_window:
                return pattern

        return None

    def _estimate_elf_size(self, offset):
        """Estimate ELF file size from headers."""
        try:
            # ELF header contains section header offset and count
            is_64bit = self.data[offset+4] == 2

            if is_64bit:
                sh_offset = struct.unpack('<Q', self.data[offset+40:offset+48])[0]
                sh_entsize = struct.unpack('<H', self.data[offset+58:offset+60])[0]
                sh_num = struct.unpack('<H', self.data[offset+60:offset+62])[0]
            else:
                sh_offset = struct.unpack('<I', self.data[offset+32:offset+36])[0]
                sh_entsize = struct.unpack('<H', self.data[offset+46:offset+48])[0]
                sh_num = struct.unpack('<H', self.data[offset+48:offset+50])[0]

            size = sh_offset + (sh_entsize * sh_num)

            # Sanity check
            if size < 1000 or size > 50 * 1024 * 1024:
                return 2 * 1024 * 1024  # Default 2MB

            return size
        except:
            return 2 * 1024 * 1024  # Default 2MB

    def extract_firmware(self):
        """Extract WiFi/BT firmware files."""
        fw_dir = self.output_dir / 'firmware'
        fw_dir.mkdir(parents=True, exist_ok=True)

        print("\n=== Searching for firmware files ===")

        # WiFi firmware patterns
        fw_patterns = [
            (b'xr829', 'xr829.bin'),
            (b'rtl8189', 'rtl8189ftv_fw.bin'),
            (b'rtl8723', 'rtl8723bs_fw.bin'),
            (b'BCM4', 'bcm_wifi.bin'),
            (b'brcmfmac', 'brcmfmac.bin'),
        ]

        for pattern, name in fw_patterns:
            pos = self.data.find(pattern)
            if pos != -1:
                # Extract a chunk around the pattern
                start = max(0, pos - 1024)
                # Find reasonable end
                end = min(len(self.data), pos + 256 * 1024)

                output_path = fw_dir / name
                print(f"  Found {name} pattern at 0x{pos:08x}")

                # Note: This is approximate - real firmware extraction needs more analysis

    def extract_fex_configs(self):
        """Extract all FEX configuration files."""
        fex_dir = self.output_dir / 'fex'
        fex_dir.mkdir(parents=True, exist_ok=True)

        print("\n=== Extracting FEX configurations ===")

        markers = [b'[product]', b'[platform]', b'[target]']
        found = set()

        for marker in markers:
            offset = 0
            while True:
                pos = self.data.find(marker, offset)
                if pos == -1:
                    break

                if pos in found:
                    offset = pos + 1
                    continue

                found.add(pos)

                # Find end of config
                end = pos
                null_count = 0
                while end < len(self.data) and end - pos < 100000:
                    if self.data[end] == 0:
                        null_count += 1
                        if null_count > 10:
                            break
                    else:
                        null_count = 0
                    end += 1

                if end - pos > 500:  # Minimum valid config
                    config_data = self.data[pos:end]
                    # Clean nulls
                    config_data = config_data.replace(b'\x00', b'')

                    output_path = fex_dir / f'sys_config_{len(found)-1}.fex'
                    with open(output_path, 'wb') as f:
                        f.write(config_data)
                    print(f"  Saved: {output_path.name} ({len(config_data)} bytes)")

                offset = end

    def extract_build_prop(self):
        """Extract build.prop file."""
        print("\n=== Extracting build.prop ===")

        start = self.data.find(b'ro.build.id=')
        if start == -1:
            print("  build.prop not found")
            return

        # Find reasonable end
        end = start
        while end < len(self.data) and end - start < 20000:
            # Look for double null or non-printable sequences
            if self.data[end:end+4] == b'\x00\x00\x00\x00':
                break
            end += 1

        prop_data = self.data[start:end]
        # Clean up
        prop_data = prop_data.replace(b'\x00', b'\n')

        output_path = self.output_dir / 'build.prop'
        with open(output_path, 'wb') as f:
            f.write(prop_data)
        print(f"  Saved: {output_path}")

    def create_vendor_structure(self):
        """Create vendor directory structure with placeholders."""
        vendor_dir = self.output_dir / 'vendor_blobs'

        dirs = [
            'lib/egl',
            'lib/hw',
            'lib64/egl',
            'lib64/hw',
            'etc/firmware',
            'etc/wifi',
            'etc/bluetooth',
            'usr/keylayout',
        ]

        for d in dirs:
            (vendor_dir / d).mkdir(parents=True, exist_ok=True)

        print(f"\n=== Vendor structure created at {vendor_dir} ===")
        return vendor_dir

    def run(self):
        """Run full extraction."""
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.read_image()

        print("\n=== Scanning for partitions ===")
        partitions = self.find_all_partitions()

        # Extract boot.img
        for part in partitions:
            if part['type'] == 'boot.img':
                output_path = self.output_dir / 'boot.img'
                with open(output_path, 'wb') as f:
                    f.write(self.data[part['offset']:part['offset']+part['size']])
                print(f"  Extracted: boot.img")
                break

        self.extract_build_prop()
        self.extract_fex_configs()
        self.extract_libs_from_data()
        self.extract_firmware()
        vendor_dir = self.create_vendor_structure()

        # Move extracted libs to vendor structure
        libs_dir = self.output_dir / 'extracted_libs'
        if libs_dir.exists():
            for lib in libs_dir.glob('*.so'):
                if 'egl' in lib.name.lower() or 'gles' in lib.name.lower():
                    dest = vendor_dir / 'lib/egl' / lib.name
                elif 'gralloc' in lib.name.lower() or 'hwcomposer' in lib.name.lower() or 'audio' in lib.name.lower():
                    dest = vendor_dir / 'lib/hw' / lib.name
                else:
                    dest = vendor_dir / 'lib' / lib.name

                lib.rename(dest)
                print(f"  Moved: {lib.name} -> {dest.relative_to(self.output_dir)}")

        print("\n=== Extraction complete ===")
        print(f"Output directory: {self.output_dir}")


def main():
    if len(sys.argv) < 2:
        print("Usage: extract_allwinner_image.py <image.img> [output_dir]")
        sys.exit(1)

    image_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else './extracted_full'

    extractor = AllwinnerImageExtractor(image_path, output_dir)
    extractor.run()


if __name__ == '__main__':
    main()
