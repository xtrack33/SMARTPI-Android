# Vendor makefile for SmartPi One
# Using open-source drivers (Lima/Mesa) - minimal proprietary blobs needed

VENDOR_PATH := vendor/smartpi/smartpi1

# ============================================
# OPEN-SOURCE GPU (Lima/Mesa)
# No proprietary Mali blobs required!
# ============================================

# Mesa3D provides Lima driver for Mali400
PRODUCT_PACKAGES += \
    libGLES_mesa \
    libEGL_mesa \
    libGLESv1_CM_mesa \
    libGLESv2_mesa

# Gralloc and HWComposer from GloDroid/minigbm
PRODUCT_PACKAGES += \
    gralloc.minigbm \
    hwcomposer.drm

# ============================================
# VIDEO DECODER (CedarX)
# ============================================

# libVE.so extracted from original image
PRODUCT_COPY_FILES += \
    $(VENDOR_PATH)/lib/libVE.so:$(TARGET_COPY_OUT_VENDOR)/lib/libVE.so

# ============================================
# WIFI FIRMWARE
# ============================================

# Firmware files will be downloaded during build or provided separately
# Common chips on H3 boards: RTL8189FTV, XR829, RTL8723BS

# ============================================
# WIFI CONFIGURATION
# ============================================

PRODUCT_COPY_FILES += \
    $(VENDOR_PATH)/etc/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf

# ============================================
# AUDIO
# ============================================

PRODUCT_PACKAGES += \
    audio.primary.default \
    audio.a2dp.default \
    audio.usb.default \
    audio.r_submix.default

# ============================================
# IR REMOTE
# ============================================

PRODUCT_COPY_FILES += \
    $(VENDOR_PATH)/keylayout/sunxi-ir.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/sunxi-ir.kl

# ============================================
# BUILD PROPERTIES
# ============================================

PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.egl=mesa \
    ro.hardware.gralloc=minigbm \
    ro.hardware.hwcomposer=drm \
    debug.hwui.renderer=opengl
