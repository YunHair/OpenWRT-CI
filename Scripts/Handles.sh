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

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

#gecoosac 修复：上游 Makefile 用 $(CP) ../LICENSE，但本仓库只同步包目录、
#根目录没有 LICENSE，prepare 阶段会 “cp: cannot stat '../LICENSE'” 直接失败。
#这里补一份 LICENSE 并改成就地引用（内容取自上游 laipeng668/luci-app-gecoosac）。
#包由 autosync 每日 rsync --delete 覆盖，所以放在 CI 侧兜底，不依赖仓库状态。
GECOO_DIR="$PACKAGE_PATH/openwrt-package/gecoosac"
if [ -f "$GECOO_DIR/Makefile" ] && grep -q '\.\./LICENSE' "$GECOO_DIR/Makefile"; then
	[ -f "$GECOO_DIR/LICENSE" ] || printf '%s\n' \
		'GNU Affero General Public License v3.0 only' \
		'' \
		'The gecoosac package in this directory is distributed under the GNU' \
		'Affero General Public License version 3 only.' \
		'' \
		'SPDX-License-Identifier: AGPL-3.0-only' \
		'' \
		'Canonical license text:' \
		'https://www.gnu.org/licenses/agpl-3.0.txt' > "$GECOO_DIR/LICENSE"
	sed -i 's#\$(CP) \.\./LICENSE#$(CP) ./LICENSE#' "$GECOO_DIR/Makefile"
	echo "Fix gecoosac LICENSE path: done"
fi

#gecoosac 去重：VIKINGYFY/packages 与 openwrt-package 各带一份同名包，
#统一使用 openwrt-package 版本（release 号更新，且 gecoosac 提供 gecoosac-files/gecoosac-common）。
#否则同名包按扫描顺序取其一，会出现这次编 viking 版、下次编自建版的随机结果。
if [ -d "$PACKAGE_PATH/openwrt-package/gecoosac" ]; then
	for NAME in gecoosac luci-app-gecoosac; do
		[ -d "$PACKAGE_PATH/packages/$NAME" ] || continue
		rm -rf "$PACKAGE_PATH/packages/$NAME"
		echo "Remove duplicate package: $PACKAGE_PATH/packages/$NAME (use openwrt-package copy)"
	done
fi
