# crDroid 16.0 for Lenovo Legion Y700 (2023) / TB320FC ("asphalt")

## 中文说明

这是给联想拯救者 Y700 2023 平板(TB320FC,设备代号 `asphalt`)自己编译的
**非官方 crDroid 16.0(v12.11)** 系统,基于 Android 16。
[crDroid](https://crdroid.net/) 官方支持设备列表里没有这台平板,这是完全从源码
自己编出来的社区构建,**不代表 crDroid 团队,也没有得到他们的官方认可或支持**。

同一台设备的 AviumUI 构建在另一个仓库:
[aviumui-y700-2023-asphalt](https://github.com/AwHsR15/aviumui-y700-2023-asphalt)。

### 这个 ROM 有什么

- **系统**:crDroid 16.0,版本号 `v12.11-20260825`,Android 16(SDK 36.1)
- **安全补丁**:2026-08-01
- **小窗 / 桌面模式开箱可用** —— 这是这个包相对该设备其它 ROM 最实际的改善,
  原因见下面「[关于小窗和桌面模式](#关于小窗和桌面模式)」一节,值得一读
- **纯净版,不含 Google 服务** —— 需要自己刷 GApps,方法见下面
  「[装 Google 服务](#装-google-服务)」,已经把版本和校验和都写清楚了
- **设备树和内核完全来自** [**lolipuru**](https://github.com/lolipuru) 的
  LineageOS 23.2 工作成果。这个仓库本身只是一份 repo manifest 加几个编译脚本,
  负责把源码正确地拼到一起编出来。另外,这台设备最早的社区适配 / 内核与 HAL
  源码这块,按流传的 LineageOS 23.2 非官方构建帖里的致谢,还要感谢
  **mickey36736**(设备适配)和 **soralis0912**(内核与 HAL 源码)——
  **这台设备能跑起来,是这几位一起的功劳**,这里不敢掠美。

### 为什么 crDroid 16.0 能直接用 LineageOS 的设备树

因为两者的基线是同一套:crDroid `16.0` 分支的 manifest 里写的是
`<default revision="refs/heads/lineage-23.2">` 加 `android-16.0.0_r4`,
和 lolipuru 设备树的 `lineage-23.2` 分支**完全对得上**。

而且 crDroid 把自己的 vendor 挂在 `vendor/lineage` 路径下,`breakfast` 执行的
仍然是 `lunch lineage_$target-$aosp_target_release-$variant`,所以设备树里的
`lineage_asphalt.mk` **一个字都不用改**就能直接用。

### 下载

去 [Releases](../../releases) 页面下载:

| 文件 | 用途 |
|---|---|
| `crDroidAndroid-16.0-20260825-asphalt-v12.11.zip` | 刷机包本体(1.23 GB) |
| `recovery.img` | 刷机第一步要用 |
| `boot.img` | 干净的 boot(想去掉 root 时刷回来) |
| `boot_magisk.img` | 已预先打好 Magisk 补丁的 boot(要 root 就刷这个) |
| `dtbo.img` / `vendor_boot.img` | 一般用不到,救砖时备用 |
| `SHA256SUMS.txt` | 校验和 |

这次刷机包只有 1.23 GB,**没超过 GitHub 单文件 2GB 上限,不用像 AviumUI 那样
先合并分卷**,下下来直接就能用。

刷之前请务必校验一下,确保传输过程中文件没损坏:

```bash
# Linux / WSL
sha256sum -c SHA256SUMS.txt
```

```powershell
# Windows PowerShell
Get-FileHash crDroidAndroid-16.0-20260825-asphalt-v12.11.zip -Algorithm SHA256
```

### 怎么刷

有两种方式,**推荐用一键脚本**,手动流程留在下面供参考和排查用。

这个包本身就是完整的系统,**不需要事先装过别的系统再"升级"过来** ——
不管你现在是联想原厂 ZUI,还是已经在跑 LineageOS / AviumUI,流程都一样:
先用 fastboot 刷一次这个包自带的 Recovery,再用那个 Recovery 去 sideload
整个包。

#### 刷机前必读

- **会清空平板上的所有数据**,重要东西先备份好
- **需要已解锁 Bootloader**(`fastboot flashing unlock`)
- 电量建议 50% 以上,全程插着 USB
- 准备一根**能传数据**的 USB 线(有些线只能充电)

#### 方式一:一键脚本(推荐)

下载仓库里的 [`flasher/`](flasher/) 整个文件夹,把刷机包 zip 和 `recovery.img`
放进去,然后右键 `一键刷机.bat` → 以管理员身份运行。

脚本会自动:

- 检查 adb / fastboot,**没有就从 Google 官方自动下载**(仓库里不附带这些
  二进制,它们属于 Android SDK Platform Tools,有自己的许可协议)
- **核对机型**,不是 `asphalt` 会直接拒绝往下走 —— 这条实测有效,曾经成功
  拦下过一台误插的三星手机
- 刷 Recovery → 重启到 Recovery → 引导你清数据 → sideload 刷入系统

脚本能自动识别 `crDroidAndroid-*.zip` 和 `AviumUI-*.zip` 两种包,同一份脚本
两个 ROM 通用。

#### 方式二:手动操作

```bash
# 1. 重启到 bootloader
adb reboot bootloader

# 2. 确认认到设备,且是这台平板
fastboot devices
fastboot getvar product        # 应该显示 taro (SM8475 平台代号)
fastboot getvar unlocked       # 应该显示 yes

# 3. 双槽都刷入 Recovery
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img

# 4. 重启进 Recovery
fastboot reboot recovery
```

进入 Recovery 后,**在平板屏幕上**操作:

1. 如果 adb 显示 `unauthorized`,先进 **Advanced → Enable ADB**
   (crDroid 的 Recovery 默认不开 ADB),或者点屏幕上的授权弹窗
2. **Factory reset → Format data / factory reset** → 确认
   - 中途如果报 `/metadata` 挂载失败,**属正常,可以忽略**
3. **Apply update → Apply from ADB**,屏幕会停在等待推送的状态

然后在电脑上:

```bash
adb sideload crDroidAndroid-16.0-20260825-asphalt-v12.11.zip
```

推完显示 `Total xfer: 1.00x` 就是成功了。回主菜单 → **Reboot system now**。

首次开机要 5~10 分钟,耐心等,别以为卡住了就去拔线。

#### 为什么不用 fastboot 直接刷分区

因为 system / vendor / product 这些是**动态分区**,得进 fastbootd 才能刷,
而至少在部分 Windows 机器上,fastbootd 的 USB 设备(`VID_18D1&PID_D00D`)会被
系统错误地绑成 "Android ADB Interface",导致 fastboot 连不上 fastbootd。
**走 Recovery sideload 这条路完全绕开了这个坑**,也更省事。

### 装 Google 服务

这个包是**纯净版,不含 Google 服务**。要用 Play 商店的话,得另外刷一次 GApps。

推荐 LineageOS 官方推荐的 **MindTheGapps**:

| | |
|---|---|
| 文件 | `MindTheGapps-16.0.0-arm64-20260409_073023.zip`(487.6 MB) |
| 下载 | [GitHub Releases](https://github.com/MindTheGapps/16.0.0-arm64/releases/download/MindTheGapps-16.0.0-arm64-20260409_073023/MindTheGapps-16.0.0-arm64-20260409_073023.zip) |
| SHA256 | `a6ff8b8c31f7ccd0a9f2fd651fa4438a8e39a5f63b95be246ea1f98982af2c28` |

**这个仓库不转发 GApps 包本身,只给官方下载链接。** 原因和不附带 adb/fastboot
一样:里面是 Google 的闭源应用,有自己的分发条款,由上游自己分发最合适。
上面的链接是 MindTheGapps 官方的 GitHub Release,直接就能下。

⚠️ **刷 GApps 的顺序很重要**:

```
刷 ROM  →  刷 GApps  →  清数据  →  重启
```

**GApps 必须在系统首次开机之前刷。** 如果你已经开过机了,那刷完 GApps
**还要再清一次数据**,否则 Google 服务注册不上,会一直弹「Google Play 服务已停止」。

具体操作(接着上面刷完 ROM 的状态,还在 Recovery 里):

```bash
# 在 Recovery 里再次进入 Apply update → Apply from ADB,然后:
adb sideload MindTheGapps-16.0.0-arm64-20260409_073023.zip
```

推完回主菜单 → **Factory reset → Format data** → **Reboot system now**。

开机后走一遍开机向导,这次就能登 Google 账号了。

### 获取 Root(Magisk)

有两种做法。

#### 做法一:直接刷现成的(最省事)

Release 里的 `boot_magisk.img` 就是**这个 ROM 的 boot.img 预先打好 Magisk
补丁**的版本,直接刷:

```bash
adb reboot bootloader
fastboot flash boot_b boot_magisk.img     # 注意槽位!见下面说明
fastboot reboot
```

**槽位要选对。** 用 `fastboot getvar current-slot` 看当前在哪个槽,刷哪个。
刚用 sideload 刷完系统的话,槽位通常已经切换过了(比如从 `a` 切到 `b`)。
只刷当前槽的好处是:**另一个槽还留着旧系统,万一出问题能切回去救命**。

开机后装上 [Magisk 官方 APK](https://github.com/topjohnwu/Magisk/releases)
(本文用的是 v30.7),打开就能管理 root 了。

#### 做法二:自己打补丁(推荐,更放心)

刷别人给的 boot 镜像终究要信任对方。想自己来的话,用仓库里的
[`scripts/patch_boot.sh`](scripts/patch_boot.sh),**在 Linux / WSL 上就能完成,
不需要设备也不需要 root**:

它的思路是把 Magisk APK 里的两套二进制**按架构分开用**——

- `magiskboot` 用 **x86_64** 版(在你的电脑上运行)
- 塞进 ramdisk 的 `magisk` / `magiskinit` / `init-ld` / `stub.apk` 用
  **arm64** 版(将来在平板上运行)

这样在 x86 电脑上就能给 arm64 的 boot.img 打补丁。打完可以自己验证:

```bash
./magiskboot unpack new-boot.img
./magiskboot cpio ramdisk.cpio 'exists overlay.d/sbin/magisk.xz'   # 应该成功
./magiskboot cpio ramdisk.cpio 'exists .backup/.magisk'            # 应该成功
```

刷完之后验证 root 是否真的可用:

```bash
adb shell /debug_ramdisk/su -c id
# 期望输出:uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

注意 `su` **默认不在 PATH 里**,`adb shell su` 会报 `inaccessible or not found`,
这不代表 root 没成功 —— 用上面的全路径测试才准。

### 关于小窗和桌面模式

这一节值得单独讲,因为**这是换到 crDroid 最实际的好处**。

Android 16 的桌面窗口化由两个开关控制,AOSP 官方文档写得很明确:

> `config_isDesktopModeSupported` 是启用桌面窗口化的**顶层开关**。
> **如果它没启用,其他所有相关配置都会被忽略。**
>
> —— [AOSP: Support multi-window](https://source.android.com/docs/core/display/multi-window)

而 `asphalt` 的设备树 overlay(`overlay/FrameworkResAsphalt/res/values/config.xml`,
一共 166 行)里,**只设了从属的那个开关**:

```xml
<bool name="config_canInternalDisplayHostDesktops">true</bool>
```

**顶层开关没设,AOSP 默认是 `false`** —— 也就是说上面那句写了等于没写,
framework 根本不看它。这就是为什么在某些基于同一套设备树的 ROM 上,
横屏下小窗行为会不太对劲。

crDroid 的公共 overlay 里**已经把顶层开关打开了**:

```
vendor/lineage/overlay/common/frameworks/base/core/res/res/values/config.xml:98
    <bool name="config_isDesktopModeSupported">true</bool>
```

所以拼起来之后两个开关都是 `true`。这不是推测 —— 我把编出来的 apk 反编译
实际查过:

```
framework-res.apk        config_isDesktopModeSupported          = true
FrameworkResAsphalt.apk  config_canInternalDisplayHostDesktops  = true
```

另外设备树里 `PRODUCT_CHARACTERISTICS := tablet` 也是对的,平板布局正常。

**如果你在用基于这套设备树的其它 ROM 且小窗有问题**,可以往自己的 overlay 里
补上 `config_isDesktopModeSupported`,应该能解决。这个问题也值得反馈给上游。

### 自己怎么编译

编译环境:WSL2 Ubuntu 24.04,16 线程,40GB 内存,全程约 **6.5 小时**。

```bash
# 1. 同步源码(约 120GB,机器好的话十几分钟)
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --depth=1
cp local_manifest.xml .repo/local_manifests/
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags

# 2. 提取闭源驱动(见下面说明,不需要设备)
cd device/lenovo/asphalt
PYTHONPATH=$SRC/tools/extract-utils python3 extract-files.py <lineage成品包.zip>

# 3. 编译
export ALLOW_MISSING_DEPENDENCIES=true
export NINJA_ARGS="-k 0"
source build/envsetup.sh
breakfast asphalt
mka bacon -j$(nproc --all)
```

现成的脚本都在 [`scripts/`](scripts/) 里。

#### 闭源驱动(blobs)怎么来 —— 这块最容易卡住

lolipuru **没有提供 vendor 仓库**,设备树是靠 `extract-files.py` 自己抽的。

官方文档说的是"从设备提取",但实际上**从 lolipuru 自己发布的 LineageOS 23.2
成品 zip 里抽是更好的办法** —— 同作者、同 `lineage-23.2` 分支,blob 和设备树
天然精确匹配,而且**完全不需要设备,也不需要 root**:

```bash
PYTHONPATH=$SRC/tools/extract-utils python3 extract-files.py lineage-23.2-*-asphalt.zip
```

正常结果:

```
vendor/lenovo/asphalt        787 个文件   (proprietary-files.txt 要求 783)
vendor/lenovo/sm8475-common  711 个文件   (要求 707)
asphalt-vendor.mk            已生成
```

所有 pinned 文件的哈希都能对上,一个 missing 都没有。

**为什么不从设备抽**:如果设备上跑的 ROM 是 `ro.debuggable=0`(user 版),
`adb root` 会被系统拒绝,而 extract-utils 的 `source.py` 把 `adb root` 写成了
**硬性步骤**,被拒之后会打断 adb 传输,紧接着的命令必定报 `error: closed`。
从 zip 抽完全绕开这个问题。

#### 编译踩过的坑

按踩到的顺序,都是能让你白等几小时的那种:

1. **`repo sync` 千万别加 `--fail-fast`**。中断会留下"git 索引是空的但工作区
   有文件"的半残仓库,`--force-sync` 也修不好(版本号对得上就跳过),
   只能进目录 `git reset --hard HEAD`。

2. **`.wslconfig` 至少给 40GB 内存**。soong 分析阶段实测峰值 39.3GB,
   给 32GB 会被 **OOM 静默杀死**,日志里什么都不留。

3. **`.wslconfig` 里的 `swapFile` 一定要指到大盘,而且路径必须写双反斜杠**:

   ```ini
   swap=16GB
   swapFile=D:\\wsl\\swap.vhdx
   ```

   默认 swap 落在 `C:\Users\...\AppData\Local\Temp\swap.vhdx`,如果 C 盘只剩
   几 GB,swap 一涨就把 C 盘写满,内核随即给 Go 运行时发 **SIGBUS**,
   soong 会在编译 **99%** 的地方崩掉,报一句
   `unexpected signal during runtime execution` 加一大坨 goroutine 栈 ——
   **完全看不出是磁盘问题**。而且写成单反斜杠会被**静默忽略**、悄悄退回 C 盘,
   一点提示都没有,只能去查文件实际位置才发现。

4. **长任务要用 Windows 计划任务跑,而且要设成每 10 分钟重复触发**
   (`schtasks /SC MINUTE /MO 10`)。承载进程会收到 **SIGHUP** 被挂断
   (日志里是 `Got signal: hangup` / `kati failed with: signal: hangup`),
   靠重复触发 + 文件锁自愈重来。`setsid` / `nohup` 单独用不管用。
   好在 ninja 和 kati 都是增量的,**中断了重跑不会白编**。

5. **`test/cts-root` 要从源码树里摘掉**。它的 32/64 位变体安装路径冲突,
   会在许可证/SBOM 检查阶段中止编译。在 local_manifest 里加
   `<remove-project name="platform/test/cts-root"/>` 即可(本仓库的清单已经加了)。

6. **设 `NINJA_ARGS="-k 0"`**,否则某个无关模块失败会毁掉整次打包。

7. **WSL 的 vhdx 默认只增不减**。先
   `wsl --manage <发行版> --set-sparse true --allow-unsafe`,之后删文件才能把
   空间还给宿主盘。**建发行版的时候就该开**。

8. **WSL 发行版别放在 iSCSI 之类的网络盘上**。实测放在 iSCSI LUN 上的发行版
   一律 `E_UNEXPECTED` 起不来,同机本地 NVMe 上的一切正常。

9. **磁盘预算**:源码约 120GB + `out/` 约 136GB ≈ **260GB**。

### 这是官方支持的设备吗?

**不是。** crDroid 官方设备列表里没有 `asphalt`,编译时它自己也会提示:

```
There is no official support for this device yet
```

这是纯粹的个人构建,遇到问题不要去打扰 crDroid 官方或 lolipuru。

### 免责声明

刷机有风险。这个包是个人自编自用后分享出来的,**没有任何担保**。
刷之前请确认你自己清楚在做什么,以及出了问题自己有能力恢复。
设备变砖、数据丢失等一切后果自负。

---

## English

An **unofficial crDroid 16.0 (v12.11)** build for the Lenovo Legion Y700 2023
tablet (TB320FC, codename `asphalt`), based on Android 16. This device is **not**
on crDroid's official device list — this is a community build compiled entirely
from source and is **not endorsed by or affiliated with the crDroid team**.

An AviumUI build for the same device lives in a separate repo:
[aviumui-y700-2023-asphalt](https://github.com/AwHsR15/aviumui-y700-2023-asphalt).

### What's in it

- crDroid 16.0, version `v12.11-20260825`, Android 16 (SDK 36.1)
- Security patch level 2026-08-01
- **Desktop windowing / freeform works out of the box** — see
  [Desktop mode](#desktop-mode) below, it's worth reading
- **Vanilla — no Google apps.** Flash GApps separately, see [GApps](#gapps)
- Device trees and kernel are entirely [**lolipuru**](https://github.com/lolipuru)'s
  LineageOS 23.2 work. This repo is just a repo manifest plus a few build
  scripts. Credit for the earliest device bring-up and kernel/HAL sources also
  goes to **mickey36736** and **soralis0912**, per the acknowledgements in the
  LineageOS 23.2 unofficial build threads.

### Why crDroid 16.0 works with LineageOS device trees unchanged

Same baseline: crDroid's `16.0` manifest declares
`<default revision="refs/heads/lineage-23.2">` plus `android-16.0.0_r4`, which
matches lolipuru's `lineage-23.2` branch exactly. crDroid also mounts its vendor
at `vendor/lineage` and `breakfast` still runs
`lunch lineage_$target-$aosp_target_release-$variant`, so `lineage_asphalt.mk`
works with **zero changes**.

### Download

Grab the ROM zip, `recovery.img`, `boot.img`, `boot_magisk.img` (pre-patched with
Magisk), `dtbo.img`, `vendor_boot.img` and `SHA256SUMS.txt` from
[Releases](../../releases).

The zip is 1.23 GB — under GitHub's 2 GB per-file limit, so unlike the AviumUI
build **there are no split parts to join**. Verify the checksum before flashing.

### Flashing

Full system package — no need to be on any particular ROM first. Flash the
bundled recovery via fastboot, then sideload the zip from that recovery.

**This wipes all data. Bootloader must already be unlocked.**

```bash
adb reboot bootloader
fastboot getvar product        # expect: taro
fastboot getvar unlocked       # expect: yes
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img
fastboot reboot recovery
```

Then on the tablet screen:

1. If adb shows `unauthorized`, go to **Advanced → Enable ADB** (crDroid's
   recovery has ADB off by default)
2. **Factory reset → Format data / factory reset** — a `/metadata` mount error
   here is harmless
3. **Apply update → Apply from ADB**

```bash
adb sideload crDroidAndroid-16.0-20260825-asphalt-v12.11.zip
```

`Total xfer: 1.00x` means it worked. Reboot. First boot takes 5–10 minutes.

There's also a Windows one-click script in [`flasher/`](flasher/) that automates
all of this, downloads platform-tools from Google if missing, and refuses to run
against any device that isn't `asphalt`.

**Why not flash partitions directly with fastboot?** system/vendor/product are
dynamic partitions requiring fastbootd, and on some Windows machines fastbootd's
USB device (`VID_18D1&PID_D00D`) gets bound to "Android ADB Interface", breaking
the connection. Recovery sideload sidesteps that entirely.

### GApps

This build is vanilla. For Play Store, flash **MindTheGapps** (LineageOS's
recommended package):

| | |
|---|---|
| File | `MindTheGapps-16.0.0-arm64-20260409_073023.zip` (487.6 MB) |
| Download | [GitHub Releases](https://github.com/MindTheGapps/16.0.0-arm64/releases/download/MindTheGapps-16.0.0-arm64-20260409_073023/MindTheGapps-16.0.0-arm64-20260409_073023.zip) |
| SHA256 | `a6ff8b8c31f7ccd0a9f2fd651fa4438a8e39a5f63b95be246ea1f98982af2c28` |

**This repo links to GApps rather than re-hosting it** — same reasoning as not
bundling adb/fastboot: those are Google's proprietary apps with their own
distribution terms, best served from upstream.

⚠️ **Order matters:** ROM → GApps → wipe data → boot. GApps must go on **before**
the system's first boot. If you already booted, flash GApps and then **wipe data
again**, otherwise GMS won't register and you'll get constant
"Google Play services has stopped" errors.

### Root (Magisk)

**Option 1 — flash the pre-patched image.** `boot_magisk.img` in Releases is this
ROM's own `boot.img` patched with Magisk v30.7:

```bash
adb reboot bootloader
fastboot getvar current-slot          # check which slot you're on
fastboot flash boot_b boot_magisk.img # flash THAT slot
fastboot reboot
```

Flashing only the active slot leaves the other slot bootable as a fallback.

**Option 2 — patch it yourself** with [`scripts/patch_boot.sh`](scripts/patch_boot.sh),
which runs on Linux/WSL with **no device and no root required**. The trick is
mixing architectures from the Magisk APK: `magiskboot` from **x86_64** (runs on
your PC) while the payload embedded into the ramdisk — `magisk`, `magiskinit`,
`init-ld`, `stub.apk` — comes from **arm64** (runs on the tablet).

Verify root afterwards:

```bash
adb shell /debug_ramdisk/su -c id
# expect: uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

Note `su` is **not on PATH** by default — plain `adb shell su` reports
`inaccessible or not found`, which does *not* mean root failed. Use the full path.

### Desktop mode

Android 16 gates desktop windowing behind two flags, and AOSP is explicit:

> `config_isDesktopModeSupported` is the top-level flag for enabling desktop
> windowing. **If it's not enabled, all other config settings are ignored.**
>
> — [AOSP: Support multi-window](https://source.android.com/docs/core/display/multi-window)

The `asphalt` device tree overlay sets only the *subordinate* flag
(`config_canInternalDisplayHostDesktops=true`) and leaves the top-level one at
its AOSP default of `false` — so it has no effect. crDroid's common overlay sets
the top-level flag to `true`, so in this build both end up true. Verified by
decompiling the built APKs:

```
framework-res.apk        config_isDesktopModeSupported          = true
FrameworkResAsphalt.apk  config_canInternalDisplayHostDesktops  = true
```

If you're on another ROM using these device trees and freeform windows misbehave,
adding `config_isDesktopModeSupported` to your overlay should fix it.

### Building it yourself

WSL2 Ubuntu 24.04, 16 threads, 40 GB RAM, ~6.5 hours total. Scripts in
[`scripts/`](scripts/).

```bash
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --depth=1
cp local_manifest.xml .repo/local_manifests/
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
cd device/lenovo/asphalt
PYTHONPATH=$SRC/tools/extract-utils python3 extract-files.py <lineage-release.zip>
cd $SRC && export ALLOW_MISSING_DEPENDENCIES=true NINJA_ARGS="-k 0"
source build/envsetup.sh && breakfast asphalt && mka bacon -j$(nproc --all)
```

**Blobs:** lolipuru ships no vendor repo. Extract from lolipuru's own LineageOS
23.2 release zip rather than from a device — same author, same branch, exact
match, and it needs neither a device nor root. (Device extraction fails on
`ro.debuggable=0` builds because extract-utils hard-requires `adb root`, and the
refusal breaks the adb transport so the next command dies with `error: closed`.)

**Pitfalls worth knowing:**

1. Never use `repo sync --fail-fast` — an interrupt leaves repos with an empty
   git index that `--force-sync` won't repair; you need `git reset --hard HEAD`.
2. Give WSL **≥40 GB RAM** — soong peaks at 39.3 GB and gets OOM-killed silently
   at 32 GB.
3. Point `swapFile` at a big drive **with escaped backslashes**
   (`swapFile=D:\\wsl\\swap.vhdx`). The default lands on C:, and a full C: makes
   the kernel deliver **SIGBUS** to the Go runtime — soong dies at **99%** with
   `unexpected signal during runtime execution` and a goroutine dump that gives
   no hint it's a disk problem. Single backslashes are **silently ignored** and
   fall back to C:.
4. Run long builds from a **repeating** scheduled task
   (`schtasks /SC MINUTE /MO 10`) plus a lock file. The build host gets
   **SIGHUP** (`kati failed with: signal: hangup`); `setsid`/`nohup` alone don't
   save you. ninja and kati are incremental, so resuming costs nothing.
5. Drop `test/cts-root` via `<remove-project>` — its 32/64-bit variants collide
   on install path and abort the build during license/SBOM checks.
6. Set `NINJA_ARGS="-k 0"` so one unrelated failure doesn't kill packaging.
7. Enable sparse mode on the WSL vhdx **at creation time**, or freed space never
   returns to the host.
8. Don't host the WSL distro on network storage (iSCSI) — it won't start.
9. Budget ~260 GB: 120 GB source + 136 GB `out/`.

### Is this officially supported?

**No.** The build itself says `There is no official support for this device yet`.
Please don't bother the crDroid team or lolipuru with issues from this build.

### Disclaimer

Flashing carries risk. This is a personal build shared as-is with **no warranty**
of any kind. Make sure you understand what you're doing and can recover your
device before proceeding. You are solely responsible for any data loss or damage.
