# 02 · 停用清单：广告、遥测、OTA、屏保

## 原则

1. **只 `pm disable-user`，不 `pm uninstall`。**
   卸载会把 APK 从 userdata 删掉，系统分区里还有一份，OTA 之后可能「复活」；
   而且卸载后想恢复得重新找安装包。`disable-user` 只是把包标记为对当前用户禁用，
   随时 `pm enable` 回来，**不占运行内存**，风险最低。
2. **一次只跑一个阶段，跑完重启验证。** 出问题能立刻定位到是哪一批。
3. **先看再改。** 先跑 `scripts/audit.sh`，确认你的固件里真的有这些包（不同年份 VIDAA 的包集合不一样）。

```bash
ADB=/c/Users/Administrator/.workbuddy/platform-tools/platform-tools/adb.exe
$ADB connect 192.168.3.205:5555
$ADB shell pm list packages | grep -E 'hisense|jamdeo' | sort
```

---

## 第一轮：广告 / 遥测 / 推广（收益最大）

| 包名 | 作用 | 停用影响 |
| --- | --- | --- |
| `com.hisense.service.ad` | 广告服务，内含阿里百川电商 SDK + 无障碍监听，**双进程约 200MB** | 开屏/贴片广告消失。收益最大的一项 |
| `com.hisense.business.ad` | 广告业务（淘宝客/百川） | 同上 |
| `com.hisense.cloudfalcon` | 广告落地页 WebActivity，开机自启 | 点广告跳转的页面没了（本来也不需要） |
| `com.hisense.service.message` | 厂商推送消息 | 收不到海信的系统推送/促销 |
| `com.hisense.hitv.das` | 观看数据埋点 | 无感知 |
| `com.hisense.logupload` | 日志上传 | 无感知 |
| `com.hisense.hotelmenu` | 酒店模式 | 家用无影响 |
| `com.hisense.autotest` | 工厂自动测试 | 无影响（售后检测会用到，恢复即可） |
| `com.hisense.hitv.payment` | 支付 | 电视内购/会员支付不可用 |
| `com.hisense.startupimage` | 开机画面 / 开机广告 | **开机更快**，不再看 15 秒广告 |

## 第二轮：更新 / 屏保 / 引导 / 识图 / 侧栏

| 包名 | 作用 | 停用影响 |
| --- | --- | --- |
| `com.jamdeo.updateservice` | 系统 OTA 更新 | **永久关闭 OTA**。好处：厂商不会把广告/新固件推回来；坏处：没有安全补丁。想保留更新就别停这个 |
| `com.jamdeo.screensaver` | 原厂屏保（可能带推广） | 屏保交给新桌面（Aerial 自带） |
| `com.jamdeo.tv.fte` | 首次开机引导 | 不会再走开机向导（已配置好的机器无影响） |
| `com.hisense.smartimages` | AI 识图，需屏幕内容识别权限，常驻约 15MB | 「识图」功能不可用 |
| `com.hisense.horizontalassistantmenu` | 侧边助手菜单 | 侧栏不再弹出 |

## 第三轮：原桌面聚好看 —— 只能「换」，不能「停」

```text
com.jamdeo.tv.vod     # 原桌面 / 内容聚合，360 RePlugin 框架 + KeepAliveService 自我保活，常驻约 97MB
```

这是单点收益最大的一项（97MB），但**本机最终没有停用它**，原因：

- 海信没有注册标准 `android.media.tv.TvInputService`；
- 遥控器上的「信号源」键由聚好看的私有悬浮窗 `SignalWindow` 响应；
- 停用聚好看后，**信号源入口彻底消失**，只剩拔插 HDMI 或进系统设置里翻。

所以正确做法是：**装好新桌面 → 设为默认 Home → 聚好看保持 `enable`**。
它不再当桌面，就不会常驻 97MB；需要切信号源时按遥控器上的信号源键，聚好看的浮窗会起来。

> 本机实测：聚好看保持启用 + Aerial 当 Home 时，闲置内存仍然有 112MB，
> 因为它不再常驻，只在你按信号源键时被拉起。

如果你**完全不用 HDMI、只看网络视频**，可以停用它多拿回 ~97MB，
代价是再也调不出信号源面板。恢复：

```bash
adb shell pm enable com.jamdeo.tv.vod
adb shell cmd package set-home-activity com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity
```

## 第四轮：只限后台，不砍功能（appops）

