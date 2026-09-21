#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 解决 ImmortalWrt 编译时 kmod-nf-ipt 与 kmod-iptables 的 ip_tables.ko / x_tables.ko 冲突

WRT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/wrt"
if [ ! -d "$WRT_DIR" ]; then
    WRT_DIR="$(pwd)"
fi

cd "$WRT_DIR" || {
    echo "PRIVATE: 未找到 wrt 目录，跳过"
    return 0 2>/dev/null || exit 0
}

echo "==> PRIVATE: 处理 kmod-iptables / kmod-nf-ipt 文件冲突"

NETFILTER_MK="package/kernel/linux/modules/netfilter.mk"
if [ ! -f "$NETFILTER_MK" ]; then
    echo "未找到 $NETFILTER_MK，跳过"
    return 0 2>/dev/null || exit 0
fi

# 备份原文件
cp -f "$NETFILTER_MK" "${NETFILTER_MK}.private.bak"

# 清空 KernelPackage/iptables 中的 FILES 变量，避免打包 ip_tables.ko 和 x_tables.ko
awk '
    BEGIN { in_iptables = 0; skip_files = 0 }
    /^define[[:space:]]+KernelPackage\/iptables([[:space:]]|$)/ { in_iptables = 1 }
    in_iptables && /^endef/ { in_iptables = 0; skip_files = 0 }
    in_iptables && /^[[:space:]]*FILES[[:space:]]*:?=/ {
        print "  FILES:="
        skip_files = 1
        next
    }
    in_iptables && skip_files {
        if ($0 ~ /\\[[:space:]]*$/) {
            next
        } else {
            skip_files = 0
            next
        }
    }
    { print }
' "${NETFILTER_MK}.private.bak" > "$NETFILTER_MK"

echo "==> PRIVATE: 已清空 kmod-iptables 的 FILES，冲突处理完成"
