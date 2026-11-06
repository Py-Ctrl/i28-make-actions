# i28-make-actions

在 GitHub Actions 上给 **XTC i28（sp9820e_xtc_i28）** 编译 TWRP recovery。
本机是 Windows / 没有 Linux 编译环境时走这条路。

- 设备树：随本仓库分发在 `device-tree/`（含 prebuilt kernel + dt.img），不再远端 clone
- 源码：`minimal-manifest-twrp` 的 **`twrp-9.0`** 分支 → TWRP 3.7.0_9
- 产物：`recovery.img`（Actions Artifact，名如 `sp9820e_xtc_i28-twrp-3.7-<run>`）
- 唯一构建线：`.github/workflows/build-twrp-9.yml`

> 旧的三条构建线已删除：`build-twrp.yml`（KitKat 4.4，编出的 3.1 卡第一屏）、
> `build-twrp-modern.yml`（twrp-11/12.1/14，从未跑过）、`probe-runner.yml`（探测 runner 用）。
> 需要的话可从 git 历史恢复：`git checkout <旧commit> -- .github/workflows/<文件名>`。

## 用法

1. 打开仓库 → **Actions** → **Build TWRP 3.7 (Android 9.0)** → **Run workflow**
2. 参数：
   - `DEVICE_TREE_BRANCH` — 设备树分支，固定 `twrp-4.4`
   - `runner` — 默认 **`ubuntu-latest`**（可选 `ubuntu-22.04` / `ubuntu-latest-4/8/16-cores`）
   - `BUILD_TARGET` — `recovery`（默认）或 `boot`
   - `DISABLE_BLANK` — **必须 true**：关掉开机黑屏，否则 ADF 会给触摸 IC 发 POWERDOWN
   - `fresh_ccache` — 勾上则丢弃 ccache 全新编译
3. 跑完在 Artifacts 里下载（约 20–40 分钟，ccache 命中更快）。

也可直接调 API 触发（不传 `runner` 就用默认）：

```sh
curl -u <user>:<token> -X POST \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/Py-Ctrl/i28-make-actions/actions/workflows/build-twrp-9.yml/dispatches \
  -d '{"ref":"main","inputs":{"DEVICE_TREE_BRANCH":"twrp-4.4","BUILD_TARGET":"recovery","DISABLE_BLANK":"true","fresh_ccache":"false"}}'
```

刷机：

```sh
fastboot boot  recovery.img   # 临时启动，不写入
fastboot flash recovery recovery.img
```

## 流程说明

| 步骤 | 作用 |
|---|---|
| 清理磁盘 / 加 12G swap | 托管 runner 盘和内存都不宽裕 |
| 装依赖 | JDK 8（zulu）、`libtinfo.so.5` 等 ncurses5、**Python2**（`build/make` 是 py2 语法）、repo 工具 |
| repo init + sync | `twrp-9.0` manifest，`-g default,pdk`；`-c --no-tags --no-clone-bundle` 省空间 |
| 内嵌设备树 | 从本仓库 `device-tree/` 拷到 `device/xtc/sp9820e_xtc_i28`，不再 clone 远端 |
| CRLF 归一化 | `.mk/.rc/.sh/.fstab/.patch` 转 LF，否则 make 报 missing separator、init 解析 .rc 失败 |
| 源码补丁 | `mtp_MtpServer.cpp` 的 `removable = false` 改成 `true`，让 MTP 多卷在 Windows 里独立显示 |
| 设备 rc 注入 | `PRODUCT_COPY_FILES` 把 `recovery/root/*` 送进 ramdisk；注释掉 `init.c.patch`（9.0 是 `init.cpp`，patch 会卡交互） |
| 编译 | `lunch omni_sp9820e_xtc_i28-eng` → `make -j$(nproc) recoveryimage` |
| 自检 + 上传 | 解析 boot header；上传 Artifact 与 Release |

## 已知限制

- **runner 版本是最大变量**。构建需要 Python2、ncurses5（`libtinfo.so.5`）、JDK 8 这些老依赖，
  workflow 用 18.04 的 deb 包手动补。`ubuntu-latest` 目前是 24.04，若依赖步骤报错，
  在 `runner` 输入里选 **`ubuntu-22.04`** 即可回到已验证可用的组合。
