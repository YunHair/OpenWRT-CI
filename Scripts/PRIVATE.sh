#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 解决 ImmortalWrt 编译时 kmod-nf-ipt 与 kmod-iptables 的 ip_tables.ko / x_tables.ko 冲突

WRT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/wrt"
if [ ! -d "$WRT_DIR" ]; then
    WRT_DIR="$(pwd)"
fi

if ! cd "$WRT_DIR"; then
    echo "PRIVATE: 未找到 wrt 目录，跳过 kmod-iptables 处理"
    return 0 2>/dev/null || exit 0
fi

echo "==> PRIVATE: 处理 kmod-iptables / kmod-nf-ipt 文件冲突"

# 1. 删除 feed 中可能独立存在的 kmod-iptables 包目录
find ./package ./feeds -maxdepth 7 -type d -iname 'kmod-iptables' -print 2>/dev/null | while IFS= read -r dir; do
    echo "删除目录: $dir"
    rm -rf "$dir"
done

# 2. 从 KernelPackage/iptables 的 FILES 中移除重复提供的 ip_tables.ko 和 x_tables.ko
#    这样 kmod-iptables 不再提供这两个文件，交给 kmod-nf-ipt 提供，避免文件冲突
find ./package/kernel ./feeds -type f \( -name '*.mk' -o -name 'Makefile' \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
    if ! grep -q 'define KernelPackage/iptables' "$file" 2>/dev/null; then
        continue
    fi

    echo "处理文件: $file"
    cp -f "$file" "${file}.private.bak" 2>/dev/null || true

    awk '
        BEGIN { in_iptables = 0 }
        /^define[[:space:]]+KernelPackage\/iptables([[:space:]]|$)/ { in_iptables = 1 }
        in_iptables && /^endef/ { in_iptables = 0 }
        in_iptables && /ip_tables\.ko|x_tables\.ko/ { next }
        { print }
    ' "${file}.private.bak" > "$file"

    # 修复删除 FILES 最后一行后可能残留的续行反斜杠
    perl -0pi -e 's/\\\n(\s*endef)/\n$1/g' "$file" 2>/dev/null || true
done

# 3. 如果此时已经有 .config，再强制关掉 kmod-iptables
if [ -f .config ]; then
    sed -i '/CONFIG_PACKAGE_kmod-iptables=/d' .config
    echo '# CONFIG_PACKAGE_kmod-iptables is not set' >> .config
fi

echo "==> PRIVATE: kmod-iptables 冲突处理完成"
