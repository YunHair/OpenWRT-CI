#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 排查 kmod-iptables 来源 + 解决 kmod-nf-ipt / kmod-iptables 的 ip_tables.ko / x_tables.ko 冲突

WRT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/wrt"
[ -d "$WRT_DIR" ] || WRT_DIR="$(pwd)"
cd "$WRT_DIR" || { echo "PRIVATE: 未找到 wrt 目录"; return 0 2>/dev/null || exit 0; }

PKGIN="tmp/.config-package.in"
NETFILTER_MK="package/kernel/linux/modules/netfilter.mk"

echo "=============================================="
echo "==> PRIVATE: 第一步，排查谁引入了 kmod-iptables"
echo "=============================================="

# 1) .config 中的状态
echo "--- 当前 .config 中的 kmod-iptables 状态 ---"
grep -n 'kmod-iptables' .config 2>/dev/null || echo "(未在 .config 中出现)"

# 2) 从 tmp/.config-package.in 找 select / depends on
if [ -f "$PKGIN" ]; then
    echo
    echo "--- $PKGIN 中 select/depends on kmod-iptables 的包 ---"
    awk '
        /^config PACKAGE_/ { pkg = $2 }
        /^[[:space:]]*(select|depends on)[[:space:]]+PACKAGE_kmod-iptables([[:space:]]|$)/ {
            print pkg " -> " $0
        }
    ' "$PKGIN" | sort -u

    echo
    echo "--- kmod-iptables 自身的定义 ---"
    awk '
        /^config PACKAGE_kmod-iptables$/ { show = 1 }
        show { print }
        show && /^$/{ exit }
    ' "$PKGIN"

    # 3) 已启用包里直接依赖 kmod-iptables 的
    echo
    echo "--- 已启用包中直接依赖 kmod-iptables 的候选 ---"
    for pkg in $(grep -oP '^CONFIG_PACKAGE_\K[^=]+(?==y)' .config | sort -u); do
        if awk -v p="PACKAGE_$pkg" '
            $0 == "config " p { found=1; next }
            found && /^config / { exit }
            found && /(select|depends on)[[:space:]]+PACKAGE_kmod-iptables([[:space:]]|$)/ { hit=1 }
            END { exit !hit }
        ' "$PKGIN"; then
            echo "PACKAGE_$pkg"
        fi
    done
else
    echo "未找到 $PKGIN（可能还没执行 make defconfig）"
fi

# 4) 源码 Makefile 里 +kmod-iptables
echo
echo "--- 源码 Makefile 中依赖 kmod-iptables 的包 ---"
grep -rn --include=Makefile --include='*.mk' \
    -E '(\+kmod-iptables|\+PACKAGE_kmod-iptables|kmod-iptables)' \
    ./package ./feeds 2>/dev/null \
    | grep -v 'netfilter.mk' \
    | sort -u

echo
echo "=============================================="
echo "==> PRIVATE: 第二步，消除 ip_tables.ko / x_tables.ko 冲突"
echo "=============================================="

if [ ! -f "$NETFILTER_MK" ]; then
    echo "未找到 $NETFILTER_MK，跳过冲突处理"
else
    cp -f "$NETFILTER_MK" "${NETFILTER_MK}.private.bak"

    # 清空 KernelPackage/iptables 的 FILES，保留 AUTOLOAD/DEPENDS 等其它行
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

    echo "已清空 $NETFILTER_MK 中 KernelPackage/iptables 的 FILES"
fi

# 5) 确保 kmod-nf-ipt 仍被启用，由它提供 ip_tables.ko / x_tables.ko
if [ -f .config ]; then
    if grep -q '^CONFIG_PACKAGE_kmod-nf-ipt=y' .config; then
        echo "kmod-nf-ipt 已启用，ip_tables.ko / x_tables.ko 由它提供"
    elif grep -q '^CONFIG_PACKAGE_kmod-nf-ipt=m' .config; then
        echo "注意：kmod-nf-ipt 当前为 =m，建议改为 =y"
        sed -i 's/^CONFIG_PACKAGE_kmod-nf-ipt=m/CONFIG_PACKAGE_kmod-nf-ipt=y/' .config
        echo "已改为 =y"
    else
        echo "警告：.config 中未找到 kmod-nf-ipt，ip_tables.ko / x_tables.ko 可能无人提供"
    fi
fi

echo
echo "=============================================="
echo "==> PRIVATE: 处理完成"
echo "=============================================="
