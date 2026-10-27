#!/bin/sh
# 公共函数：定位 adb、连接电视、检查包是否存在
# 用法（在其它脚本里）：
#   . "$(dirname "$0")/_common.sh"
#   resolve_adb
#   connect_tv "$TV_HOST"

resolve_adb() {
  if [ -n "${ADB:-}" ] && [ -x "$ADB" ]; then
    return 0
  fi
  if command -v adb >/dev/null 2>&1; then
    ADB=adb
    return 0
  fi
  for c in \
    "/c/Users/Administrator/.workbuddy/platform-tools/platform-tools/adb.exe" \
    "$HOME/AppData/Local/Android/Sdk/platform-tools/adb.exe" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "$HOME/Android/Sdk/platform-tools/adb" \
    "/usr/lib/android-sdk/platform-tools/adb"
  do
    if [ -x "$c" ]; then
      ADB="$c"
      return 0
    fi
  done
  echo "[错误] 找不到 adb。请安装 platform-tools，或用环境变量指定：" >&2
  echo "       ADB=/path/to/adb sh $0 ..." >&2
  return 1
}

connect_tv() {
  host="$1"
  port="${2:-5555}"
  DEV="$host:$port"
  "$ADB" connect "$DEV" >/dev/null 2>&1
  state=$("$ADB" -s "$DEV" get-state 2>/dev/null | tr -d '\r')
  if [ "$state" != "device" ]; then
    echo "[错误] 连不上 $DEV（state=$state）" >&2
    echo "       1) 电视端开发者选项里 ADB / 网络调试是否打开" >&2
    echo "       2) 电视 IP 是否变了（建议路由器按 MAC 绑定静态 IP）" >&2
    echo "       3) 本机优先用 Wi-Fi 连，不要用网线（见 docs/01-adb.md）" >&2
    return 1
  fi
  echo "[OK] 已连接 $DEV"
}

tv() {
  "$ADB" -s "$DEV" shell "$@"
}

pkg_installed() {
  printf '%s\n' "$PKG_CACHE" | grep -qx "$1"
}

disable_pkg() {
  p="$1"
  if ! pkg_installed "$p"; then
    echo "  跳过 $p（本机没有这个包）"
    return 0
  fi
  out=$(tv "pm disable-user --user 0 $p" 2>&1 | tr -d '\r')
  case "$out" in
    *"new state: disabled"*) echo "  已停用 $p" ;;
    *) echo "  $p -> $out" ;;
  esac
}

enable_pkg() {
  p="$1"
  if ! pkg_installed "$p"; then
    echo "  跳过 $p（本机没有这个包）"
    return 0
  fi
  out=$(tv "pm enable $p" 2>&1 | tr -d '\r')
  case "$out" in
    *"new state: enabled"*) echo "  已恢复 $p" ;;
    *) echo "  $p -> $out" ;;
  esac
}

load_packages() {
  PKG_CACHE=$(tv "pm list packages" 2>/dev/null | tr -d '\r' | sed 's/^package://')
}
