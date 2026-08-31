#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  刷机前查一下你的 Y700 2023 是哪个硬件区域(PRC / ROW / NEC)
#  刷之前跑这个,能避免刷完开不了机。
#
#  用法:  bash check_region.sh
#  需要:  平板处于开机状态、已开 USB 调试、adb 能连上
# ─────────────────────────────────────────────────────────────────────
set -u
ADB="${ADB:-adb}"

say() { printf '%s\n' "$*"; }
hr()  { printf '%s\n' "────────────────────────────────────────────────────────"; }

hr; say "  Y700 2023 (TB320FC) 硬件区域检查"; hr; say

state="$("$ADB" get-state 2>/dev/null || true)"
if [ "$state" != "device" ]; then
  say "✗ adb 没连上设备(当前状态: ${state:-无})"
  say "  请开机进系统、打开 USB 调试、用数据线连电脑后重试。"
  exit 1
fi

dev="$("$ADB" shell getprop ro.product.device 2>/dev/null | tr -d '\r\n')"
if [ "$dev" != "asphalt" ]; then
  say "✗ 这台不是 Y700 2023(ro.product.device = ${dev:-未知})"
  exit 1
fi

disp="$("$ADB" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r\n')"
fp="$("$ADB" shell getprop ro.build.fingerprint 2>/dev/null | tr -d '\r\n')"
vfp="$("$ADB" shell getprop ro.vendor.build.fingerprint 2>/dev/null | tr -d '\r\n')"
bfp="$("$ADB" shell getprop ro.bootimage.build.fingerprint 2>/dev/null | tr -d '\r\n')"

say "当前系统标识"
say "  ro.build.display.id            : ${disp:-(空)}"
say "  ro.build.fingerprint           : ${fp:-(空)}"
say "  ro.vendor.build.fingerprint    : ${vfp:-(空)}"
say "  ro.bootimage.build.fingerprint : ${bfp:-(空)}"
say

# vendor 指纹最能代表底层固件的来源区域
probe="$vfp$bfp$fp$disp"
region="未知"
case "$probe" in
  *_CN_*|*_CN:*|*TB320FC_CN*)   region="CN / PRC(中国大陆)";;
  *_ROW_*|*_ROW:*|*TB320FC_ROW*) region="ROW(全球)";;
  *_NEC_*|*_NEC:*|*TB320FC_NEC*) region="NEC(日本)";;
esac

hr
say "  推测的固件区域: $region"
hr
say

case "$region" in
  ROW*|NEC*)
    say "✓ 这台在跑 ROW / NEC 系固件。"
    say "  本仓库的 crDroid 包就是基于 ROW 固件(ZUI 17.0.339 ROW)编的,"
    say "  可以直接刷。"
    ;;
  CN*)
    say "⚠ 这台在跑 CN(国行)固件,需要特别注意!"
    say
    say "  联想从 2024 年 4 月起给这台设备加了区域锁:固件会去一个"
    say "  持久分区里找 'PRC' 区域码,找不到就【永久写入】PRC。"
    say "  一旦写上 PRC,再刷 ROW / 全球系固件就会出现红字:"
    say
    say "    The current system is not compatible with hardware."
    say "    The device will power off automatically."
    say
    say "  本仓库的包是 ROW 基线,PRC 机器直接刷【很可能开不了机】。"
    say "  请先按 XDA 的区域转换教程把设备转成 ROW,再回来刷:"
    say "    https://xdaforums.com/t/y700-2023-gen_2-regional-rom-flashing-guide.4685115/"
    ;;
  *)
    say "? 没能从属性里判断出区域。"
    say "  如果这台已经在跑第三方 ROM(LineageOS / crDroid / AviumUI),"
    say "  属性里的指纹会是 ROM 作者写死的,不代表你的硬件区域。"
    say
    say "  这种情况下的判断依据:"
    say "    · 这台以前刷过 ROW / 全球固件并能正常开机  → 硬件区多半是 ROW"
    say "    · 这台是 2024 年 4 月以后买的国行机           → 多半是 PRC"
    say "    · 从没刷过非国行固件的国行机                  → 按 PRC 处理最稳妥"
    ;;
esac

say
say "补充说明:"
say "  · 2024 年 4 月之前出厂的机器通常没有写区域码,刷什么都行"
say "  · 首次成功启动 ROW 固件后,设备会被写上 ROW,之后就锁定 ROW/NEC 了"
say "  · 这个脚本只做提示,不写入任何东西"
