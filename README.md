# msm_kgsl.ko + 刷机模块 构建包（GFX-KERNEL lnx.16.0.r8-rel）

一次 GitHub Actions 运行 =
1. 拉 6.1 高通内核树
2. 把 `src/`（CAF graphics-kernel r8）当外部模块编出 `msm_kgsl.ko`
3. 自动打包成 **Magisk / KernelSU 可直接刷入的模块 zip**

## 怎么用

1. GitHub 新建仓库（private 也行）
2. 把本目录**全部内容**传上去（`.github/` 也要）
3. Actions → **build-msm-kgsl-ko** → Run workflow
4. Artifacts 里下载 `msm_kgsl-ko-*`：

| 文件 | 说明 |
|---|---|
| `msm_kgsl-r8-module.zip` | **可刷入模块**，直接拿去 Magisk/KernelSU 刷 |
| `msm_kgsl.stripped.ko` | 去掉调试符号的 ko（3.2 MB） |
| `msm_kgsl.ko` | 带调试符号的 ko（32 MB） |
| `vermagic.txt` / `msm_kgsl.modinfo.txt` / `kernel.config` / `build.log` | 核对用 |

## 指定产物对应的内核版本（重点）

`kernel_version` 输入就是产物的 **vermagic**，也就是这个 ko 认哪一版内核：

| 填法 | 结果 |
|---|---|
| 留空 | 用内核树自己的版本，例如 `6.1.176-android14-11-ab14529422` |
| `6.1.138-android14-11-g0c3d559bcd85-ab14529422` | 把内核树版本改成这个再编，产物 vermagic 与之一致 |

工作流做的事（已实测）：

1. 拆成 `6.1.138` + `-android14-11-g0c3d559bcd85-ab14529422`
2. 改 `kd/Makefile` 的 `VERSION/PATCHLEVEL/SUBLEVEL`，清空 `EXTRAVERSION`
3. 清掉这棵树里写死的 `export BUILD_NUMBER = 14529422`（否则 setlocalversion 会再追加一个 `-ab14529422`，vermagic 就重复了）
4. `CONFIG_LOCALVERSION="<后面那截>"`、关掉 `CONFIG_LOCALVERSION_AUTO`
5. 编完用 `modinfo -F vermagic` 与输入比对，不一致直接 **红叉报错**（不会给你个假的产物）

> 注意：改的只是版本号，**代码还是那棵内核树的代码**（这里默认 6.1.176 的树）。
> 它解决的是"vermagic 对不上装不了"，解决不了"符号 CRC / 模块签名对不上"。

## 刷机模块里是什么

```
module.prop                 id=msm_kgsl_r8，version 里带 vermagic
customize.sh                安装时比对 uname -r 与 vermagic，不一致就中止
vermagic.txt
system/vendor/lib/modules/msm_kgsl.ko   ← Magisk 走这条
vendor/lib/modules/msm_kgsl.ko          ← KernelSU 走这条
```

- 刷完**重启**生效（覆盖系统里的 `/vendor/lib/modules/msm_kgsl.ko`）。
- 卸载模块 + 重启 = 恢复原样。
- 想强制装到 vermagic 不一致的内核上：先建空文件 `/sdcard/kgsl_force` 再刷（不推荐，会直接开不了 GPU）。

## 参数

| 输入 | 默认 | 说明 |
|---|---|---|
| `kernel_version` | 空 | 产物 vermagic；空=用内核树自身版本 |
| `kernel_repo` | `cnmrlin/android_kernel_xiaomi_sm8650` | 带 `arch/arm64/configs/vendor/` 的 6.1 高通树 |
| `kernel_ref` | `lineage-24.0` | 分支/tag |
| `vendor_config` | `pineapple_GKI.config` | SM8650；别的平台换对应的 |
| `jobs` | `4` | make -j |

## 本地跑也行

```bash
sudo apt install clang lld llvm make bc bison flex libssl-dev libelf-dev python3 kmod zip
git clone --depth 1 -b lineage-24.0 https://github.com/cnmrlin/android_kernel_xiaomi_sm8650 kd
./build_local.sh kd          # 出 kd/msm_kgsl/msm_kgsl.ko + kd/msm_kgsl-r8-module.zip
```

单独打包已有 ko：

```bash
bash tools/pack_module.sh path/to/msm_kgsl.ko out.zip [vermagic]
```

## 实测记录

手机上（Ubuntu arm64 chroot + clang 18.1.3 + 上面那棵树）跑通：

- 树默认版本：`6.1.176-android14-11-ab14529422`，85 个 .c 全过，ko 32 MB / strip 3.2 MB，模块 zip 1.6 MB
- 指定 `kernel_version=6.1.138-android14-11-g0c3d559bcd85-ab14529422`：产物 vermagic 完全一致


## 注意

- 官方内核开了 `CONFIG_MODVERSIONS` + 模块签名，这种自编 ko **只能配自编内核**（关掉签名/用同一棵树全量编译）。
- 想彻底对上内核，把 `kernel_repo`/`kernel_ref` 换成你自编内核的仓库和分支，再用 `kernel_version` 兜底版本号。

## 踩过的坑（都已在 workflow 里修好）

1. `governor.h` 找不到 —— Kbuild 里 `-I$(KERNEL_SRC)/drivers/devfreq`，树内 `M=` 编译时这个变量是空的，改成回落 `$(srctree)`。
2. `CONFIG_QCOM_KGSL` 被 `olddefconfig` 删掉 —— 内核树没有这个符号，把源码放 `kd/msm_kgsl/` 并在 `kd/drivers/Kconfig` 加 `source "msm_kgsl/Kconfig"`。
3. 这棵树写死了 `export BUILD_NUMBER = 14529422`，`setlocalversion` 会额外追加 `-ab14529422`，vermagic 变成两截。
4. **vermagic 尾巴多一个 `+`**（CI 上必现）：`git clone` 出来的仓库不在 tag 上，`setlocalversion` 的 `scm_version --short` 返回 `+`，
   而它的判断条件是「`LOCALVERSION` 环境变量是否已定义」。本地用 tarball 编不会出现，所以容易漏。
   修法：全程给 make 一个**空的** `LOCALVERSION`（已定义 → 不加 `+`），workflow 里 job env 和 `$GITHUB_ENV` 都设了。
   另外 `modules_prepare` 之后会先读 `out/include/config/kernel.release` 和目标比对，**不对就立刻失败**，不用等 20 分钟编译完才发现。
