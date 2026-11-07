#!/system/bin/sh
# Magisk / KernelSU 共用的安装脚本：校验 vermagic 后再覆盖 /vendor/lib/modules/msm_kgsl.ko
SKIPUNZIP=0

KVER="$(uname -r)"
MV="$(cat "$MODPATH/vermagic.txt" 2>/dev/null)"

ui_print " "
ui_print "*******************************"
ui_print "  Adreno KGSL r8 (msm_kgsl.ko) "
ui_print "*******************************"
ui_print "- 当前内核: $KVER"
ui_print "- 模块内核: $MV"

if [ "$KVER" != "$MV" ]; then
	ui_print "! vermagic 不一致，这个 ko 正常情况下加载不了"
	ui_print "! 只能用于 $MV 的内核"
	if [ -f /sdcard/kgsl_force ]; then
		ui_print "- 检测到 /sdcard/kgsl_force，强制安装"
	else
		ui_print "  确认要继续：先建一个空文件 /sdcard/kgsl_force 再刷"
		abort "! 已中止安装"
	fi
fi

if [ -f /vendor/lib/modules/msm_kgsl.ko ]; then
	ui_print "- 将覆盖 /vendor/lib/modules/msm_kgsl.ko"
else
	ui_print "- 系统内没找到原 msm_kgsl.ko，仍按此路径放置"
fi
ui_print "- 重启后生效；卸载模块再重启即恢复"

set_perm_recursive "$MODPATH" 0 0 0755 0644
