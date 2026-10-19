#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 处理 ImmortalWrt 编译中的内核模块文件冲突

WRT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/wrt"
[ -d "$WRT_DIR" ] || WRT_DIR="$(pwd)"
cd "$WRT_DIR" || { echo "PRIVATE: 未找到 wrt 目录"; return 0 2>/dev/null || exit 0; }

NETFILTER_MK="package/kernel/linux/modules/netfilter.mk"

if [ ! -f "$NETFILTER_MK" ]; then
    echo "未找到 $NETFILTER_MK，跳过"
    return 0 2>/dev/null || exit 0
fi

echo "=============================================="
echo "==> PRIVATE: 处理内核模块文件冲突"
echo "=============================================="

cp -f "$NETFILTER_MK" "${NETFILTER_MK}.private.bak"

# 1) 清空 KernelPackage/iptables 的 FILES
#    让 ip_tables.ko / x_tables.ko 只由 kmod-nf-ipt 提供
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
        if ($0 ~ /\\[[:space:]]*$/) { next }
        else { skip_files = 0; next }
    }
    { print }
' "${NETFILTER_MK}.private.bak" > "$NETFILTER_MK"
echo "已清空 KernelPackage/iptables 的 FILES"

# 2) 清空 KernelPackage/nf-conntrack-bridge 的 FILES
#    让 nf_conntrack_bridge.ko 只由 kmod-nft-bridge 提供
cp -f "$NETFILTER_MK" "${NETFILTER_MK}.private.bak2"
awk '
    BEGIN { in_nfcb = 0; skip_files = 0 }
    /^define[[:space:]]+KernelPackage\/nf-conntrack-bridge([[:space:]]|$)/ { in_nfcb = 1 }
    in_nfcb && /^endef/ { in_nfcb = 0; skip_files = 0 }
    in_nfcb && /^[[:space:]]*FILES[[:space:]]*:?=/ {
        print "  FILES:="
        skip_files = 1
        next
    }
    in_nfcb && skip_files {
        if ($0 ~ /\\[[:space:]]*$/) { next }
        else { skip_files = 0; next }
    }
    { print }
' "${NETFILTER_MK}.private.bak2" > "$NETFILTER_MK"
echo "已清空 KernelPackage/nf-conntrack-bridge 的 FILES"

# 3) 确认 kmod-nft-bridge 在 .config 中为 =y
if [ -f .config ]; then
    if grep -q '^CONFIG_PACKAGE_kmod-nft-bridge=y' .config; then
        echo "kmod-nft-bridge 已启用，nf_conntrack_bridge.ko 由它提供"
    else
        echo "注意：kmod-nft-bridge 未在 .config 中启用，nf_conntrack_bridge.ko 可能无人提供"
    fi
fi

echo "=============================================="
echo "==> PRIVATE: 处理完成"
echo "=============================================="
