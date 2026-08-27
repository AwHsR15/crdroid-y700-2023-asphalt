#!/bin/bash
# 从 lolipuru 的 LineageOS 23.2 成品包提取 blobs(免设备、免 root)
SRC="$HOME/crdroid"
ZIP="/mnt/d/D区下载/lineage-23.2-20260505-UNOFFICIAL-asphalt.zip"

echo "源包: $ZIP"
ls -la "$ZIP" || { echo "找不到包"; exit 1; }
echo

cd "$SRC/device/lenovo/asphalt" || exit 1
PYTHONPATH="$SRC/tools/extract-utils" python3 extract-files.py "$ZIP" 2>&1 | tail -50

echo
echo "=================== 结果 ==================="
for d in "$SRC/vendor/lenovo/asphalt" "$SRC/vendor/lenovo/sm8475-common"; do
  if [ -d "$d" ]; then
    echo "  $d : $(du -sh "$d" 2>/dev/null | cut -f1), $(find "$d" -type f 2>/dev/null | wc -l) 个文件"
  else
    echo "  缺失 $d"
  fi
done
[ -f "$SRC/vendor/lenovo/asphalt/asphalt-vendor.mk" ] && echo "  OK  asphalt-vendor.mk 已生成" || echo "  !!  asphalt-vendor.mk 仍缺"
echo "EXTRACT_DONE"
