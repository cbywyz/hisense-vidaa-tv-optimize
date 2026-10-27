# 海信 VIDAA 电视优化实录（换桌面 / 去广告 / 提速 / 信号源）

> 一台 2019 年前后的海信 VIDAA 电视（Android 9、MTK9255、**933MB 内存**、720p），
> 通过 ADB 换掉原桌面、停用广告与遥测服务、清理桌面垃圾图标、调优动画与后台，
> 把开机闲置内存从 **59MB 提升到 125MB**，swap 占用从 42MB 降到 **0**，卡顿明显缓解。
>
> 所有改动都是 `pm disable-user` + `settings put` + `appops`，**不刷机、不 root、不卸载系统应用**，
> 随时可用一个脚本还原。

## 目录

| 文档 | 内容 |
| --- | --- |
| [docs/01-adb.md](docs/01-adb.md) | **开启 ADB 全流程**（含「有线连不上、无线能连」的实测与排查） |
| [docs/02-debloat.md](docs/02-debloat.md) | 停用清单：广告 / 遥测 / OTA / 屏保 / 侧栏，逐项说明理由与风险 |
| [docs/03-launcher-aerial.md](docs/03-launcher-aerial.md) | 换 Aerial 桌面并设为默认 Home，保留聚好看 |
| [docs/04-performance.md](docs/04-performance.md) | 内存瓶颈分析、动画倍率、AOT 预编译、后台限制、实测数据 |
| [docs/05-signal-source.md](docs/05-signal-source.md) | **为什么屏幕上做不出「信号源」入口**，以及唯一可行的路径 |
| [docs/06-troubleshooting.md](docs/06-troubleshooting.md) | 卡顿、卸载卡住、Home 失效、信号源消失等问题的处理 |
| [docs/07-boot-ad.md](docs/07-boot-ad.md) | 开机 15 秒广告：bootad 分区、`video_advert_time` 与能否关闭 |
| [scripts/](scripts/) | `audit.sh`（只读体检）/ `debloat.sh`（分阶段停用）/ `optimize.sh`（调优）/ `restore.sh`（还原） |

## 本机信息（实测）

```text
型号        VIDAA_TV（Hisense）
系统        Android 9 / SDK 28
固件        PPR2.180905.006.A1 release-keys
芯片        MTK9255（ro.boot.hardware=mt5862，4×A53 1.3GHz）
内存        933MB（实际可用约 911MB）
屏幕        1280x720 / density 213
存储        eMMC，无 root，ro.adb.secure=1
ADB         192.168.3.205:5555（persist.adb.tcp.port=5555，重启后仍可连）
无线 MAC    8c:35:92:14:ec:48（wlan0）
有线 MAC    e4:3b:c9:b1:8b:43（eth0）
```

## 优化效果（本机实测）

| 指标 | 优化前 | 优化后 |
| --- | --- | --- |
| 开机闲置 MemFree | 约 59–60MB | **125MB**（峰值约 180MB） |
| MemAvailable | 约 383MB | **575MB** |
| zram swap 占用 | 42MB | **0** |
| 常驻第三方进程 | 15 个 | **7–8 个** |
| 已停用包 | 0 | **32 个** |
| 桌面图标 | 24 个 | **8 个** |
| 广告/推送/埋点服务 | 全部在跑 | 全部停用 |
| Home 键 | 聚好看（含广告位） | Aerial |

> 内存在实际播放视频/投屏时会自然下降，以上为开机闲置 5 分钟后的数值。

## 快速开始

```bash
# 0) 准备 adb（Windows 示例路径，按自己的改）
ADB=/c/Users/Administrator/.workbuddy/platform-tools/platform-tools/adb.exe
$ADB connect 192.168.3.205:5555

# 1) 先看体检报告，不改任何东西
sh scripts/audit.sh 192.168.3.205

# 2) 分阶段停用（建议逐段执行，每段后重启验证）
sh scripts/debloat.sh 192.168.3.205 1   # 广告/遥测
sh scripts/debloat.sh 192.168.3.205 2   # OTA/屏保/引导/识图/侧栏
sh scripts/debloat.sh 192.168.3.205 3   # 原桌面（先装好新桌面再跑！）

# 3) 性能调优（动画 0.5 + AOT 预编译 + 后台限制）
sh scripts/optimize.sh 192.168.3.205

# 4) 不满意？一键还原
sh scripts/restore.sh 192.168.3.205
```

**执行顺序很重要**：`debloat.sh 3` 会停用聚好看桌面，务必先在 Aerial 里确认能正常当桌面，
否则可能出现「开机黑屏、没有桌面」的局面（救法见 [docs/06](docs/06-troubleshooting.md)）。

## 三条最重要的结论

1. **ADB 走无线，不要折腾有线。** 同一台电视、同一个端口，网线插着时 `adb connect` 连不上，
   改用 Wi-Fi 立刻成功。具体实测与排查见 [docs/01](docs/01-adb.md)。
2. **聚好看（`com.jamdeo.tv.vod`）不能永久停用。** 海信没有注册标准
   `android.media.tv.TvInputService`，遥控器上的「信号源」键是聚好看的私有悬浮窗在响应。
   停用聚好看 = 信号源入口彻底消失。见 [docs/05](docs/05-signal-source.md)。
3. **换桌面只改默认 Home，不要卸载原桌面**，否则信号源和部分系统设置入口会一起消失。
4. **开机 15 秒广告已消除**（本机实测）。素材虽然放在 `bootad` 分区，但播放是 Android 侧
   StartupImage / 广告服务发起的：停用 `com.hisense.startupimage` + 把
   `persist.sys.video_advert_time` 设为 0 + `com.hisense.service.ad_block=1` 就能拦掉。
   见 [docs/07](docs/07-boot-ad.md)。

## 适用与不适用

**适用**：海信/VIDAA 的 Android 9 左右机型（MTK 或 MStar 方案），尤其是 1GB 内存的低端机。
包名（`com.hisense.*` / `com.jamdeo.*`）在海信 VIDAA 体系里通用，但**不同固件版本的包集合不同**，
脚本对不存在的包会跳过，不会报错。

**不适用**：Android TV / Google TV 版海信（系统是标准 Android TV，信号源走 TvInputService，
不存在本文的信号源问题）；已 root 或刷了第三方固件的机器。

## 风险声明

- 停用系统包属于**非官方操作**，可能影响保修；出问题请先跑 `restore.sh`，再考虑恢复出厂设置。
- 停用 `com.jamdeo.updateservice` 会**永久关闭 OTA**（好处是厂商不会把广告推回来，坏处是没有安全补丁）。
- 本文所有包名与命令均在作者机器上实测；**在你自己的机器上执行前，请先跑 `audit.sh` 确认包存在**。
- 本项目仅供个人折腾记录，不构成任何官方支持。

## 许可

MIT
