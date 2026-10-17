# i28-make-actions

在 GitHub Actions 上给 **XTC i28（sp9820e_xtc_i28）** 编译 TWRP recovery。
本机是 Windows / 没有 Linux 编译环境时走这条路。

- 设备树：`TuberMain/twrp_device_sp9820e_xtc_i28`（分支 `twrp-4.4`）
- 源码：`minimal-manifest-twrp` 官方 minimal manifest
- 产物：`sp9820e_xtc_i28-recovery.img`（Actions Artifact，保留 30 天）

## 用法

1. 推到 GitHub 后，打开仓库 → **Actions** → 右侧 **Build TWRP for XTC i28** → **Run workflow**
2. 参数：
   - `twrp_branch` — TWRP 分支，**不确定就先 `twrp-11`**，编不过再试 `twrp-9.0`/`twrp-12.1`
   - `device_branch` — 设备树分支，默认 `twrp-4.4`
   - `target` — `recoveryimage`（默认）或 `bootimage`
   - `fresh_ccache` — 勾上则丢弃 ccache 全新编译
3. 跑完在 Artifacts 里下载镜像。

刷机：

```sh
fastboot boot  sp9820e_xtc_i28-recovery.img   # 临时启动，不写入
fastboot flash recovery sp9820e_xtc_i28-recovery.img
```

## 流程说明

| 步骤 | 作用 |
|---|---|
| 清理磁盘 | 托管 runner 只有约 14G 可用盘，先删 Android SDK / .NET / Haskell / Docker 镜像 |
| 加 8G swap | 16G 内存编译 TWRP 有点紧 |
| repo init + sync | `--depth=1 -c --no-tags --no-clone-bundle`，设备树用 local_manifest 挂进去 |
| 删除 `.repo` | sync 完立刻删，回收一半空间给 out/ |
| 换行符体检 | 把 `.mk/.rc/.sh/.fstab/.patch` 的 CRLF 转 LF，否则 make 报 missing separator、init 解析 .rc 失败 |
| make | `lunch omni_sp9820e_xtc_i28-eng` → `make -j$(nproc) recoveryimage` |

## 已知限制（重要）

- **单次任务上限 6 小时**，已设 350 分钟超时。同步 + 编译通常 2–5 小时；
  若某分支源码太大导致同步阶段就超时，换 `twrp-9.0`（源码最小）重试。
- **磁盘是最大风险**。若 `make` 阶段报 `No space left on device`：
  把 `runs-on` 改成 `ubuntu-24.04`（部分机器盘更大），或改用 **self-hosted runner**（见下）。
- 该设备树必须落在 `device/xtc/sp9820e_xtc_i28`（`BoardConfig.mk` 里 `DEVICE_PATH` 写死）。
- `vendorsetup.sh` 里的 `init.c.patch` 只对 Omni 4.4 时代的 `system/core/init/init.c` 有效；
  在 TWRP 3.x（Android 9+）源码上会打不上，但 `patch -Np1` 失败不会中断 lunch，
  只是 SELinux 保持 enforcing —— TWRP 3.x 自身会处理，通常无影响。

## 提速

构建耗时的大头是 **`external/clang` 从源码编一遍**（KitKat manifest 锁死 `prebuilts/clang 3.3`，AOSP 会把整个 clang 编出来给宿主工具链用），4 核上就要好几分钟。

| 手段 | 效果 | 代价 |
|---|---|---|
| ccache（已启用，`ccache -M 5G`） | 第二轮起生效 | 无 |
| **换 runner 核数**（`runner` 下拉可选 4/8/16 核） | 近似线性 | larger runner 按分钟计费 |
| **self-hosted runner** | 最快、免费、无 6h 限制 | 需要一台 Linux 机器 |
| 去掉 `make clean` | 省掉非编译类的重复产出 | 源码变动时可能脏 |

**ccache 注意事项（重要）**：前两轮命中率必然是 0%
—— 第一轮缓存为空；第二轮的缓存曾被 `CCACHE_MAXSIZE` 环境变量失效导致的 1GB 上限
用 LRU 挤到只剩 1402 个文件（7884 个编译当然命不中）。
必须**成功**跑完一轮（`Post 恢复 ccache` 不被 skip）缓存才会完整落盘，之后才看得出效果。

## 改自托管 runner（盘不够 / 想更快的兜底）

有台 Linux 机器（≥150G 盘 / ≥16G 内存）的话：

```yaml
    runs-on: self-hosted
```

然后在 workflow 的 `runner` 输入里选 `self-hosted`（或加自定义标签）。
**注意**：self-hosted 下 `container:` 不生效，需要把 Ubuntu 18.04 容器那套
（apt 依赖、GLIBC 2.28、Python2、JDK7）改成直接在宿主机装好。

## 触摸驱动

设备用的 Cypress **CYTTSP5**（I2C 0x24），已内置编译进 `prebuilt/kernel`（built-in，非 .ko），
recovery 下无需 insmod。详见设备树仓库的 `TOUCH_DRIVER.md`。
