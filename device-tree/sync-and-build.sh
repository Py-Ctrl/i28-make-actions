#!/bin/bash
# =============================================================
#  从零开始：拉 TWRP 源码 + 拉设备树 + 编 recovery.img
#  适用于一台干净的 Ubuntu 20.04/22.04（物理机 / 云主机 / 虚拟机均可）
#
#  用法:
#     export TWRP_BRANCH=twrp-11        # TWRP 分支，见下方说明
#     bash sync-and-build.sh
#
#  磁盘需求: >=150GB    内存: >=16GB（32G 更稳）    时间: 同步 1-3h + 编译 1-3h
# =============================================================
set -e

DEVICE=sp9820e_xtc_i28
SRC="${TWRP_SRC:-$HOME/twrp}"
# TWRP 官方 minimal manifest 分支，按你的源码树选：
#   twrp-9.0  -> TWRP 3.3/3.4（老设备、kernel 3.x/4.4 兼容性最好）
#   twrp-11   -> TWRP 3.6/3.7（默认，arm 32-bit 仍受支持）
#   twrp-12.1 -> TWRP 3.7
BRANCH="${TWRP_BRANCH:-twrp-11}"
MANIFEST="https://github.com/minimal-manifest-twrp/platform_manifest_twrp.git"
DEVICE_REPO="https://github.com/TuberMain/twrp_device_sp9820e_xtc_i28"
DEVICE_BRANCH="twrp-4.4"

echo "[*] 源码目录 : $SRC"
echo "[*] TWRP 分支: $BRANCH"

# ---------- 1. 装依赖 ----------
if ! command -v repo >/dev/null 2>&1; then
    echo "[*] 安装编译依赖 (需要 sudo)"
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        git-core gnupg flex bison build-essential zip curl zlib1g-dev \
        libc6-dev-i386 lib32ncurses5-dev lib32z1-dev \
        libgl1-mesa-dev libxml2-utils xsltproc unzip \
        python3 python3-pip bc ccache libssl-dev \
        openjdk-11-jdk-headless schedtool patch
    sudo mkdir -p /usr/local/bin
    sudo curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    sudo chmod +x /usr/local/bin/repo
fi

# ---------- 2. 同步 TWRP 源码 ----------
mkdir -p "$SRC"
cd "$SRC"
if [ ! -d .repo ]; then
    echo "[*] repo init -b $BRANCH"
    repo init -u "$MANIFEST" -b "$BRANCH" --depth=1
fi
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/i28.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="TuberMain/twrp_device_sp9820e_xtc_i28"
           path="device/xtc/${DEVICE}"
           remote="github"
           revision="${DEVICE_BRANCH}" />
  <remote name="github" fetch="https://github.com" />
</manifest>
EOF
echo "[*] repo sync -j$(nproc) -c --no-tags --no-clone-bundle"
repo sync -j"$(nproc)" -c --no-tags --no-clone-bundle --force-sync

# 若 local_manifest 没拉到（remote 声明顺序问题），手动兜底
[ -d "device/xtc/$DEVICE" ] || git clone -b "$DEVICE_BRANCH" --depth 1 "$DEVICE_REPO" "device/xtc/$DEVICE"

# ---------- 3. 编译 ----------
export TWRP_SRC="$SRC"
export DEVICE_DIR="$SRC/device/xtc/$DEVICE"
bash "$(dirname "${BASH_SOURCE[0]}")/build.sh" "${1:-recoveryimage}"
