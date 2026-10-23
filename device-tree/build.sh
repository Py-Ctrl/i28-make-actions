#!/bin/bash
# =============================================================
#  XTC i28 (sp9820e_xtc_i28) TWRP 编译脚本  —  Linux 编译机执行
#
#  用法:
#     export TWRP_SRC=/home/you/twrp        # TWRP/Omni 源码根目录（必填）
#     bash build.sh                          # 编 recoveryimage（默认）
#     bash build.sh bootimage                # 编 bootimage
#     bash build.sh clean                    # 清 out
#
#  可选项:
#     DEVICE_DIR=/path/to/tree   已存在的设备树目录，不指定则自动从 GitHub 拉取
#     REPO_URL / REPO_BRANCH     设备树仓库（默认 TuberMain/twrp_device_sp9820e_xtc_i28 @ twrp-4.4）
#
#  产物: $TWRP_SRC/out/target/product/sp9820e_xtc_i28/recovery.img
# =============================================================
set -e

DEVICE=sp9820e_xtc_i28
PRODUCT=omni_${DEVICE}
VENDOR=xtc
REPO_URL="${REPO_URL:-https://github.com/TuberMain/twrp_device_sp9820e_xtc_i28}"
REPO_BRANCH="${REPO_BRANCH:-twrp-4.4}"
TARGET="${1:-recoveryimage}"

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="${DEVICE_DIR:-$SELF_DIR}"

# 若本脚本不在设备树里（单独拿到 Linux 上跑），自动 clone
if [ ! -f "$DEVICE_DIR/BoardConfig.mk" ]; then
    echo "[*] 未发现设备树，克隆 $REPO_URL ($REPO_BRANCH)"
    DEVICE_DIR="${TWRP_SRC:-$HOME}/device/$VENDOR/$DEVICE"
    mkdir -p "$(dirname "$DEVICE_DIR")"
    rm -rf "$DEVICE_DIR"
    git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$DEVICE_DIR"
fi

TWRP_SRC="${TWRP_SRC:-$HOME/twrp}"
echo "[*] TWRP 源码 : $TWRP_SRC"
echo "[*] 设备树    : $DEVICE_DIR  ($(cd "$DEVICE_DIR" && git rev-parse --short HEAD 2>/dev/null || echo 无git))"
echo "[*] 编译目标  : $TARGET"

# ---------- 0. 前置检查 ----------
[ -d "$TWRP_SRC" ] || { echo "[!] TWRP_SRC 不存在: $TWRP_SRC"; exit 1; }
[ -f "$TWRP_SRC/build/envsetup.sh" ] || { echo "[!] 未找到 build/envsetup.sh，源码树不完整"; exit 1; }
command -v patch >/dev/null || { echo "[!] 缺少 patch（vendorsetup.sh 要给 init.c 打 selinux 补丁）"; exit 1; }

# ---------- 0.5 换行符体检（Windows 拷过来的 CRLF 会让 make / init 直接炸） ----------
bad=0
while IFS= read -r f; do
    if grep -qU $'\r' "$f" 2>/dev/null; then echo "[!] CRLF: $f"; bad=1; fi
done < <(find "$DEVICE_DIR" -type f ! -path '*/.git/*' \
         \( -name '*.mk' -o -name '*.rc' -o -name '*.sh' -o -name '*.fstab' -o -name '*.patch' -o -name 'Android.bp' \))
if [ "$bad" = 1 ]; then
    echo "[!] 检测到 CRLF 换行，正在转换为 LF ..."
    find "$DEVICE_DIR" -type f ! -path '*/.git/*' \
         \( -name '*.mk' -o -name '*.rc' -o -name '*.sh' -o -name '*.fstab' -o -name '*.patch' -o -name 'Android.bp' \) \
         -exec sed -i 's/\r$//' {} +
    echo "[+] 已转换"
fi

# ---------- 1. 部署设备树到 device/xtc/sp9820e_xtc_i28 ----------
DEST="$TWRP_SRC/device/$VENDOR/$DEVICE"
mkdir -p "$(dirname "$DEST")"
if [ -L "$DEST" ] || [ -d "$DEST" ]; then
    echo "[*] 目标已存在，覆盖: $DEST"
    rm -rf "$DEST"
fi
cp -r "$DEVICE_DIR" "$DEST"
chmod +x "$DEST"/*.sh 2>/dev/null || true
rm -rf "$DEST/.git" 2>/dev/null || true

cd "$TWRP_SRC"

# ---------- 2. 环境 ----------
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
# shellcheck disable=SC1091
source build/envsetup.sh

# ---------- 3. lunch（vendorsetup.sh 会在此自动打 init.c selinux 补丁） ----------
lunch ${PRODUCT}-eng

# ---------- 4. 编译 ----------
JOBS=$(nproc 2>/dev/null || echo 8)
echo "[*] make -j$JOBS $TARGET"
if command -v mka >/dev/null 2>&1; then
    mka "$TARGET"
else
    make -j"$JOBS" "$TARGET"
fi

# ---------- 5. 收尾 ----------
OUT="$TWRP_SRC/out/target/product/$DEVICE"
IMG="$OUT/recovery.img"
[ "$TARGET" = "bootimage" ] && IMG="$OUT/boot.img"
echo
echo "=============================================="
if [ -f "$IMG" ]; then
    echo "[+] 编译完成: $IMG"
    ls -l "$IMG"
    md5sum "$IMG"
    echo
    echo "临时启动: fastboot boot $IMG"
    echo "写入分区: fastboot flash recovery $IMG"
else
    echo "[!] 未找到产物 $IMG，请查看上方 make 报错"
    exit 1
fi
