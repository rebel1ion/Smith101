TARGET := iphone:clang:latest:18.0
ARCHS = arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Smith101

Smith101_FILES = Tweak.xm
Smith101_CFLAGS = -fobjc-arc -O2
Smith101_FRAMEWORKS = UIKit CoreFoundation Foundation Security QuartzCore CoreGraphics
Smith101_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
