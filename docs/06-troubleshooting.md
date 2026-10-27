# 06 · 故障处理

按「症状 → 原因 → 处理」组织，都是本机真实遇到过的。

---

## 1. 卸载应用一直卡在「正在卸载」页面

**症状**：点卸载后进度条一直转，等几分钟也不结束，以为没卸掉。

**原因**：不是卸载失败，是**内存不足导致系统 UI 不刷新**。
本机当时 `MemFree` 只剩约 60MB，`PackageInstaller` 已经完成删除，但进度页的重绘被系统杀掉了。
日志里能看到：

```text
Force stopping com.trim.tv: deletePackageX
```

包已经被删，只是界面停在那一帧。

**处理**：

```bash
# 确认到底卸没卸
adb shell pm list packages | grep <包名关键字>
# 没有输出 = 已经删掉了

# 界面卡住就回桌面 / 重启
adb shell input keyevent KEYCODE_HOME
adb reboot
```

**预防**：卸载前先看 `free -m`，内存低于 80MB 时先重启电视再操作。

---

## 2. 换桌面后开机黑屏 / 没有桌面

**症状**：重启后卡在海信 logo 或黑屏，按遥控器没反应，但电视有背光。

**原因**：把原桌面停用了，同时新桌面没有成功设为默认 Home。

**处理**（ADB 还能连上的情况）：

```bash
adb connect 192.168.3.205:5555

# 1) 先把原桌面救回来
adb shell pm enable com.jamdeo.tv.vod
adb shell cmd package set-home-activity \
  com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity

# 2) 或者直接把新桌面设为 Home
adb shell cmd package set-home-activity app.orchard.tv/.MainActivity

# 3) 强制回桌面
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

**ADB 也连不上时**：电视断电重启，开机时**长按遥控器 Home 键**（部分机型是「设置」键），
有的固件会弹出「选择主屏幕应用」。都不行就恢复出厂（见第 8 节）。

> 教训：**先装好新桌面并确认能当 Home，再停用聚好看。**

---

## 3. 遥控器 Home 键没反应

**症状**：`adb shell input keyevent 3` 执行了，但界面没回桌面。

**原因**：海信/部分国产 TV 固件**屏蔽了 input 注入的 Home 键**，
`keyevent` 只对应用内的导航有效，回桌面必须走实体遥控器。

**处理**：用实体遥控器按 Home 验证；脚本里不要依赖 `input keyevent 3` 判断桌面是否正常。

---

## 4. 信号源键按了没反应 / 面板出不来

见 [05-signal-source.md](05-signal-source.md) 第 6 节。九成是 `com.jamdeo.tv.vod` 被停用了。

```bash
adb shell pm enable com.jamdeo.tv.vod
adb shell am start -n com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity
```

---

## 5. 遥控器突然失灵（尤其是蓝牙遥控器）

**原因**：把 `com.android.bluetooth` 停用了。

```bash
adb shell pm enable com.android.bluetooth
adb reboot
```

> 本机是红外遥控器，停用蓝牙无影响；**蓝牙遥控器的机型不要停这个包**。

---

## 6. 电视越用越卡

按收益从高到低：

1. **重启**（最简单，清掉泄漏的内存）；
2. 看内存：`adb shell free -m`，`MemFree < 80MB` 就会卡；
3. 看后台大户：`adb shell top -n 1 -b -o PID,USER,RSIZE,NAME | head -20`；
4. 确认广告服务没复活：`adb shell ps -A | grep -i hisense`；
5. 把所有「快速开机 / 节能待机」关掉——待机时应用还在跑，越待越卡；
6. 减少同时运行的应用（933MB 内存同时开 3 个视频 App 必卡）。

---

## 7. ADB 连不上

先看 [01-adb.md](01-adb.md) 第 5 节的速查表。最常见的三个：

```bash
# 1) 端口没监听
adb shell getprop init.svc.adbd     # 应为 running

# 2) 未授权
adb kill-server && adb start-server
# 电视上出现弹窗要选「允许」

# 3) 有线连不上 → 换无线
# 本机实测：网线怎么都不行，Wi-Fi 一次就通
```

---

## 8. 最后的兜底：恢复出厂

如果电视黑屏、ADB 也连不上、遥控器也进不去设置：

1. 拔掉电源；
2. 按住电视机身上的**电源键/音量减键**（不同机型不同，海信多为机身「电源」+「音量-」）；
3. 插上电源，保持按住 10–15 秒，直到出现恢复界面；
4. 选「清除数据 / 恢复出厂设置」。

恢复出厂会清掉所有安装的应用和本项目的所有改动，回到开箱状态。
**这是最后手段**，能跑 `restore.sh` 就别用它。

---

## 9. 一键还原（推荐优先使用）

```bash
sh scripts/restore.sh 192.168.3.205
```

它会：

- 恢复所有被 `disable-user` 的包；
- 复位 appops 后台限制；
- 动画倍率改回 1.0；
- **不会**改默认 Home，也**不会**卸载 Aerial（这两项按需手动处理）。

改完后重启一次，让系统重新注册服务：

```bash
adb reboot
```
