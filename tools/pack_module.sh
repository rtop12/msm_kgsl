#!/bin/bash
# =============================================================================
# 把编好的 msm_kgsl.ko 打包成 Magisk / KernelSU 可刷入模块 zip
#
#   bash tools/pack_module.sh <msm_kgsl.ko> [输出zip] [vermagic]
#
# 产物解压后结构:
#   module.prop / customize.sh / vermagic.txt
#   system/vendor/lib/modules/msm_kgsl.ko   (Magisk 用)
#   vendor/lib/modules/msm_kgsl.ko          (KernelSU 用)
# =============================================================================
set -euo pipefail

KO=${1:?用法: pack_module.sh <msm_kgsl.ko> [输出zip] [vermagic]}
REFDIR=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$KO" ] || { echo "找不到 $KO" >&2; exit 1; }
[ -f "$REFDIR/module/module.prop" ] || { echo "缺少 $REFDIR/module/module.prop" >&2; exit 1; }

VERMAGIC=${3:-}
if [ -z "$VERMAGIC" ]; then
	VERMAGIC=$(modinfo -F vermagic "$KO" 2>/dev/null | awk '{print $1}')
fi
[ -n "$VERMAGIC" ] || { echo "读不到 vermagic，请作为第 3 个参数传入" >&2; exit 1; }

OUTZIP=${2:-$PWD/msm_kgsl-r8-module.zip}
case "$OUTZIP" in /*) ;; *) OUTZIP=$PWD/$OUTZIP ;; esac
DATE=$(date +%Y%m%d)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cp -a "$REFDIR/module/." "$TMP/"
mkdir -p "$TMP/system/vendor/lib/modules" "$TMP/vendor/lib/modules"
cp "$KO" "$TMP/system/vendor/lib/modules/msm_kgsl.ko"
cp "$KO" "$TMP/vendor/lib/modules/msm_kgsl.ko"
printf '%s\n' "$VERMAGIC" > "$TMP/vermagic.txt"
chmod 755 "$TMP/customize.sh" 2>/dev/null || true

sed -i "s|@VERMAGIC@|$VERMAGIC|g; s|@DATE@|$DATE|g" "$TMP/module.prop"
sed -i "s|^versionCode=.*|versionCode=$DATE|" "$TMP/module.prop"

rm -f "$OUTZIP"
( cd "$TMP" && zip -qr "$OUTZIP" . )
echo "模块: $OUTZIP"
echo "vermagic: $VERMAGIC"
echo "大小: $(du -h "$OUTZIP" | cut -f1)"
