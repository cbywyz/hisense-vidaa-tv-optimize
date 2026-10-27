# 03 · 换桌面：Aerial

原桌面「聚好看」是内容和广告的聚合入口：RePlugin 插件框架 + `KeepAliveService` 自我保活，
光桌面就常驻约 97MB。在 933MB 内存的机器上，这是卡顿的主要来源之一。

本机最终用的是 **Aerial 1.57**（包名 `app.orchard.tv`，入口 `app.orchard.tv.MainActivity`）：
体积小、无广告、启动快，遥控器方向键/OK/返回都正常，Home 键能回。

> 也试过自己构建的 cleanyourtv（`com.gathin.tvhome`），它能编译进「输入源」入口，
> 但海信上那个入口打开的只是快捷设置页，**并不能真正切换信号源**，最终卸载。
> 详见 [05-signal-source.md](05-signal-source.md)。

---

## 1. 装 APK

> 本仓库不附带第三方 APK，请从 Aerial 项目的 Release 页下载，或用你自己的安装包。
> 下面以本地文件 `aerial-1.57.apk` 为例。

```bash
ADB=/c/Users/Administrator/.workbuddy/platform-tools/platform-tools/adb.exe
$ADB connect 192.168.3.205:5555

$ADB install -r aerial-1.57.apk
# 期望：Success
```

装完先**手动**打开一次，确认能用：

```bash
$ADB shell am start -n app.orchard.tv/.MainActivity
```

用遥控器走一遍：方向键移动、OK 打开应用、返回键、设置页。都正常再继续。

## 2. 设为默认 Home

```bash
# 看当前默认桌面
$ADB shell cmd package resolve-activity --brief \
  -c android.intent.category.HOME -a android.intent.action.MAIN

# 列出所有候选桌面
$ADB shell cmd package query-activities --brief \
  -c android.intent.category.HOME -a android.intent.action.MAIN

# 设为 Aerial
$ADB shell cmd package set-home-activity app.orchard.tv/.MainActivity
```

设完按遥控器 **Home** 键，应该直接回 Aerial。

> 如果 `set-home-activity` 报权限错误（部分固件限制 shell 改默认桌面），
> 就在电视上手动设：设置 → 应用 → 默认应用 → 主屏幕 → 选 Aerial。
> 海信有些固件藏在「设置 → 系统 → 主屏幕」里。

## 3. 关键：聚好看保持启用

```bash
$ADB shell pm enable com.jamdeo.tv.vod
```

**不要**为了省内存把它停掉——遥控器「信号源」键要靠它的悬浮窗响应。
它不当桌面后不会常驻，只在按信号源键时被拉起，代价可以接受。

如果之前已经停用了，恢复后再按一次信号源键验证：

```bash
$ADB shell pm enable com.jamdeo.tv.vod
$ADB shell am start -n com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity
# 然后按遥控器信号源键，应出现频道/HDMI 切换浮层
```

## 4. 重启验证

```bash
$ADB reboot
```

等 40–60 秒，确认三件事：

1. 开机直接进 Aerial，没有黑屏、没有「选择桌面」弹窗；
2. 按 Home 能回到 Aerial（不会跳回聚好看）；
3. 遥控器信号源键仍能调出切换面板。

## 5. 回退

```bash
# 把 Home 还给聚好看
$ADB shell cmd package set-home-activity \
  com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity

# 或者卸载 Aerial（可选）
$ADB uninstall app.orchard.tv
```

## 6. 桌面选型对比（本机实测）

| 桌面 | 包名 | 体积 | 优点 | 缺点 |
| --- | --- | --- | --- | --- |
| Aerial 1.57 | `app.orchard.tv` | 约 3MB | 轻、无广告、启动快、遥控器适配好 | 屏幕上的「信号源」入口为空（海信限制，非桌面问题） |
| cleanyourtv（自建） | `com.gathin.tvhome` | 约 6MB | 可改代码、可塞自定义入口 | 海信上「输入源」只能打开快捷设置页；自建需维护 CI |
| 聚好看（原厂） | `com.jamdeo.tv.vod` | 常驻 97MB | 信号源面板、系统整合完整 | 广告多、后台保活、卡顿主因 |

**结论**：Aerial 当桌面 + 聚好看留着当「信号源面板宿主」，是这台机器的最优组合。
