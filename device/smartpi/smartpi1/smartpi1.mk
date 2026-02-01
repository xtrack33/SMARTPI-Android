# smartpi1.mk - Main product makefile for SmartPi One

# Inherit device configuration
$(call inherit-product, device/smartpi/smartpi1/device.mk)

# Inherit vendor blobs
$(call inherit-product-if-exists, vendor/smartpi/smartpi1/smartpi1-vendor.mk)

# Product identifiers
PRODUCT_NAME := smartpi1
PRODUCT_DEVICE := smartpi1
PRODUCT_BRAND := SmartPi
PRODUCT_MODEL := SmartPi One
PRODUCT_MANUFACTURER := SmartPi

# Build fingerprint
BUILD_FINGERPRINT := SmartPi/smartpi1/smartpi1:10/QQ3A.200805.001/$(shell date +%Y%m%d):userdebug/release-keys
