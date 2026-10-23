#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/xtc/sp9820e_xtc_i28

# KitKat 构建系统只 wildcard recovery/res，不拷 recovery/root；
# 设备专属 rc 必须经 PRODUCT_COPY_FILES 进 PRODUCT_OUT/root 才会被
# cp -R $(TARGET_ROOT_OUT) 带进 recovery/root（否则 init 起不来，卡 Logo 屏）。
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.sp9820e_xtc_i28.rc:root/init.recovery.sp9820e_xtc_i28.rc \
    $(LOCAL_PATH)/recovery/root/ueventd.sp9820e_xtc_i28.rc:root/ueventd.sp9820e_xtc_i28.rc

PRODUCT_COPY_FILES +=     $(LOCAL_PATH)/recovery/root/tpirq.sh:root/sbin/tpirq.sh
