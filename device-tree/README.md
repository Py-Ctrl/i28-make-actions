# Android device tree for I28 I28 (sp9820e_xtc_i28)

```
#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
```

## 触摸驱动

有。Cypress **CYTTSP5**（I2C 0x24，DT 节点 `tsc@24`），**已内置编译进 `prebuilt/kernel`**（built-in，非 .ko），recovery 下无需 insmod 即可触摸。
详细证据见 [TOUCH_DRIVER.md](TOUCH_DRIVER.md)。

## 上游仓库

https://github.com/TuberMain/twrp_device_sp9820e_xtc_i28 （唯一分支 `twrp-4.4`，HEAD `99b31ad`）
本地 `twrp_device_sp9820e_xtc_i28-twrp-4.4` 与该分支**内容完全一致**：
`prebuilt/kernel`、`prebuilt/dt.img` SHA1 逐字节相同，文本文件仅检出换行差异。

## 编译

### A. 已有 TWRP 源码树

```bash
export TWRP_SRC=/home/you/twrp                                   # TWRP/Omni 源码根
export DEVICE_DIR=/path/to/twrp_device_sp9820e_xtc_i28-twrp-4.4   # 本目录
bash build.sh recoveryimage                                       # 或 bootimage / clean
```

### B. 从零开始（连 TWRP 源码都没有）

```bash
export TWRP_BRANCH=twrp-11     # 或 twrp-9.0 / twrp-12.1，按你的源码树选
bash sync-and-build.sh         # 装依赖 -> repo sync -> 编 recovery.img
```
需求：Ubuntu 20.04/22.04，磁盘 ≥150GB，内存 ≥16GB。

### 手工步骤（等价）

```bash
cd $TWRP_SRC
cp -r $DEVICE_DIR device/xtc/sp9820e_xtc_i28
. build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch omni_sp9820e_xtc_i28-eng      # vendorsetup.sh 会自动给 system/core/init/init.c 打 selinux 补丁
make -j$(nproc) recoveryimage
```

产物：`$TWRP_SRC/out/target/product/sp9820e_xtc_i28/recovery.img`

### 注意

- 设备树走 `device/xtc/sp9820e_xtc_i28` 路径（`BoardConfig.mk` 里 `DEVICE_PATH` 已写死）。
- `TARGET_FORCE_PREBUILT_KERNEL := true`，使用 `prebuilt/kernel` + `prebuilt/dt.img`，**不需要 kernel 源码**。
- `lunch` 会执行 `patch -Np1 < device/xtc/sp9820e_xtc_i28/init.c.patch` 关闭 SELinux，需安装 `patch`。
- **所有 `.mk / .rc / .sh / .fstab / .patch` 必须 LF**。仓库已加 `.gitattributes` 强制；`build.sh` 也会在编译前体检并自动转 LF。


