#!/bin/sh
# 只读体检：不修改电视任何设置
#
# 用法:
#   sh audit.sh [电视IP]            # 打印到屏幕
#   sh audit.sh 192.168.3.205 > report.txt
#
# 输出内容: 设备信息 / 网络 / ADB / 内存 / 已停用包 / 默认桌面 / 三方应用 / 进程

set -u
TV_HOST="${1:-192.168.3.205}"
DIR=$(dirname "$0")
. "$DIR/_common.sh"

resolve_adb || exit 1
connect_tv "$TV_HOST" || exit 1

echo "=============================================="
echo " 海信 VIDAA 电视体检报告"
echo " 时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo " 设备: $DEV"
echo "=============================================="

echo ""
echo "--- 设备信息 ---"
tv 'echo "型号: $(getprop ro.product.model)"; \
    echo "品牌: $(getprop ro.product.brand)"; \
    echo "系统: Android $(getprop ro.build.version.release) / SDK $(getprop ro.build.version.sdk)"; \
    echo "硬件: $(getprop ro.boot.hardware)"; \
    echo "固件: $(getprop ro.build.display.id)"'
tv "wm size; wm density"

echo ""
echo "--- 网络接口 ---"
tv "ip -o addr show 2>/dev/null | awk '{print \$2, \$4}'"

echo ""
echo "--- ADB 状态 ---"
tv 'echo "adbd: $(getprop init.svc.adbd)"; \
    echo "persist.adb.tcp.port: $(getprop persist.adb.tcp.port)"; \
    echo "ro.adb.secure: $(getprop ro.adb.secure)"'
tv "netstat -ln 2>/dev/null | grep 5555"

echo ""
echo "--- 内存 ---"
tv "cat /proc/meminfo | head -3"
tv "cat /proc/swaps"
tv "free -m 2>/dev/null"

echo ""
echo "--- 默认桌面 ---"
tv "cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN | tail -1"

echo ""
echo "--- 动画倍率 ---"
tv 'for k in window_animation_scale transition_animation_scale animator_duration_scale; do \
      echo "$k = $(settings get global $k)"; done'

echo ""
echo "--- 已停用的包 ---"
tv "pm list packages -d"

echo ""
echo "--- 第三方应用 ---"
tv "pm list packages -3"

echo ""
echo "--- 内存占用前 15 的进程 ---"
tv "top -n 1 -b -o PID,USER,RSIZE,NAME 2>/dev/null | head -18"

echo ""
echo "--- TV Input 注册情况（信号源相关） ---"
tv "dumpsys tv_input 2>/dev/null | head -20"

echo ""
echo "=============================================="
echo " 提示: 本报告只读。优化请用 debloat.sh / optimize.sh"
echo "=============================================="
