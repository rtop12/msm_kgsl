# msm_kgsl.ko 构建包（GFX-KERNEL lnx.16.0.r8-rel）

一次 GitHub Actions 运行 = 拉内核树 + 把 `src/`（你给的 r8 源码）当外部模块编出 `msm_kgsl.ko`。

## 怎么用

1. GitHub 新建仓库（private 也行）
2. 把本目录**全部内容**传上去，`.github/` 也要（网页 Upload files 拖整个文件夹即可）
3. Actions → **build-msm-kgsl-ko** → Run workflow（默认参数不用动）
4. 跑完在 Artifacts 里下载 `msm_kgsl-ko`：
   - `msm_kgsl.ko`（带 debug 信息）
   - `msm_kgsl.stripped.ko`（strip 过的，小很多）
   - `msm_kgsl.modinfo.txt`、`build.log`、`kernel.config`

## 默认参数（可改）

| 输入 | 默认 | 说明 |
|---|---|---|
| `kernel_repo` | `cnmrlin/android_kernel_xiaomi_sm8650` | 带 `arch/arm64/configs/vendor/` 的 6.1 高通树 |
| `kernel_ref` | `lineage-24.0` | 分支/tag |
| `vendor_config` | `pineapple_GKI.config` | SM8650(pineapple) 片段；别的平台换 `gki_kalama.conf` 之类 |
| `jobs` | `4` | make -j |

## 这套参数是实测能编过的

我在这台手机上用同一套步骤（Ubuntu arm64 + clang 18.1.3 + 上面那棵树）跑通了：

```
CONFIG_QCOM_KGSL=m  → 85 个 .c 全部编过 → msm_kgsl.ko
vermagic: 6.1.176-android14-11-ab14529422 SMP preempt mod_unload modversions aarch64
大小: 32MB（带 debug）/ 3.2MB（strip 后）
```

过程中踩到并已在 workflow 里修好的两个坑：

1. `governor_msm_adreno_tz.c: governor.h not found`
   → 源码 Kbuild 里 `-I$(KERNEL_SRC)/drivers/devfreq`，树内 `M=` 编译时 `KERNEL_SRC` 是空的；
     workflow 用 sed 改成 `$(if $(KERNEL_SRC),$(KERNEL_SRC),$(srctree))`。
2. `CONFIG_QCOM_KGSL` 在内核树里没有 Kconfig，`olddefconfig` 会把它删掉
   → 把源码放成 `kd/msm_kgsl/`，并在 `kd/drivers/Kconfig` 加一行 `source "msm_kgsl/Kconfig"`。

## 拿到 ko 之后（重要）

- 这是 **6.1.176-android14-11** 树上编的；你手机现在是 `6.1.138-android14-11-g0c3d559bcd85-ab14529422`，
  vermagic 对不上就 insmod 不了（`Invalid module format`）。
- 官方内核还开了 `CONFIG_MODVERSIONS=y` + 模块签名（`CONFIG_MODULE_SIG_ALL/PROTECT`），
  自编 ko 没有厂商签名、也没有对应符号 CRC，**只能加载到你自己编的内核上**。
- 想真的上机：编自编内核时把这个 ko 一起装（或者直接把 graphics-kernel 编进内核），
  同时关掉模块签名强制校验。
