# 05 · 信号源：为什么屏幕上找不到入口

这是本次折腾里花了最多时间、结论也最确定的一块。**先说结论：**

> 在海信 VIDAA 上，第三方桌面（包括 Aerial、cleanyourtv、以及任何自己写的 App）
> **不可能**做出一个能真正切换 HDMI/AV 的「信号源」界面。
> 唯一可用的入口是**遥控器上的「信号源」物理键**，而且**聚好看必须保持启用**。

下面是完整的验证过程，给以后的自己（或者遇到同样问题的你）省点时间。

---

## 1. 现象

- 换成 Aerial 后，桌面上的「信号源 / 输入源」打开是**空白列表**；
- 自己构建的 cleanyourtv 把「输入源」指向海信的快捷设置页，按下去出来的是**快捷设置面板**，
  不是频道/HDMI 切换界面；
- 但用**实体遥控器按「信号源」键**，能正常弹出信道切换浮层——说明功能在，只是入口不在标准 API 里。

## 2. 根本原因：海信没有注册标准 TV Input

Android TV 的信号源标准做法是实现 `android.media.tv.TvInputService`，
第三方 App 通过 `TvInputManager` 枚举输入源并调 `TvView`/`createSession` 切源。

本机检查：

```bash
adb shell dumpsys tv_input
# 输出里的 HDMI / 硬件输入列表为空，没有任何 TvInputService 注册

adb shell pm list packages | grep -i -E "tvinput|inputservice"
# 没有相关包
```

也就是说：**系统根本没向 Android 的 TvInput 框架注册 HDMI 输入**，
Aerial 这类桌面去查 `TvInputManager.getTvInputList()` 自然拿到空数组，
所以界面上就是空的——这不是桌面的 bug。

## 3. 真正的面板在哪：聚好看的私有悬浮窗

海信把信号源做成了自己的私有实现，宿主是原桌面/内容聚合应用 **聚好看**
（`com.jamdeo.tv.vod`）：

| 组件 | 作用 |
| --- | --- |
| `SignalWindow` | 信号源切换浮层（你按信号源键看到的那个） |
| `SignalViewService` | 承载浮层的服务 |
| `com.jamdeo.tv.policy.PANEL_EVENT` | 遥控器私有按键事件（信号源键发的就是它） |

遥控器按下信号源键 → 系统发 `PANEL_EVENT` 私有广播 → 聚好看收到后拉起 `SignalWindow`。

**这条路对第三方 App 是封死的**：广播和服务都受海信**平台签名级权限**保护，
普通应用（uid 2000，即 `shell`/第三方）既发不出去也调不起来。

## 4. 我们试过、并且失败了的方案

按尝试顺序记录，避免重复踩坑：

### 4.1 直接找「信号源」Activity 并启动

反查聚好看的 54 个 Activity，逐个看名字和 intent-filter，**没有一个是信号源切换界面**。
信号源是 Service + 悬浮窗，不是 Activity，`am start` 无从下手。

### 4.2 发私有广播模拟按键

```bash
adb shell am broadcast -a com.jamdeo.tv.policy.PANEL_EVENT ...
# 结果：Permission Denial: not allowed to send broadcast ... from uid=2000
```

普通应用/ADB shell 没有海信签名，直接被系统拒绝。

### 4.3 直接启动 / 绑定 `SignalViewService`

```bash
adb shell am startservice ...
# 结果：Requires permission ... not exported（或 permission denied）
```

服务 `exported=false` 且带签名权限，第三方无法调用。

### 4.4 用海信快捷设置页冒充

海信有一个导出的 Activity：

```text
com.android.tv.settings/com.hisense.systemsettings.quicksettings.QuickSettingsActivity
exported=true
```

cleanyourtv 的「输入源」就是跳到这里的。但它只是**快捷设置面板**，
里面只有「开机信号源」这种一次性设置，**不能切换当前信号源**——所以按下去"页面不对"。

### 4.5 Aerial 自带的海信入口

Aerial 有海信/Vidda 的适配代码，尝试调用：

```text
com.hisense.tv.InputsUIService
com.hisense.tv.inputs
```

本机检查两个都 `Not found`。Aerial 官方也说明海信/VIDAA 不支持它的私有信号源面板。

## 5. 结论

| 方案 | 可行 | 说明 |
| --- | --- | --- |
| 遥控器「信号源」物理键 | ✅ | 唯一稳定入口，前提：聚好看 `enable` |
| 第三方桌面做信号源界面 | ❌ | 系统没有 TvInputService，拿不到输入源列表 |
| 第三方 App 调聚好看面板 | ❌ | 广播/服务均有平台签名权限保护 |
| 海信快捷设置页 | ⚠️ | 只能设「开机信号源」，不能切当前源 |
| root + 注入/改系统签名 | ❌（本机） | 无 root，且不建议为这个功能刷机 |

**所以本机的最终形态就是：Aerial 当桌面，聚好看留着当「信号源面板宿主」。**
聚好看不再当桌面，就不会常驻 97MB；只有你按信号源键时它才被拉起来。

## 6. 如果哪天信号源键没反应了

按顺序检查（本机真实踩过）：

```bash
# 1) 聚好看是不是被停用了（最常见原因）
adb shell pm list packages -d | grep jamdeo

# 2) 恢复它
adb shell pm enable com.jamdeo.tv.vod

# 3) 拉起一次，让它的服务注册上
adb shell am start -n com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity

# 4) 再按遥控器信号源键
```

如果聚好看是启用的、但按键还是没反应，重启电视一次（它的服务偶发不注册）。

## 7. 怎么确认 HDMI 设备真的接上了

没有信号源面板时，可以用系统层看 HDMI 状态：

```bash
adb shell dumpsys display | grep -i -E "hdmi|external" | head
adb shell dumpsys hdmi 2>/dev/null | head -30
```

另外：HDMI 口插着设备时，电视通常会自动切过去；这句话本身也说明——**物理上能用，
只是软件入口被厂商锁在私有实现里**。
