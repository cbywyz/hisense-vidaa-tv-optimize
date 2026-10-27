# 04 · 性能调优

## 1. 先看清瓶颈：933MB 内存

```bash
adb shell cat /proc/meminfo | head -5
adb shell free -m
adb shell cat /proc/swaps
```

本机优化前的状态：

```text
MemTotal:   933540 kB     ← 厂商标称 1GB，实际可用 911MB
MemFree:     约 60MB      ← 只剩 6%
Swap:        42MB 已用    ← zram 已经在疯狂换页
```

`MemFree` 长期低于 80MB 时，Android 会频繁杀后台、桌面重绘、遥控器响应变慢——
这就是「卡」的直接原因，不是 CPU 不行（4×A53 1.3GHz 跑 720p 桌面绰绰有余）。

看谁在吃内存：

```bash
adb shell dumpsys meminfo | head -40
adb shell top -n 1 -b -o PID,USER,RSIZE,NAME | head -20
```

本机的大户：广告服务双进程约 200MB、聚好看约 97MB、语音助手 5 进程约 76MB。

## 2. 动画减半（体感提升最快，零风险）

```bash
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5
```

Android 9 上 0.5 倍不会显得生硬，但列表滚动、应用切换、返回桌面的等待感明显减少。
不喜欢就改回 `1.0`。

## 3. 停用广告/遥测/原桌面

见 [02-debloat.md](02-debloat.md)。这是内存收益最大的一块，本机停用后空出约 50MB。

## 4. AOT 预编译（减少 JIT 抖动）

Android 默认对第三方应用用 `quickening`/解释执行，冷启动时现编译，1GB 机器上很容易卡一下。
对常用应用做一次 `speed` 模式 AOT：

```bash
for p in app.orchard.tv com.ktcp.video com.ju.miguvideoTV.cmcc \
         com.dangbeimarket com.dangbei.zhushou \
         com.android.tv.settings com.android.settings; do
  echo "== $p"
  adb shell cmd package compile -m speed -f "$p"
done
```

- `-m speed`：全量编译成机器码，启动最快，占用存储略增；
- `-f`：强制重编译（已编译过也会重来）；
- 单个应用几十秒，7 个大约 3–5 分钟，期间电视会有点卡，正常；
- 应用更新后会退回默认编译，需要时重跑即可。

验证：

```bash
adb shell dumpsys package app.orchard.tv | grep -i -E "compiler|status"
# 或
adb shell cmd package dump app.orchard.tv | grep -i compilation
```

> 别对所有系统应用无差别 `speed` 编译——收益小、占空间，还可能拖慢 OTA。

## 5. 限制后台常驻（appops）

```bash
for p in com.multiscreen.airplay com.android.wechathci \
         com.sohu.inputmethod.sogou.tv com.android.gallery3d; do
  adb shell cmd appops set "$p" RUN_IN_BACKGROUND ignore
done
```

这些应用前台功能不受影响，只是不在后台空转。恢复：

```bash
adb shell cmd appops set <包名> RUN_IN_BACKGROUND allow
```

## 6. 关掉不必要的系统服务

本机还停用了：

```bash
adb shell pm disable-user --user 0 com.jamdeo.tv.fte          # 首次开机引导
adb shell pm disable-user --user 0 com.jamdeo.screensaver    # 原厂屏保
adb shell pm disable-user --user 0 com.hisense.smartimages    # AI 识图，常驻 15MB
adb shell pm disable-user --user 0 com.hisense.horizontalassistantmenu  # 侧栏
```

## 7. 实测结果

| 指标 | 优化前 | 优化后 |
| --- | --- | --- |
| `MemFree`（开机闲置） | 59–60MB | **112MB**（峰值 180MB） |
| `SwapUsed` | 42MB | **2MB** |
| 常驻第三方进程 | 15 个 | **7–8 个** |
| 开机广告 | 15 秒 | 无 |
| Home 键响应 | 1–3 秒，偶尔无响应 | 即时 |
| 设置/应用管理打开 | 明显停顿 | 流畅 |

> 播放 4K/高码率视频时内存仍会吃紧，这是硬件上限（933MB + 720p 屏），
> 软件层面已经榨不出更多。真要再快，只能减少同时运行的应用。

## 8. 日常维护建议

```bash
# 每周看一眼内存与后台
adb shell free -m
adb shell dumpsys meminfo | head -20

# 发现某个包又复活（OTA 后常见）
adb shell pm list packages -d
```

- 不要把电视的「节能待机 / 快速开机」打开——那会让应用在待机时继续驻留，越用越卡；
- 不要装太多 TV 版应用，1GB 机器同时开 3 个视频 App 必卡；
- 定期重启（一周一次）比任何清理软件都有效。
