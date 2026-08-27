#!/bin/bash
# 同步 crDroid 16.0 源码 + asphalt 设备树
# 注意:不加 --fail-fast(上次 AviumUI 就是栽在这上面,会留下"git索引空+工作区半残"的仓库)
set -e
SRC="$HOME/crdroid"
export PATH="$HOME/bin:$PATH"

echo "=================== 环境 ==================="
df -h "$HOME" | tail -1

mkdir -p "$HOME/bin"
if [ ! -x "$HOME/bin/repo" ]; then
  curl -s https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
  chmod a+x "$HOME/bin/repo"
  echo "  已安装 repo"
fi

git config --global user.name  "AwHsR15"
git config --global user.email "hxw2826348144@gmail.com"
git config --global color.ui true
git config --global --add safe.directory '*'
git config --global http.postBuffer 524288000
git config --global core.compression 0

echo
echo "=================== repo init (crDroid 16.0) ==================="
mkdir -p "$SRC" && cd "$SRC"
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --depth=1

echo
echo "=================== 放入设备树清单 ==================="
mkdir -p .repo/local_manifests
cp /mnt/d/Y700/crdroid/local_manifest.xml .repo/local_manifests/
echo "  ok"

echo
echo "=================== 开始同步 ==================="
date
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
date

echo
echo "=================== 结果 ==================="
du -sh "$SRC"
df -h "$HOME" | tail -1
for d in build/make frameworks/base vendor/lineage device/lenovo/asphalt device/lenovo/sm8475-common kernel/lenovo/sm8475; do
  [ -d "$SRC/$d" ] && echo "  OK      $d" || echo "  缺失    $d"
done
echo "SYNC_DONE"
