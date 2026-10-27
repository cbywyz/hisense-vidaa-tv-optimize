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
