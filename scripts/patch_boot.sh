#!/bin/bash
# 在 WSL(x86_64)上给 arm64 的 boot.img 打 Magisk 补丁
# magiskboot 用 x86_64 版(在这台机器上跑),植入 ramdisk 的用 arm64 版(在平板上跑)
set -e
W=/tmp/mgkpatch
mkdir -p "$W"
cp -f /mnt/d/Y700/crdroid/magisk/wsl_patch/* "$W"/
cp -f /mnt/d/Y700/crdroid/release/boot.img "$W"/boot.img
cd "$W"
chmod 755 magiskboot magiskinit magiskpolicy magisk busybox boot_patch.sh

echo "=== 打补丁 ==="
KEEPVERITY=true KEEPFORCEENCRYPT=true sh boot_patch.sh boot.img 2>&1 | tail -25

echo
echo "=== 校验产物 ==="
[ -f new-boot.img ] || { echo "未生成 new-boot.img"; exit 1; }
ls -la new-boot.img
./magiskboot unpack new-boot.img >/dev/null 2>&1
echo "--- ramdisk 内容 ---"
./magiskboot cpio ramdisk.cpio 'ls' 2>/dev/null | head -15
echo "--- 关键项 ---"
./magiskboot cpio ramdisk.cpio 'exists overlay.d/sbin/magisk.xz' && echo "  OK  magisk.xz 已植入" || echo "  !!  magisk.xz 缺失"
./magiskboot cpio ramdisk.cpio 'exists .backup/.magisk'        && echo "  OK  备份记录已建立" || echo "  !!  备份记录缺失"

cp -f new-boot.img /mnt/d/Y700/crdroid/release/boot_magisk.img
echo
echo "=== 已输出 ==="
sha256sum /mnt/d/Y700/crdroid/release/boot_magisk.img
