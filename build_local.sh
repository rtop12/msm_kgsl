#!/bin/bash
# PC/Linux 本地跑（x86_64 或任意能装 clang 的机器）
# 用法: ./build_local.sh <内核树目录> [分支名无关]
set -euo pipefail
KD=$(cd "${1:?用法: ./build_local.sh <内核树目录>}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
VCONF=${VCONF:-pineapple_GKI.config}
JOBS=${JOBS:-$(nproc)}

rm -rf "$KD/msm_kgsl" && mkdir -p "$KD/msm_kgsl"
rsync -a --exclude='.git*' "$HERE/src/" "$KD/msm_kgsl/"
sed -i 's|-I$(KERNEL_SRC)/drivers/devfreq|-I$(if $(KERNEL_SRC),$(KERNEL_SRC),$(srctree))/drivers/devfreq|' "$KD/msm_kgsl/Kbuild"
grep -q 'msm_kgsl/Kconfig' "$KD/drivers/Kconfig" || printf '\n# KGSL (Adreno)\nsource "msm_kgsl/Kconfig"\n' >> "$KD/drivers/Kconfig"

cd "$KD"
mkdir -p out
make O=out ARCH=arm64 LLVM=1 gki_defconfig
scripts/kconfig/merge_config.sh -m -O out out/.config "arch/arm64/configs/vendor/$VCONF"
scripts/config --file out/.config \
  -e MODULES -e MODVERSIONS -e MODULE_UNLOAD \
  -e QCOM_KGSL -e QCOM_KGSL_POOL -e QCOM_KGSL_CONTEXT_DEBUG \
  -e LTO_NONE -d LTO_CLANG_THIN -d LTO_CLANG_FULL \
  -e DEBUG_INFO_NONE -d DEBUG_INFO_BTF -d DEBUG_INFO_DWARF5 \
  -e WERROR -d MODULE_SIG_ALL -d MODULE_SIG_FORCE -d MODULE_SIG_PROTECT
make O=out ARCH=arm64 LLVM=1 olddefconfig
make O=out ARCH=arm64 LLVM=1 -j"$JOBS" modules_prepare
make O=out ARCH=arm64 LLVM=1 -j"$JOBS" M="$KD/msm_kgsl" KERNEL_SRC="$KD" modules
ls -l "$KD/msm_kgsl/msm_kgsl.ko"

# 顺手打个可刷入模块 zip（Magisk / KernelSU）
if command -v zip >/dev/null 2>&1 && [ -f "$HERE/tools/pack_module.sh" ]; then
  bash "$HERE/tools/pack_module.sh" "$KD/msm_kgsl/msm_kgsl.ko" "$KD/msm_kgsl-r8-module.zip" || true
fi
