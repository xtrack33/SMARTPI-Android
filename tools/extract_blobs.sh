#!/bin/bash
# extract_blobs.sh - Extract proprietary blobs from Android system image
# Usage: ./extract_blobs.sh <system.img> [output_dir]

set -e

SYSTEM_IMG="${1:-}"
OUTPUT_DIR="${2:-vendor/smartpi/smartpi1}"

if [ -z "$SYSTEM_IMG" ]; then
    echo "Usage: $0 <system.img> [output_dir]"
    echo ""
    echo "Extracts Mali GPU and other proprietary blobs from Android system image."
    echo ""
    echo "For Allwinner IMAGEWTY format, first extract system.img using:"
    echo "  python3 tools/awimage_extract.py image.img extracted/"
    echo ""
    exit 1
fi

if [ ! -f "$SYSTEM_IMG" ]; then
    echo "Error: $SYSTEM_IMG not found"
    exit 1
fi

# Create output directories
echo "=== Creating output directories ==="
mkdir -p "$OUTPUT_DIR/lib/egl"
mkdir -p "$OUTPUT_DIR/lib/hw"
mkdir -p "$OUTPUT_DIR/lib64/egl"
mkdir -p "$OUTPUT_DIR/lib64/hw"
mkdir -p "$OUTPUT_DIR/etc/firmware"
mkdir -p "$OUTPUT_DIR/etc/wifi"
mkdir -p "$OUTPUT_DIR/etc/bluetooth"
mkdir -p "$OUTPUT_DIR/usr/keylayout"

# Check if it's a sparse image and convert if needed
echo "=== Checking image format ==="
FILE_TYPE=$(file "$SYSTEM_IMG")

if echo "$FILE_TYPE" | grep -q "Android sparse image"; then
    echo "Converting sparse image to raw..."
    TEMP_IMG=$(mktemp)
    simg2img "$SYSTEM_IMG" "$TEMP_IMG"
    SYSTEM_IMG="$TEMP_IMG"
    CLEANUP_TEMP=1
fi

# Create mount point
MOUNT_POINT=$(mktemp -d)
echo "=== Mounting image at $MOUNT_POINT ==="

# Try to mount (requires root)
if ! sudo mount -o loop,ro "$SYSTEM_IMG" "$MOUNT_POINT" 2>/dev/null; then
    echo "Warning: Cannot mount image directly. Trying to extract with 7z..."

    # Try 7z extraction
    if command -v 7z &> /dev/null; then
        7z x -o"$MOUNT_POINT" "$SYSTEM_IMG" 2>/dev/null || true
    else
        echo "Error: Cannot mount or extract image. Install p7zip-full or run as root."
        exit 1
    fi
fi

echo "=== Extracting Mali GPU blobs ==="
# Mali GPU libraries
MALI_LIBS=(
    "lib/egl/libGLES_mali.so"
    "lib/libMali.so"
    "lib/libUMP.so"
    "vendor/lib/egl/libGLES_mali.so"
    "vendor/lib/libMali.so"
)

for lib in "${MALI_LIBS[@]}"; do
    if [ -f "$MOUNT_POINT/$lib" ]; then
        echo "  Found: $lib"
        cp "$MOUNT_POINT/$lib" "$OUTPUT_DIR/lib/egl/" 2>/dev/null || \
        cp "$MOUNT_POINT/$lib" "$OUTPUT_DIR/lib/" 2>/dev/null || true
    fi
done

echo "=== Extracting HAL modules ==="
# Hardware abstraction layers
HAL_MODULES=(
    "lib/hw/gralloc.sun8i.so"
    "lib/hw/hwcomposer.sun8i.so"
    "lib/hw/audio.primary.sun8i.so"
    "lib/hw/memtrack.sun8i.so"
    "vendor/lib/hw/gralloc.sun8i.so"
    "vendor/lib/hw/hwcomposer.sun8i.so"
)

for hal in "${HAL_MODULES[@]}"; do
    if [ -f "$MOUNT_POINT/$hal" ]; then
        echo "  Found: $hal"
        cp "$MOUNT_POINT/$hal" "$OUTPUT_DIR/lib/hw/" 2>/dev/null || true
    fi
done

echo "=== Extracting CedarX video codecs ==="
CEDAR_LIBS=(
    "lib/libcedarc.so"
    "lib/libcedarx.so"
    "lib/libcdc_base.so"
    "lib/libcdc_vd_h264.so"
    "lib/libcdc_vd_h265.so"
    "lib/libcdc_vd_mpeg2.so"
    "lib/libcdc_vd_mpeg4.so"
    "lib/libcdc_vd_vp8.so"
    "lib/libcdc_vd_mjpeg.so"
    "lib/libVE.so"
    "lib/libMemAdapter.so"
    "vendor/lib/libcedarc.so"
    "vendor/lib/libcedarx.so"
)

for cedar in "${CEDAR_LIBS[@]}"; do
    if [ -f "$MOUNT_POINT/$cedar" ]; then
        echo "  Found: $cedar"
        cp "$MOUNT_POINT/$cedar" "$OUTPUT_DIR/lib/" 2>/dev/null || true
    fi
done

echo "=== Extracting WiFi firmware ==="
WIFI_FW=(
    "etc/firmware/xr829.bin"
    "etc/firmware/xr829_bt.bin"
    "etc/firmware/xr829_sdd.bin"
    "etc/firmware/rtl8189ftv_fw.bin"
    "etc/firmware/rtl8723bs_nic.bin"
    "vendor/firmware/xr829.bin"
    "vendor/firmware/rtl8189ftv_fw.bin"
)

for fw in "${WIFI_FW[@]}"; do
    if [ -f "$MOUNT_POINT/$fw" ]; then
        echo "  Found: $fw"
        cp "$MOUNT_POINT/$fw" "$OUTPUT_DIR/etc/firmware/" 2>/dev/null || true
    fi
done

echo "=== Extracting configuration files ==="
# WiFi config
if [ -f "$MOUNT_POINT/etc/wifi/wpa_supplicant.conf" ]; then
    cp "$MOUNT_POINT/etc/wifi/wpa_supplicant.conf" "$OUTPUT_DIR/etc/wifi/"
fi

# Keylayout
if [ -f "$MOUNT_POINT/usr/keylayout/sunxi-ir.kl" ]; then
    cp "$MOUNT_POINT/usr/keylayout/sunxi-ir.kl" "$OUTPUT_DIR/usr/keylayout/"
fi

echo "=== Cleanup ==="
sudo umount "$MOUNT_POINT" 2>/dev/null || true
rmdir "$MOUNT_POINT" 2>/dev/null || true

if [ "${CLEANUP_TEMP:-0}" = "1" ]; then
    rm -f "$TEMP_IMG"
fi

echo ""
echo "=== Extraction complete ==="
echo "Blobs extracted to: $OUTPUT_DIR"
echo ""
echo "Directory structure:"
find "$OUTPUT_DIR" -type f | head -30

echo ""
echo "Next steps:"
echo "1. Review extracted files"
echo "2. Update vendor/smartpi/smartpi1/smartpi1-vendor.mk"
echo "3. Commit the vendor blobs to a separate repository"
