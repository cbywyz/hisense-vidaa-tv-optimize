#!/bin/sh
# 性能调优：动画减半 + 后台限制 + AOT 预编译
#
# 用法:
#   sh optimize.sh [电视IP] [--no-aot]
#
# 说明:
#   - 动画倍率 1.0 -> 0.5，随时可改回
#   - appops 只限制后台，不影响前台功能
#   - AOT 用 speed 模式重编译常用应用，耗时 3-5 分钟，期间电视会卡

set -u
TV_HOST="${1:-192.168.3.205}"
NO_AOT=0
for a in "$@"; do
  [ "$a" = "--no-aot" ] && NO_AOT=1
done

DIR=$(dirname "$0")
. "$DIR/_common.sh"

resolve_adb || exit 1
connect_tv "$TV_HOST" || exit 1
load_packages

echo ""
echo "=== 1. 动画倍率 0.5 ==="
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  tv "settings put global $k 0.5"
  echo "  $k = $(tv "settings get global $k" | tr -d '\r')"
done

echo ""
echo "=== 2. 限制后台常驻（前台功能保留） ==="
for p in \
  com.multiscreen.airplay \
  com.android.wechathci \
  com.sohu.inputmethod.sogou.tv \
  com.android.gallery3d
do
  if pkg_installed "$p"; then
    tv "cmd appops set $p RUN_IN_BACKGROUND ignore" >/dev/null 2>&1
    echo "  已限制 $p"
  else
    echo "  跳过 $p（本机没有这个包）"
  fi
done

if [ "$NO_AOT" = "1" ]; then
  echo ""
  echo "=== 3. AOT 预编译：已跳过（--no-aot） ==="
else
  echo ""
  echo "=== 3. AOT 预编译（speed 模式，请耐心等待） ==="
  for p in \
    app.orchard.tv \
    com.ktcp.video \
    com.ju.miguvideoTV.cmcc \
    com.dangbeimarket \
    com.dangbei.zhushou \
    com.android.tv.settings \
    com.android.settings
  do
    if pkg_installed "$p"; then
      echo "  编译 $p ..."
      tv "cmd package compile -m speed -f $p" >/dev/null 2>&1 && echo "    完成" || echo "    跳过（失败或不支持）"
    else
      echo "  跳过 $p（本机没有这个包）"
    fi
  done
fi

echo ""
echo "=== 当前内存 ==="
tv "cat /proc/meminfo | head -3"
tv "cat /proc/swaps"

echo ""
echo "=== 完成。建议重启一次让改动生效 ==="
echo "  $ADB -s $DEV reboot"
