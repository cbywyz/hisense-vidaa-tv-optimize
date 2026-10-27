# 07 · 开机广告（15 秒）调查

## 现象

换桌面、停用 `com.hisense.service.ad` 之后，**每次开机仍然先播约 15 秒广告**，播完才进桌面。

## 已经确认的事实

### 1. 广告应用本身已经停用

```bash
adb shell pm list packages -d | grep -E "startupimage|service.ad|business.ad|cloudfalcon"
# package:com.hisense.startupimage
# package:com.hisense.service.ad
# package:com.hisense.business.ad
# package:com.hisense.cloudfalcon
```

`com.hisense.startupimage` 的 codePath 是 `/system/app/StartupImage`，
`enabled=3`（disabled-user）。**停用它并没有消掉广告**，说明广告不是这个 App 播的。

### 2. 广告时长写死在 persist 属性里

```bash
adb shell getprop | grep -i advert
```

```text
[mstar.videoadvert.finished]: [1]
[persist.str.video_advert_time]: [16143]     ← 16.143 秒，和看到的 15 秒广告吻合
[persist.sys.video_advert_time]: [16143]
[persist.sys.advert_jump_url]: [1]
[ro.his.ad.adpath]: [/bootad/local/misc/]    ← 广告素材目录（bootad 分区）
```

`ro.his.ad.adpath` 指向 **`/bootad/local/misc/`**，而且系统里有一个独立的块设备分区：

```bash
adb shell ls -l /dev/block/by-name/bootad
# bootad -> /dev/block/mmcblk0p25
```

也就是说：**开机广告素材单独放在 eMMC 的 `bootad` 分区里，由 bootloader 阶段播放**，
不在 Android 的应用层。这也解释了为什么停用广告 App 没有用。

### 3. 广告开关还有一处

```bash
adb shell settings get global com.hisense.service.ad_block
# 0  → 改成 1
```

这个键名字面意思就是「广告屏蔽」，默认值是 0。

## 已做的处理

```bash
# 1) 广告时长归零（persist，重启后保持）
adb shell setprop persist.sys.video_advert_time 0
adb shell setprop persist.str.video_advert_time 0

# 2) 打开系统侧的广告屏蔽开关
adb shell settings put global com.hisense.service.ad_block 1

# 3) 确认
adb shell getprop persist.sys.video_advert_time   # 0
adb shell settings get global com.hisense.service.ad_block  # 1
```

重启后验证：两个属性仍然是 `0` / `1`（本机实测保持住了）。

## 实测结果：广告已消失（2026-10-27）

设完上面三步后执行 `adb reboot`，**开机不再出现 15 秒广告，直接进 Aerial 桌面**。
重启后复查，三个值都保持住了：

```bash
adb shell getprop persist.sys.video_advert_time          # 0
adb shell getprop persist.str.video_advert_time          # 0
adb shell settings get global com.hisense.service.ad_block  # 1
```

结论：这台机器的开机广告虽然素材来自 `bootad`，但**播放动作是 Android 侧的
StartupImage / 广告服务发起的**，所以「停用 StartupImage + 时长归零 + 广告屏蔽开关」
这套组合能把 15 秒拦掉，不需要 root。

> 以上是**软重启（`adb reboot`）**验证的结果。如果想更彻底，可以拔掉电源等 10 秒再插上
> 做一次冷启动确认——冷启动会完整走一遍 bootloader 流程。本机软重启已经不再播放。

## 换机型/换固件的兜底

| 广告类型 | 能否用 ADB 关 | 说明 |
| --- | --- | --- |
| 应用层开屏广告（聚好看、云视听极光等） | ✅ | 停用对应 App 的广告服务，或换桌面 |
| 系统「开机画面」（StartupImage） | ✅ | `pm disable-user com.hisense.startupimage` + 时长归零 |
| bootloader 阶段直接播放的 bootad 视频 | ❌（无 root） | 素材在 `bootad` 分区，Android 层根本管不到 |

如果按本文做完**仍然**播广告，那才是 bootloader 直接读 `bootad` 分区播放的情况，
彻底去掉只有两条路：

1. **工厂菜单**里找 `Boot Ad` / `AD Switch` / `开机广告` 之类选项（入口见
   [01-adb.md](01-adb.md) 第 1.2 节的三条路径，进的是同一个工厂菜单）；
2. **root 后擦除 `bootad` 分区**（`dd if=/dev/zero of=/dev/block/by-name/bootad`）。

> ⚠️ 第 2 条风险很高：bootad 分区擦错或擦到相邻分区会导致开机卡 logo，而这台机器
> 没有可用的 fastboot/EDL 救砖手段。**没有完整分区备份之前不要动手。**

## 不用 root 的替代方案

1. **不要断电关机，用遥控器待机**：多数 VIDAA 机型从待机唤醒不会重播 bootad 广告
   （代价：待机功耗几瓦，且应用会驻留内存）。
2. 开机后立刻按遥控器「主页」/「返回」，部分固件可以直接跳过。
3. 打海信客服，说明「开机广告影响使用，要求关闭开机广告」——部分机型可以后台关掉。
4. 外接电视盒子（当贝/小米盒子），把电视只当显示器，开机广告就与你无关了。

## 附：怎么确认广告到底在哪一层

```bash
# 开机后马上抓，看有没有 bootad 相关记录
adb logcat -d | grep -i -E "bootad|video_advert|StartupImage"

# 看到类似下面这行，说明 Android 侧还在统计 bootad 分区
# BootReceiver: fs_stat, partition:bootad stat:0x54b
```

如果在 **Android 起来之前**（还没看到桌面、adb 也连不上）就已经在播广告，
那一定是 bootloader 层的 bootad，不用再在应用层找了。
