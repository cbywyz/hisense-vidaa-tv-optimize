#!/bin/sh
# 一键还原：恢复所有被停用的包 + 复位后台限制 + 动画倍率改回 1.0
#
# 用法:
#   sh restore.sh [电视IP]
#
# 不会做的事:
#   - 不卸载任何应用（包括 Aerial）
#   - 不改默认 Home（需要时手动执行文末命令）
#   - 不撤销 AOT 编译（重装/更新应用会自动回退）

set -u
TV_HOST="${1:-192.168.3.205}"
DIR=$(dirname "$0")
. "$DIR/_common.sh"

resolve_adb || exit 1
connect_tv "$TV_HOST" || exit 1
load_packages

echo ""
echo "=== 1. 恢复广告 / 遥测 / 推广包 ==="
for p in \
  com.hisense.service.ad \
  com.hisense.business.ad \
  com.hisense.cloudfalcon \
  com.hisense.service.message \
  com.hisense.hitv.das \
  com.hisense.logupload \
  com.hisense.hotelmenu \
  com.hisense.autotest \
  com.hisense.hitv.payment \
  com.hisense.startupimage
do
  enable_pkg "$p"
done

echo ""
echo "=== 2. 恢复更新 / 屏保 / 引导 / 识图 / 侧栏 ==="
for p in \
  com.jamdeo.updateservice \
  com.jamdeo.screensaver \
  com.jamdeo.tv.fte \
  com.hisense.smartimages \
  com.hisense.horizontalassistantmenu
do
  enable_pkg "$p"
done

echo ""
echo "=== 3. 恢复原桌面聚好看（信号源面板宿主） ==="
enable_pkg "com.jamdeo.tv.vod"

echo ""
echo "=== 4. 恢复蓝牙（如果是蓝牙遥控器） ==="
enable_pkg "com.android.bluetooth"

echo ""
echo "=== 5. 复位后台限制 ==="
for p in \
  com.multiscreen.airplay \
  com.android.wechathci \
  com.sohu.inputmethod.sogou.tv \
  com.android.gallery3d
do
  if pkg_installed "$p"; then
    tv "cmd appops set $p RUN_IN_BACKGROUND allow" >/dev/null 2>&1
    echo "  已恢复 $p"
  fi
done

echo ""
echo "=== 6. 动画倍率改回 1.0 ==="
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  tv "settings put global $k 1.0"
  echo "  $k = $(tv "settings get global $k" | tr -d '\r')"
done

echo ""
echo "=== 完成 ==="
echo "如需把默认桌面也还给聚好看："
echo "  $ADB -s $DEV shell cmd package set-home-activity com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity"
echo ""
echo "建议重启一次："
echo "  $ADB -s $DEV reboot"
