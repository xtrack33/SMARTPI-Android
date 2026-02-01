# device.mk for SmartPi One (Allwinner H3)

DEVICE_PATH := device/smartpi/smartpi1

# Inherit from common GloDroid configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Device identifiers
PRODUCT_NAME := smartpi1
PRODUCT_DEVICE := smartpi1
PRODUCT_BRAND := SmartPi
PRODUCT_MODEL := SmartPi One
PRODUCT_MANUFACTURER := SmartPi
PRODUCT_BOARD := sun8i-h3

# Build properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.first_api_level=29 \
    ro.hardware=smartpi1 \
    ro.opengles.version=131072 \
    ro.sf.lcd_density=160 \
    persist.sys.timezone=Europe/Paris

# Dalvik/ART
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=192m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

# GPU Mali400
PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.egl=mali \
    debug.hwui.renderer=opengl

# Audio
PRODUCT_PROPERTY_OVERRIDES += \
    audio.output.active=AUDIO_CODEC,AUDIO_HDMI \
    audio.input.active=AUDIO_CODEC

# WiFi
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0 \
    wifi.supplicant_scan_interval=15

# Display
PRODUCT_PROPERTY_OVERRIDES += \
    sys.display-size=1920x1080 \
    persist.sys.hdmi_hpd=1

# USB
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=mtp,adb \
    ro.adb.secure=0

# Fstab
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/fstab.smartpi1:$(TARGET_COPY_OUT_RAMDISK)/fstab.smartpi1 \
    $(DEVICE_PATH)/fstab.smartpi1:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.smartpi1

# Init scripts
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init.smartpi1.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.smartpi1.rc \
    $(DEVICE_PATH)/init.smartpi1.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.smartpi1.usb.rc \
    $(DEVICE_PATH)/ueventd.smartpi1.rc:$(TARGET_COPY_OUT_VENDOR)/ueventd.rc

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \
    frameworks/native/data/etc/android.software.app_widgets.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.app_widgets.xml

# Media codecs
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(DEVICE_PATH)/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml

# Audio configuration
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml

# Keylayout
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/gpio-keys.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/gpio-keys.kl

# Graphics packages
PRODUCT_PACKAGES += \
    libGLES_mali \
    gralloc.sun8i \
    hwcomposer.sun8i \
    libdrm \
    libdrm_freedreno

# Audio packages
PRODUCT_PACKAGES += \
    audio.primary.smartpi1 \
    audio.a2dp.default \
    audio.usb.default \
    audio.r_submix.default \
    libaudioutils \
    libtinyalsa

# WiFi packages
PRODUCT_PACKAGES += \
    hostapd \
    wpa_supplicant \
    wpa_supplicant.conf \
    libwpa_client

# USB
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service

# Keymaster
PRODUCT_PACKAGES += \
    android.hardware.keymaster@3.0-impl \
    android.hardware.keymaster@3.0-service

# Gatekeeper
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-impl \
    android.hardware.gatekeeper@1.0-service

# Health
PRODUCT_PACKAGES += \
    android.hardware.health@2.0-service

# Light
PRODUCT_PACKAGES += \
    android.hardware.light@2.0-service.smartpi1

# Power
PRODUCT_PACKAGES += \
    android.hardware.power@1.0-service

# Memtrack
PRODUCT_PACKAGES += \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service

# Graphics
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.mapper@2.0-impl

# DRM
PRODUCT_PACKAGES += \
    android.hardware.drm@1.0-impl \
    android.hardware.drm@1.0-service
