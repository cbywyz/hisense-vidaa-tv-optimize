# 01 · 开启 ADB 并连上电视

海信 VIDAA 是**深度定制的 Android**，不是 Android TV。它的「开发者选项」默认隐藏，
不同年份的固件入口还不一样。这一章按「先打开开关 → 再连上 → 最后固化」三段写。

> 一句话结论：**用 Wi-Fi 连，不要用网线。** 本机实测同一个 `5555` 端口，
> 有线怎么都连不上，切到无线立刻成功。原因排查见第 4 节。

---

## 1. 电视端：打开 ADB 开关

### 1.1 先判断你的 VIDAA 属于哪一代

在电视上进入 **设置 → 关于 / 本机信息**，记下「软件版本」或「系统版本」。也可以连上后看：

```bash
adb shell getprop ro.build.version.release   # 9
adb shell getprop ro.build.version.sdk       # 28
adb shell getprop ro.product.model           # VIDAA_TV
```

### 1.2 三条常见入口（按顺序试）

VIDAA 的调试开关藏在「工厂菜单」里，固件不同入口不同：

**路径 A：设置 → 声音 → 声音平衡**（VIDAA 4.0 及以后最常见）

1. 进入「设置 → 声音 → 声音平衡」；
2. 遥控器快速按 **菜单 → OK → 菜单 → OK**（部分机型是 **菜单 → 菜单 → OK → OK**，
   带红绿黄蓝键的遥控器则是 **红 → 绿 → 黄 → 蓝**）；
3. 屏幕出现工厂菜单（可能是半透明浮层），进 **选项 / Option**；
4. 把 **`To Fac`** 从 `U` 改成 `M`（部分固件叫 `Factory` / `Factory Mode`，值 `U`→`M`）；
5. 退出并**断电重启**（遥控器关机不够，拔插头 10 秒更稳）。

**路径 B：关于本机 → 连按菜单键 + 确认键**

1. 设置 → 关于 → 本机信息；
2. 连按遥控器 **菜单键 4–5 次**，再连按 **确认键 7–10 次**；
3. 若弹出「已进入开发者模式」或直接进入隐藏的原生 Android 设置，就成功了；
4. 在原生设置里找 **开发者选项 → USB 调试 / ADB 调试**，打开。

**路径 C：VIDAA 助手（老机型）**

我的应用 → VIDAA 助手 → 设置 → **电视调试授权** → 打开。
部分机型还需要在应用管理里找到 **ADB Service** 并启用。

### 1.3 必须打开的两个开关

进入开发者选项后，确认这两项：

| 开关名（不同固件叫法） | 作用 | 必须 |
| --- | --- | --- |
| USB 调试 / ADB 调试 | 允许 adb 连接 | 是 |
| 网络调试 / ADB over Network / Wi-Fi 调试 | 允许 TCP 5555 | 是（只用局域网时） |

### 1.4 本机（VIDAA_TV / Android 9 / mt5862）的实际状态

打开成功后，用下面几条命令确认，比看菜单可靠：

```bash
adb shell getprop persist.adb.tcp.port    # 5555   ← 端口已持久化
adb shell getprop persist.service.adb.enable  # 1
adb shell getprop init.svc.adbd           # running
adb shell getprop ro.adb.secure           # 1      ← 首次连接需要在电视上点「允许」
```

如果 `persist.adb.tcp.port` 是空的，用一次：

```bash
adb shell setprop persist.adb.tcp.port 5555
# 没有 root 时若提示权限不足，改用：
adb tcpip 5555
```

`setprop persist.*` 会写进 `persist` 分区，**重启后依然有效**（本机重启后实测仍可直接连接）。

---

## 2. 电脑端：连接

```bash
# Windows 下 adb 一般在 platform-tools 里，按自己的路径改
ADB=/c/Users/Administrator/.workbuddy/platform-tools/platform-tools/adb.exe

$ADB connect 192.168.3.205:5555
# 期望输出：connected to 192.168.3.205:5555

$ADB devices
# 期望输出：192.168.3.205:5555   device
```

首次连接时电视会弹「是否允许 USB 调试」，**用遥控器选「允许」并勾选「一律允许」**。
没弹窗或误点拒绝，执行：

```bash
adb kill-server && adb start-server
# 或到电视的开发者选项里「撤销 USB 调试授权」后重连
```

### 2.1 电视 IP 怎么找

设置 → 网络 → 有线/无线网络 → 当前连接，能看到 IP。
本机无线是 `192.168.3.205`（主路由网段 `192.168.3.0/24`）。

> **强烈建议**：在路由器上按 MAC 给电视绑一个静态 DHCP 地址。
> 电视的 IP 会随租约变化，绑了之后脚本里的 IP 永远有效。
> 本机无线 MAC：`8c:35:92:14:ec:48`。

---

## 3. 固化：让电视重启后还能连

海信的 `adbd` 在 `5555` 上监听，且 `persist.adb.tcp.port` 已写入时，重启后不需要再执行
`adb tcpip`。验证方式：

