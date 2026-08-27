#!/bin/bash
# crDroid 16.0 for asphalt (Lenovo Legion Y700 2023 / TB320FC)
# 本脚本由每 10 分钟触发一次的计划任务反复调用:
#   已在编译 -> 立刻退出;被 SIGHUP 打断 -> 下一次触发自动接着编(ninja 增量)
SRC="$HOME/crdroid"
LOCK=/tmp/crdroid_build.lock

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "[$(date +%H:%M:%S)] 已有编译在跑,本次触发跳过" >> /home/build_ticks.log
  exit 0
fi
if pgrep -f 'ninja|soong_ui|ckati' >/dev/null 2>&1; then
  echo "[$(date +%H:%M:%S)] 检测到编译进程,本次触发跳过" >> /home/build_ticks.log
  exit 0
fi
if grep -q BUILD_DONE /home/build.log 2>/dev/null; then
  echo "[$(date +%H:%M:%S)] 已完成,不再重编" >> /home/build_ticks.log
  exit 0
fi

# 忽略挂断信号,子进程一并继承
trap '' HUP

cd "$SRC" || exit 1
export ALLOW_MISSING_DEPENDENCIES=true
export NINJA_ARGS="-k 0"

{
  echo "=================== 开工/续编 ==================="
  date
  free -g | head -2
  df -h "$SRC" | tail -1
  echo

  source build/envsetup.sh || exit 1
  breakfast asphalt || { echo "BREAKFAST_FAILED"; exit 1; }

  echo
  echo "=================== mka bacon ==================="
  date
  mka bacon -j"$(nproc --all)"
  RC=$?
  date

  echo
  echo "=================== 结果 (rc=$RC) ==================="
  df -h "$SRC" | tail -1
  ls -la "$SRC"/out/target/product/asphalt/*.zip 2>/dev/null
  # 只有真正产出 zip 才算完成,否则留给下一次触发继续
  if ls "$SRC"/out/target/product/asphalt/*.zip >/dev/null 2>&1; then
    echo "BUILD_DONE rc=$RC"
  else
    echo "本轮未产出 zip(rc=$RC),等待下次触发续编"
  fi
} >> /home/build.log 2>&1