这几个是「要用的时候得在」，但没必要常驻后台：

```bash
for p in com.multiscreen.airplay com.android.wechathci \
         com.sohu.inputmethod.sogou.tv com.android.gallery3d; do
  adb shell cmd appops set $p RUN_IN_BACKGROUND ignore
done
```

| 包名 | 作用 | 影响 |
| --- | --- | --- |
| `com.multiscreen.airplay` | 手机投屏 | 前台投屏仍可用，后台不常驻 |
| `com.android.wechathci` | 微信电视助手 | 同上 |
| `com.sohu.inputmethod.sogou.tv` | 搜狗输入法 | 打字时仍能弹出，只是不后台驻留 |
| `com.android.gallery3d` | 媒体扫描 / 图库 | U 盘、本地视频仍可播 |

## 第五轮：系统级设置

| 项 | 原值 | 新值 | 说明 |
| --- | --- | --- | --- |
| `window_animation_scale` | 1.0 | 0.5 | 窗口动画减半，主观流畅度提升最明显 |
| `transition_animation_scale` | 1.0 | 0.5 | 同上 |
| `animator_duration_scale` | 1.0 | 0.5 | 同上 |

```bash
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5
```

另有 **AOT 预编译**（`cmd package compile -m speed`），见 [04-performance.md](04-performance.md)。

## 额外一项：`com.android.bluetooth`（谨慎！）

本机把 `com.android.bluetooth` 也停用了（这台用的是红外遥控器，电视也不需要蓝牙外设）。
**如果你的遥控器是蓝牙遥控器，或者要用蓝牙音箱/耳机/游戏手柄，千万不要停这个包**，
否则遥控器会直接失联，只能用机身按键或重新进系统恢复。

```bash
# 确认你的遥控器类型：看系统里有没有蓝牙配对记录
adb shell dumpsys bluetooth_manager | grep -i -E "bonded|name" | head
```

## 第六轮：桌面垃圾图标 + 语音助手（2026-10-27 追加）

换 Aerial 之后，桌面上仍会列出系统里所有带 LAUNCHER 入口的应用，其中一大半是电视永远用不到的
AOSP 残留。这些包停用后**图标直接从桌面消失，进程也不会再起**。

### 6.1 图标类（15 个）

| 包名 | 桌面名称 | 停用影响 |
| --- | --- | --- |
| `com.hisense.systeminfo` | SystemInfo | 无（售后查版本/温度/内存的调试工具，日常用不到） |
| `com.android.contacts` | 通讯录 | 无（电视不打电话） |
| `com.android.calendar` | 日历 | 无 |
| `com.android.deskclock` | 时钟 | 闹钟/计时器不可用。**后台实测占 112MB，收益很大** |
| `com.android.music` | 音乐 | 本地音乐播放没了（媒体中心仍可播） |
| `com.android.browser` | 浏览器 | 应用内跳网页可能失败（广告已停，日常无感） |
| `com.android.camera2` | 相机 | 无（无摄像头硬件） |
| `com.android.gallery3d` | 图库 | 不能看图，U 盘视频仍可用媒体中心播 |
| `com.android.soundrecorder` | 录音机 | 无 |
| `com.android.printspooler` | 打印服务 | 无 |
| `com.android.wechathci` | 微信电视 | 无法用微信投屏/遥控，手机投屏仍可用 Hi投屏 |
| `com.cvte.tv.at` | （无图标）工厂自动化测试 | 无（售后检测时恢复） |
| `com.hisense.usbupgrade` | （无图标）U 盘强制升级 | 无法用 U 盘刷固件（我们本来也关了 OTA） |
| `com.hisense.infaredcodesettings` | （无图标）红外码设置 | 无 |
| `fusion.android.tv.demo` | （无图标）演示模式 | 无 |

```bash
for p in com.hisense.systeminfo com.android.contacts com.android.calendar \
         com.android.wechathci com.android.browser com.android.camera2 \
         com.android.deskclock com.android.music com.android.gallery3d \
         com.android.soundrecorder com.android.printspooler com.cvte.tv.at \
         com.hisense.usbupgrade com.hisense.infaredcodesettings \
         fusion.android.tv.demo; do
  adb shell pm disable-user --user 0 $p
done
```

