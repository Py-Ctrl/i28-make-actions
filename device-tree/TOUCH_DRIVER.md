# i28 (sp9820e_xtc_i28) 触摸驱动核查报告

结论：**有触摸驱动，且已内置编译进 `prebuilt/kernel`，recovery 下可直接出图并响应触摸。**

## 1. 触摸 IC 型号

Cypress（赛普拉斯）**CYTTSP5** 系列，I2C 接口，从地址 **0x24**。

## 2. 证据

### 2.1 设备树 `prebuilt/dt.img`（SPRD 头，`53 50 52 44`）

在偏移 `0x2258` 处有唯一触摸节点 `tsc@24`：

```
tsc@24
  compatible = "cy,cyttsp5_i2c_adapter"
  reg        = <0x24>
  cy,core    -> compatible = "cyttsp5_core"
  cy,mt      -> compatible = "cyttsp5_mt"
```

全 dt.img 内只此一个触摸节点（`gtp` / `ctp@` / `touch@` 均无匹配），说明机器只有一颗 TP。

### 2.2 内核 `prebuilt/kernel`（10,547,200 字节，非压缩 ARM Image）

字符串命中 `cyttsp*` 共 **177** 条，关键如下：

| 命中 | 含义 |
|---|---|
| `cyttsp5` / `cyttsp5_i2c_adapter` / `cyttsp5_mt` / `cyttsp5_btn` / `cyttsp5_proximity` / `cyttsp5_device_access` / `cyttsp5_loader` | 核心 + I2C 适配 + 多点 + 按键 + 接近感应 + 设备访问 + 固件加载器**全部存在** |
| `cyttsp5_probe` / `cyttsp5_mt_probe` / `cyttsp5_btn_probe` / `cyttsp5_proximity_probe` / `cyttsp5_device_access_probe` / `cyttsp5_loader_probe` | probe 函数符号在 Image 内 ⇒ **built-in(=y)，不是外部 .ko**，不需 insmod |
| `INIT CYTTSP RST gpio=%d and IRQ gpio=%d` / `RESET CYTTSP gpio=%d` | 复位与中断 GPIO 由驱动自行申请 |
| `cyttsp5_probe the i2c address is %d, g_xtc_tp_type:%d` | XTC 厂家的 TP 型号选择逻辑（本内核只有 cyttsp5 一支） |
| `touchscreen_parse_properties` + `touchscreen-size-x/y`、`touchscreen-max-pressure` | 通用 touchscreen 属性解析已编入 |

未发现其他 TP 驱动（ft5x06 / gt9xx / gsl / silead / hynitron / himax / ilitek 均为 0 命中）。

### 2.3 recovery 侧

- `recovery/root/ueventd.rc:44` → `/dev/input/* 0660 root input`，TWRP 能正常打开 event 节点。
- `BoardConfig.mk` 已有 `TW_INPUT_BLACKLIST := "hbtp_vm"`，不会把 TP 误屏蔽。
- 主题 `TW_THEME := watch_mdpi`（圆形表盘），触摸坐标直接由 cyttsp5_mt 上报。

## 3. 风险点（均已排除）

1. **是否依赖外部固件？** 驱动内含 `cyttsp5_loader`（仅用于升级 FW）。正常 probe 走 `cyttsp5_core` 内置路径；且日志串 `No cmcp threshold file.` / `Failed loading cmcp threshold file, attempting legacy file` 表明缺少 `/productinfo/tsx.dat` 时会回退 legacy，**不会导致 probe 失败**。recovery.fstab 里 `/productinfo`（prodnv，ext4）已列，需要时 TWRP 可直接挂载。
2. **是否依赖 .ko 模块？** 否，probe 符号在 Image 内。
3. **是否需要 insmod？** 否，rc 中无需添加任何 insmod。

## 4. 上机自检命令（recovery 起来后 adb shell）

```sh
# 1) 驱动是否 probe 成功
dmesg | grep -i cyttsp
#    期望: INIT CYTTSP RST gpio=.. and IRQ gpio=.. / cyttsp5_probe the i2c address is 36(0x24)

# 2) input 节点是否生成
getevent -il | grep -i -A3 cyttsp
ls -l /dev/input/

# 3) 内核是否上报触摸事件（手指划屏应有输出）
getevent -l /dev/input/eventX

# 4) TWRP 侧是否识别
cat /tmp/recovery.log | grep -i -E "input|touch|event"
```

若 `getevent` 无 cyttsp5 设备，优先查：`dmesg | grep -iE "cyttsp|i2c"` 看 I2C 0x24 是否 NAK（硬件/排线问题，非 recovery 问题）。

## 5. 与编译相关的结论

- `TARGET_FORCE_PREBUILT_KERNEL := true` + `TARGET_PREBUILT_KERNEL := prebuilt/kernel` → 直接用原厂内核，触摸能力 100% 继承，无需移植驱动。
- `BOARD_KERNEL_SEPARATED_DT` 被置空、`BOARD_MKBOOTIMG_ARGS += --dt prebuilt/dt.img` → dt 一并打包，`tsc@24` 节点会生效。
- 因此 **无需为触摸额外修改任何配置**，可直接编译。
