#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校验 recovery.img 的 ramdisk 里是否包含设备专属 rc 文件。

用法: python3 check_ramdisk.py <recovery.img> [期望的文件...]
退出码 0 = 全部存在；1 = 有缺失（会把缺失项打出来）
"""
import gzip
import struct
import sys

DEFAULT_WANTS = (
    "init.recovery.sp9820e_xtc_i28.rc",
    "ueventd.sp9820e_xtc_i28.rc",
    "etc/recovery.fstab",
    "init.recovery.usb.rc",
    "sbin/recovery",
    "twres/watch.xml",
)


def ramdisk_names(path):
    d = open(path, "rb").read()
    if d[:8] != b"ANDROID!":
        sys.exit("不是 Android boot 镜像: %s" % d[:8])
    ksize = struct.unpack("<I", d[8:12])[0]
    rsize = struct.unpack("<I", d[16:20])[0]
    page = struct.unpack("<I", d[36:40])[0]
    dtsize = struct.unpack("<I", d[40:44])[0]
    koj = page
    roj = koj + ((ksize + page - 1) // page) * page
    print("boot header: kernel=%d ramdisk=%d dt=%d page=%d"
          % (ksize, rsize, dtsize, page))
    raw = gzip.decompress(d[roj:roj + rsize])
    names = set()
    off = 0
    while off + 110 <= len(raw):
        if raw[off:off + 6] not in (b"070701", b"070702"):
            break
        f = lambda o: int(raw[off + 6 + o * 8:off + 6 + (o + 1) * 8], 16)
        nsize, fsize = f(11), f(6)
        n = off + 110
        name = raw[n:n + nsize - 1].decode("utf-8", "replace")
        n2 = (n + nsize + 3) & ~3
        off = (n2 + fsize + 3) & ~3
        names.add(name)
        if name == "TRAILER!!!":
            break
    return names


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    names = ramdisk_names(sys.argv[1])
    wants = sys.argv[2:] or list(DEFAULT_WANTS)
    missing = [w for w in wants if w not in names]
    for w in wants:
        print(("  [OK] " if w not in missing else "  [!!] 缺失 ") + w)
    if missing:
        print("\n%! 缺失 %d 项: %s" % (len(missing), ", ".join(missing)))
        return 1
    print("\n%+ ramdisk 关键文件齐全")
    return 0


if __name__ == "__main__":
    sys.exit(main())