> **踩坑记录：Aerial 里「隐藏」不等于停用。**
>
> 第一遍清理时有 6 个包（通讯录、日历、时钟、相机、音乐、浏览器）在 Aerial 里点了隐藏，
> 桌面上确实看不到了，看起来像处理完；但 `pm list packages -d` 里根本没有它们，
> **进程照常在后台跑**（时钟仍然占着 112MB）。
>
> 教训：**验收标准永远是 `pm list packages -d | grep 包名` 有输出**，
> 而不是「桌面图标不见了」。Aerial 的隐藏只是画面上不画这个图标，
> 应用本身照样启动、照样占内存。真正的停用必须走 `pm disable-user`。

### 6.2 语音助手 + 会员中心（8 个，约省 350MB）

这一组是**取舍**，不是纯垃圾——停用后遥控器语音键会失效：

| 包名 | 作用 | 后台实测 |
| --- | --- | --- |
| `com.hisense.vidaaassistant` | 小聚助手（语音入口） | 约 71MB |
| `com.keylab.speech.core.vidaa` | 语音识别核心 | 约 82MB |
| `com.keylab.speech.view.vidaa` | 语音 UI | 约 69MB |
| `com.hisense.tv.aivirtualassistant` | AI 虚拟助手 | 约 76MB |
| `com.hisense.voicecontrol` | 语音控制 | 系统应用 |
| `com.hisense.msvoicetome` | 语音转文字 | 系统应用 |
| `com.hispeech.ai.area` | 讯飞语音区域服务 | — |
| `com.hisense.hitv.hicloud.account` | 会员中心 / 海信账号 | 约 61MB |

```bash
for p in com.hisense.vidaaassistant com.keylab.speech.core.vidaa \
         com.keylab.speech.view.vidaa com.hisense.tv.aivirtualassistant \
         com.hisense.voicecontrol com.hisense.msvoicetome \
         com.hispeech.ai.area com.hisense.hitv.hicloud.account; do
  adb shell pm disable-user --user 0 $p
done
```

**停用代价**：遥控器「语音」键无响应、语音搜片不可用、海信会员/账号入口消失；
爱奇艺、云视听极光等第三方 App 的会员与登录**不受影响**。
想恢复语音，执行：

```bash
for p in com.hisense.vidaaassistant com.keylab.speech.core.vidaa \
         com.keylab.speech.view.vidaa com.hisense.tv.aivirtualassistant \
         com.hisense.voicecontrol com.hisense.msvoicetome \
         com.hispeech.ai.area com.hisense.hitv.hicloud.account; do
  adb shell pm enable $p
done
adb reboot
```

### 6.3 停不掉的那个图标：聚好看

桌面上还会留一个「聚好看」图标。它**不能停用**（信号源面板宿主，见
[05-signal-source.md](05-signal-source.md)），只能在 Aerial 里长按图标 → 隐藏。
隐藏只是不显示，不影响按遥控器信号源键唤出面板。

### 6.4 本机实测效果

| 指标 | 清理前 | 清理后 |
| --- | --- | --- |
| 桌面图标（Aerial 全部应用） | 24 个（含 15 个垃圾） | **8 个** |
| 已停用包总数 | 16 | **39**（含二次补齐的 6 个「只隐藏没停用」） |
| `MemFree` | 52MB | **125MB** |
| `MemAvailable` | 383MB | **575MB** |
| zram swap 占用 | 98MB | **0** |
| 开机到桌面 | 约 30 秒 | 约 28 秒 |

剩下的 8 个图标：云视听极光、Hi投屏、媒体中心、同花顺、当贝市场、当贝助手、聚好看、系统设置。
（Aerial 自己是桌面，不计入图标列表。）

## 执行与验证

```bash
# 分阶段执行（推荐）
sh scripts/debloat.sh 192.168.3.205 1
adb reboot        # 重启后确认：能开机、能进桌面、广告没了、遥控器正常
sh scripts/debloat.sh 192.168.3.205 2
adb reboot
```

逐项验证：

```bash
adb shell pm list packages -d          # 已停用的包
adb shell dumpsys package com.hisense.service.ad | grep -m2 -E "enabled|stopped"
adb shell ps -A | grep -i -E "hisense|jamdeo"   # 看还有哪些进程在跑
```

## 出问题怎么退

```bash
# 全部恢复
sh scripts/restore.sh 192.168.3.205

# 只恢复某一个
adb shell pm enable com.jamdeo.tv.vod
adb shell pm enable com.android.bluetooth
```

> 停用不会丢数据。真正会「回不来」的只有卸载（`pm uninstall`），所以本文一条卸载命令都没有。
