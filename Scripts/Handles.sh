#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修复vantage表单说明宽度限制（anothaDev/luci-theme-vantage#51）
FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
	-e '/^\.cbi-map-descr {/,/^}/ { /max-width: 76ch;/d; }' \
	-e 's/^\(\.cbi-section-descr { \)max-width: 80ch; /\1/' \
	-e '/^\.cbi-value-description {/,/^}/ { /max-width: 70ch;/d; }' \
	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

#gecoosac 选型：VIKINGYFY/packages 与 openwrt-package 各带一份同名包，
#统一使用 viking 版本（与历史成功构建的 -r1 一致，其 Makefile 也不依赖仓库根的 LICENSE）。
#否则同名包按扫描顺序取其一，会出现这次编 viking 版、下次编自建版的随机结果。
#以 viking 版存在为前提，缺失时保留 openwrt-package 的副本，避免把包删空。
if [ -d "$PACKAGE_PATH/packages/gecoosac" ]; then
	for NAME in gecoosac luci-app-gecoosac; do
		[ -d "$PACKAGE_PATH/openwrt-package/$NAME" ] || continue
		rm -rf "$PACKAGE_PATH/openwrt-package/$NAME"
		echo "Remove duplicate package: $PACKAGE_PATH/openwrt-package/$NAME (use VIKINGYFY copy)"
	done
fi
