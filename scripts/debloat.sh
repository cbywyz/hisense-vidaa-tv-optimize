#!/bin/sh
# 分阶段停用海信 VIDAA 的广告 / 遥测 / OTA / 屏保等包
#
# 用法:
#   sh debloat.sh [电视IP] [stage]
#   stage = 1 | 2 | 3 | 4 | 5 | all     （默认 1）
#
# 阶段说明:
#   1  广告 / 遥测 / 推广（10 项，收益最大，风险最低）
#   2  更新 / 屏保 / 引导 / 识图 / 侧栏（5 项）
#   3  原桌面聚好看（97MB）—— 停用后「信号源」键会失效！
#      只有在你完全不用 HDMI、且已确认新桌面能当 Home 时才执行。
#   4  桌面垃圾图标：通讯录、日历、时钟、音乐、浏览器、相机、微信电视等（14 项）
#   5  语音助手全家桶 + 海信会员中心（8 项，约省 350MB，代价：遥控器语音键失效）
#
# 注意: 全部使用 pm disable-user，可随时用 restore.sh 恢复。

set -u
TV_HOST="${1:-192.168.3.205}"
STAGE="${2:-1}"
DIR=$(dirname "$0")
. "$DIR/_common.sh"

resolve_adb || exit 1
connect_tv "$TV_HOST" || exit 1
load_packages

STAGE1="
com.hisense.service.ad
com.hisense.business.ad
com.hisense.cloudfalcon
com.hisense.service.message
com.hisense.hitv.das
com.hisense.logupload
com.hisense.hotelmenu
com.hisense.autotest
com.hisense.hitv.payment
com.hisense.startupimage
"

STAGE2="
com.jamdeo.updateservice
com.jamdeo.screensaver
com.jamdeo.tv.fte
com.hisense.smartimages
com.hisense.horizontalassistantmenu
"

STAGE3="
com.jamdeo.tv.vod
"

# 第六轮：桌面垃圾图标（停用后图标消失，进程不再启动）
STAGE4="
com.android.contacts
com.android.calendar
com.android.wechathci
com.android.browser
com.android.camera2
com.android.deskclock
com.android.music
com.android.gallery3d
com.android.soundrecorder
com.android.printspooler
com.cvte.tv.at
com.hisense.usbupgrade
com.hisense.infaredcodesettings
fusion.android.tv.demo
"

# 第六轮：语音助手 + 会员中心（约省 350MB，代价：遥控器语音键失效）
STAGE5="
com.hisense.vidaaassistant
com.keylab.speech.core.vidaa
com.keylab.speech.view.vidaa
com.hisense.tv.aivirtualassistant
com.hisense.voicecontrol
com.hisense.msvoicetome
com.hispeech.ai.area
com.hisense.hitv.hicloud.account
"

run_stage() {
  n="$1"
  list="$2"
  title="$3"
  echo ""
  echo "=== 阶段 $n：$title ==="
  for p in $list; do
    disable_pkg "$p"
  done
}

case "$STAGE" in
  1) run_stage 1 "$STAGE1" "广告 / 遥测 / 推广" ;;
  2) run_stage 2 "$STAGE2" "更新 / 屏保 / 引导 / 识图 / 侧栏" ;;
  3)
    echo ""
    echo "!!! 警告：即将停用原桌面 com.jamdeo.tv.vod"
    echo "!!! 停用后遥控器「信号源」键会失效（海信没有标准 TvInputService）"
    echo "!!! 确认已安装并设为默认 Home 的第三方桌面，例如 app.orchard.tv"
    printf "继续？输入 yes 确认："
    read -r ans
    if [ "$ans" != "yes" ]; then
      echo "已取消。"
      exit 0
    fi
    run_stage 3 "$STAGE3" "原桌面（信号源面板宿主）"
    ;;
  all)
    run_stage 1 "$STAGE1" "广告 / 遥测 / 推广"
    run_stage 2 "$STAGE2" "更新 / 屏保 / 引导 / 识图 / 侧栏"
    echo ""
    echo "阶段 1、2 已完成。以下阶段需单独执行并按需确认："
    echo "  sh $0 $TV_HOST 3   # 停用聚好看（会让信号源键失效）"
    echo "  sh $0 $TV_HOST 4   # 清理桌面垃圾图标（安全）"
    echo "  sh $0 $TV_HOST 5   # 停用语音助手+会员中心（会失去语音键）"
    ;;
  4) run_stage 4 "$STAGE4" "桌面垃圾图标（通讯录/日历/时钟/微信电视等）" ;;
  5)
    echo ""
    echo "!!! 阶段 5 会停用语音助手全家桶与海信会员中心"
    echo "!!! 代价：遥控器语音键失效、语音搜片不可用；第三方 App 会员不受影响"
    printf "继续？输入 yes 确认："
    read -r ans
    if [ "$ans" != "yes" ]; then
      echo "已取消。"
      exit 0
    fi
    run_stage 5 "$STAGE5" "语音助手 + 会员中心"
    ;;
  *)
    echo "用法: sh $0 [电视IP] [1|2|3|all]"
    exit 1
    ;;
esac

echo ""
echo "=== 完成，建议重启后验证 ==="
echo "  $ADB -s $DEV reboot"
echo "  $ADB -s $DEV shell pm list packages -d"
echo ""
echo "提示: 蓝牙遥控器机型不要停用 com.android.bluetooth，本脚本没有包含它。"
