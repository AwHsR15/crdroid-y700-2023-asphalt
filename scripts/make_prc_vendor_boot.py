#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 ROW 基线的 vendor_boot.img 转成 PRC,供国行(PRC 区域锁)机器使用。

背景
────
联想从 2024-04 起给 Y700 2023 加了硬件区域锁,区域码写进安全持久分区后
**永久不可移除**。社区的做法不是"把设备改回 ROW"(做不到),而是反过来
**把 ROM 改成 PRC 去迎合设备**。

区域标记藏在 vendor_boot 内嵌的设备树里:一个值为 "ROW" 的 FDT 属性。
本设备的 vendor_boot 里有 4 处(对应 4 个 DTB)。

FDT 属性的二进制布局:

    00 00 00 03   FDT_PROP token
    00 00 00 04   len = 4
    xx xx xx xx   nameoff(属性名在 strings 块里的偏移)
    52 4F 57 00   值 = "ROW\\0"

"PRC" 和 "ROW" 都是 3 字符,替换后长度不变,FDT 结构和后续偏移全部保持
不变 —— 所以这是一次干净的等长替换。

本脚本**只替换通过 FDT 结构校验的位置**(token=FDT_PROP 且 len=4),
不做无脑字符串替换 —— 镜像里存在 "RPRCSD" 之类的巧合子串,盲替会损坏文件。

用法
────
    python3 make_prc_vendor_boot.py vendor_boot.img vendor_boot_prc.img
    python3 make_prc_vendor_boot.py --to-row vendor_boot_prc.img vendor_boot.img
    python3 make_prc_vendor_boot.py --check vendor_boot.img      # 只看不改

⚠️ 注意
────
- 改完 vendor_boot 之后,它的 AVB 哈希就和 vbmeta 对不上了。本 ROM 面向
  已解锁 Bootloader 的设备(vbmeta 已带 --disable-verity --disable-verification),
  通常不影响启动;但这一点**未在真实 PRC 机器上验证过**。
- 本脚本没有 PRC 实机可测。请自行确认能开机、并准备好回滚手段。
"""
import argparse
import struct
import sys

FDT_PROP = 0x00000003
VALUE_LEN = 4  # "ROW\0" / "PRC\0"


def find_region_props(data, want):
    """找出所有值为 want 的 FDT 属性,返回值起始偏移列表。

    只有满足 token == FDT_PROP 且 len == 4 的才算数,避免误伤巧合子串。
    """
    hits = []
    needle = want + b"\x00"
    pos = 0
    while True:
        i = data.find(needle, pos)
        if i < 0:
            break
        pos = i + 1
        head = i - 12  # token(4) + len(4) + nameoff(4)
        if head < 0:
            continue
        token, length = struct.unpack(">II", data[head:head + 8])
        if token == FDT_PROP and length == VALUE_LEN:
            hits.append(i)
    return hits


def main():
    ap = argparse.ArgumentParser(
        description="ROW <-> PRC 转换 vendor_boot.img 里的设备树区域标记")
    ap.add_argument("src", help="输入 vendor_boot.img")
    ap.add_argument("dst", nargs="?", help="输出文件(--check 时不需要)")
    ap.add_argument("--to-row", action="store_true",
                    help="反向转换:PRC -> ROW(默认是 ROW -> PRC)")
    ap.add_argument("--check", action="store_true",
                    help="只检测当前区域,不写任何文件")
    args = ap.parse_args()

    with open(args.src, "rb") as f:
        data = bytearray(f.read())

    n_row = len(find_region_props(data, b"ROW"))
    n_prc = len(find_region_props(data, b"PRC"))

    print("输入: %s" % args.src)
    print("  设备树里的区域标记:  ROW x%d   PRC x%d" % (n_row, n_prc))

    if n_row and n_prc:
        print("  判定: 混合(两种都有)—— 不正常,请检查来源文件")
    elif n_row:
        print("  判定: ROW(全球)")
    elif n_prc:
        print("  判定: PRC(国行)")
    else:
        print("  判定: 找不到区域标记")
        print()
        print("  这个 vendor_boot 里没有区域标记。可能是:")
        print("    · 不是这台设备的 vendor_boot")
        print("    · 该固件版本不带这个标记")
        print("  无需转换,也无从转换。")
        return 1 if not args.check else 0

    if args.check:
        return 0

    if not args.dst:
        print("\n错误: 需要指定输出文件")
        return 2

    src_val, dst_val = (b"PRC", b"ROW") if args.to_row else (b"ROW", b"PRC")
    offs = find_region_props(data, src_val)

    if not offs:
        print("\n没有可替换的 %s 标记,已经是目标区域了?" % src_val.decode())
        return 1

    for o in offs:
        data[o:o + 3] = dst_val

    with open(args.dst, "wb") as f:
        f.write(data)

    print()
    print("已替换 %d 处: %s -> %s" % (len(offs), src_val.decode(), dst_val.decode()))
    print("  替换偏移: %s" % ", ".join(hex(o) for o in offs))
    print("输出: %s" % args.dst)
    print()
    print("复核输出文件:")
    with open(args.dst, "rb") as f:
        out = f.read()
    print("  ROW x%d   PRC x%d" % (len(find_region_props(out, b"ROW")),
                                   len(find_region_props(out, b"PRC"))))
    print("  文件大小: %d 字节(应与输入完全一致: %d)" % (len(out), len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