```bash
adb reboot
# 等电视起来（约 40-60 秒）
adb connect 192.168.3.205:5555
adb devices
```

如果重启后连不上，通常是 `persist.adb.tcp.port` 没写进去（固件把它重置了），
需要重新走一次工厂菜单，或改用**每次开机后执行一次 `adb tcpip 5555`**（可做成计划任务）。

---

## 4. 重点：有线连不上，无线反而能连

这是本次折腾里最反直觉的一点，单独记一节。

### 4.1 实测现象

同一台电视、同一台电脑、同一个 `5555` 端口：

| 电视联网方式 | 电视 IP | `adb connect` 结果 |
| --- | --- | --- |
| 网线（eth0） | 路由器 DHCP 分配 | `failed to connect` / `Connection refused`，重试多次无效 |
| Wi-Fi（wlan0） | 192.168.3.205 | **一次成功**，`adb devices` 显示 `device` |

### 4.2 电视侧的真实状态

用无线连上后看接口，有线口其实是 `UP` 但**没有地址**（网线拔了或没拿到 DHCP）：

```text
$ adb shell ip -o addr show
lo     127.0.0.1/8
wlan0  192.168.3.205/24
```

```text
$ adb shell netstat -ln | grep 5555
tcp6  0  0 :::5555  :::*  LISTEN
```

注意 adbd 监听的是 `:::5555`（所有地址、IPv6 双栈），**理论上不挑网卡**。
所以「有线不行」不是 adbd 只绑了 wlan0，而是**有线那条链路本身没通到电视的 IP**。

### 4.3 四个最可能的原因（按概率排序）

1. **有线根本没拿到 IP / 不在同一网段**
   电视的有线口接了光猫、旧路由或交换机上联口，拿到的是 `192.168.1.x`，
   而电脑在 `192.168.3.x`，跨网段又没路由 → 连不上。
   *验证*：电视「设置 → 网络 → 有线」看 IP；或 `ping <电视有线IP>` 从电脑测。
2. **有线口链路起不来（百兆口协商失败 / 网线只通了 4 芯）**
   低端机的百兆口对劣质网线很挑，指示灯亮但拿不到地址。
   *验证*：看路由器 DHCP 租约里有没有电视的有线 MAC（本机 `e4:3b:c9:b1:8b:43`）。
3. **同时连着 Wi-Fi 和网线，默认路由走了 Wi-Fi**
   Android 的 `adb connect` 用的是你给的那个 IP，但如果这个 IP 属于一张没跑通的网卡，
   包就出不去。表现就是「IP 能 ping 通、adb 连不上」或反过来。
   *验证*：只留网线、关掉电视 Wi-Fi，再试一次。
4. **固件对有线口的 adbd 做了限制 / 防火墙只放行 wlan0**
   定制 ROM 里确实存在这种策略（虽然不常见）。
   *验证*：有线状态下 `adb shell netstat -ln | grep 5555` 是否还在监听（需要先用别的方式连上）。

### 4.4 结论与建议

- **直接用无线连 ADB**，这是本机唯一稳定可用的方式，不必再在有线上耗时间。
- 无线连接质量足够跑 `pm` / `settings` / `screencap`（本机 RSSI -43dBm，65Mbps 协商速率）。
- 如果必须用有线（比如 Wi-Fi 信号差）：
  1. 关掉电视 Wi-Fi，只留网线；
  2. 确认电视有线 IP 和电脑在同一网段、能互 ping；
  3. 再 `adb connect <有线IP>:5555`；
  4. 还不行就在路由器上抓包/看防火墙，排除 AP 隔离与 IoT 隔离。
- **不要**因为「有线连不上」去反复开关开发者选项或恢复出厂——本机证明开关是好的，
  问题在链路层，不在 adbd。

---

## 5. 连接故障速查

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `connection refused` | 电视端 ADB 开关没开 / adbd 没监听 | 重开开发者选项；`getprop init.svc.adbd` 应为 running |
| `Connection timed out` | IP 不对 / 跨网段 / 电视休眠断网 | 确认 IP、关电视节能待机、优先用无线 |
| `unauthorized` | 没点「允许」或密钥变了 | 电视上撤销授权后重连；`adb kill-server` |
| `offline` | adbd 卡住 | `adb disconnect` → `adb connect`；必要时重启电视 |
| `device not found`（刚 connect 成功又消失） | adb server 被重启（多个终端各自起了 daemon） | 固定用一个 adb，或所有命令串在一条里执行 |
| 能 ping 通但连不上 5555 | 端口没开 / 防火墙 | `adb shell netstat -ln \| grep 5555` 确认监听 |

> 小坑：Windows 上如果每条命令都在新的 shell 里跑，`adb connect` 建立的是**当前 adb server**
> 的连接状态，server 一重启就丢了。要么保持同一个终端，要么把 `connect` 和后续命令写在同一条命令里。