- `timeout-minutes: 350` 是保险值；实际同步 + 编译约 20–40 分钟（ccache 命中后更短）。
- 该设备树必须落在 `device/xtc/sp9820e_xtc_i28`（`BoardConfig.mk` 里 `DEVICE_PATH` 写死）。
- `vendorsetup.sh` 里的 `init.c.patch` 是给 Omni 4.4 的 `init.c` 用的，9.0 下打不上；
  workflow 已把 `patch -Np1` 注释掉。SELinux 实测为 Permissive，不影响挂载与触摸。
- recovery 分区需 ≥ 25MB：9.0 版镜像约 24–25MB，出厂分区表装不下，需先扩容。

## 提速

耗时大头是 **repo sync + 首次全量编译**，不是老 KitKat 线那种从源码编 `external/clang`。

| 手段 | 效果 | 代价 |
|---|---|---|
| ccache（已启用，`ccache -M 5G`） | 第二轮起从 20–40 分钟降到几分钟 | 无 |
| **换 runner 核数**（4/8/16 核） | 近似线性 | larger runner 按分钟计费 |
| **self-hosted runner** | 最快、免费、无 6h 限制 | 需要一台 Linux 机器 |

**ccache 注意事项**：必须**成功**跑完一轮（`Post 恢复 ccache` 不被 skip）缓存才会完整落盘，
前两轮命中率必然是 0%，之后才看得出效果。

## 改自托管 runner

有台 Linux 机器（≥150G 盘 / ≥16G 内存）的话，把 `runs-on` 改成 `self-hosted`。
**注意**：这条 workflow 不使用 `container:`，所以 JDK 8、Python2、ncurses5、repo 等依赖
需要直接装在宿主机上；`runner` 输入里没有 `self-hosted` 选项，改 `runs-on` 即可。

## 触摸与挂载（设备树定制）

- 触摸：cyttsp5 驱动已 built-in 进 `prebuilt/kernel`，但 probe 会 disable 自己的 IRQ。
  Android 在 `sys.boot_completed=1` 时写 `nobark` 调用 `enable_cyttsp5_and_irq()`，
  recovery 从不写，所以 `on boot` 里直接 `write /sys/kernel/bbk_softdog/bbkwatchdog "nobark"`。
- 输入设备：这台机器的 ueventd 只建扁平 `/dev/eventN`，TWRP 只扫 `/dev/input/`，
  所以 `on boot` 里 `mkdir /dev/input` + 9 条 `symlink`。
- 挂载：**Android 9 的 ueventd 不再自动创建 by-name 链接**（5.1 会），
  fstab 里的 `/dev/block/platform/soc/by-name/*` 会解析成空、mount 报 `Invalid argument`。
  `on boot` 里按内核 `PARTNAME` 建回 38 个链接（两套路径）。
- `/vendor`：fstab 里已删掉该行，不再报 "Unable to mount /vendor"。

## 设备树已内嵌（device-tree/）

| 文件 | 改动 |
|---|---|
| `recovery.fstab` | 删 `/vendor`；给 `/system` `/data` `/productinfo` `/xtcdata` 加 `storage` + `storagename` |
| `BoardConfig.mk` | 删 `TW_SCREEN_BLANK_ON_BOOT`；加 `TW_INTERNAL/EXTERNAL_STORAGE_PATH`、`TW_HAS_MTP`、`RECOVERY_SDCARD_ON_DATA` |
| `omni_sp9820e_xtc_i28.mk` | `PRODUCT_MODEL := D3-i28 TWRP`（MTP 名去掉 "(by Cms)"） |
| `recovery/root/init.recovery.sp9820e_xtc_i28.rc` | `on boot` 里建 `/dev/input` + 9 symlink、写 `nobark`、建 38×2 条 by-name symlink；`on property` 兜底再写一次 `nobark` |
| `device.mk` | `PRODUCT_COPY_FILES` 把设备 rc 送进 ramdisk |
| `.github/workflows/build-twrp-9.yml` | 上述源码补丁与注入步骤 |

> 内核仍是设备树里的 prebuilt（未打补丁）。触摸靠运行时写 softdog 节点打开，
> 若哪代内核改了该节点路径，同步改 rc 里的 `write` 即可。
