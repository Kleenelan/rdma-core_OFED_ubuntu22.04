# rdma-core Debug 构建

从 `MLNX_OFED_SRC` 中抽取 `rdma-core` 源码，并编译为带调试符号的版本，方便用 GDB 做源码级调试。

## 仓库内容

```text
build-rdma-core-debug.sh   # 一键构建脚本
MLNX_OFED_SRC-24.10-5.1.6.1/SOURCES/rdma-core_2410mlnx54.orig.tar.gz
```

## 依赖

脚本会自动尝试安装依赖（需要 `sudo`）：

- `build-essential` / `cmake` / `ninja-build`（包名；可执行文件可能是 `ninja` 或 `ninja-build`）/ `pkg-config`
- `libnl-3-dev` / `libnl-route-3-dev`
- `libnuma-dev` / `libssl-dev` / `libelf-dev`
- `libudev-dev` / `libsystemd-dev` / `systemd`
- `dh-python` / `python3-dev` / `python3-docutils`
- `pandoc` / `valgrind` / `quilt` / `fakeroot`

## 快速构建

```bash
bash build-rdma-core-debug.sh
```

构建目录默认在当前目录下：`$PWD/rdma-core-debug-build/`。

构建完成后会输出类似：

```text
Build complete: /home/<user>/.../rdma-core-debug-build/rdma-core-2410mlnx54/build
  Shared libraries: /home/<user>/.../rdma-core-debug-build/rdma-core-2410mlnx54/build/lib
  Binaries:         /home/<user>/.../rdma-core-debug-build/rdma-core-2410mlnx54/build/bin
```

如果当前目录的绝对路径太长，脚本会提前报错并提示使用更短的 `BUILD_ROOT`：

```bash
BUILD_ROOT="$PWD/rdma" bash ./build-rdma-core-debug.sh
```

## 常见错误：ninja 编译失败 `size of unnamed array is negative`

### 现象

`ninja` 在编译 `librdmacm/acm.c` 时报错：

```text
error: size of unnamed array is negative
BUILD_ASSERT(sizeof(IBACM_SERVER_PATH) <= sizeof(addr.unx.sun_path));
```

### 原因

`-DIN_PLACE=1` 时，`CMAKE_INSTALL_PREFIX` 被设为构建目录本身。如果构建目录的绝对路径太长，生成的 `IBACM_SERVER_PATH`（例如 `/home/.../rdma-core-debug-build/.../build/var/run/ibacm.sock`）会超过 Unix domain socket 路径长度限制 `sockaddr_un.sun_path`（108 字节）。同时 `ACM_CONF_DIR` 也会超过 `ibacm` 里固定的 128 字节缓冲区。

### 解决方案

脚本默认在当前目录下构建：

```bash
BUILD_ROOT="${BUILD_ROOT:-$WORK_DIR/rdma-core-debug-build}"
```

同时在 `cmake` 中显式指定：

```bash
-DCMAKE_INSTALL_RUNDIR=/run
```

这样 `ibacm.sock` 的运行时路径为 `/run/ibacm.sock`，远小于 108 字节限制。

如果当前目录的绝对路径导致 `ACM_CONF_DIR` 超过 128 字节缓冲区，脚本会提前报错。此时请使用更短的 `BUILD_ROOT`，例如：

```bash
BUILD_ROOT="$PWD/rdma" bash ./build-rdma-core-debug.sh
```

## 调试使用示例

```bash
cd $PWD/rdma-core-debug-build/rdma-core-2410mlnx54/build/
LD_LIBRARY_PATH=$PWD/lib gdb <your_app>
```

## 系统级安装（可选）

如果希望生成系统级 debug 包而不是本地 in-place 构建，可参考：

```bash
EXTRA_CMAKE_FLAGS='-DCMAKE_BUILD_TYPE=Debug' DEB_BUILD_OPTIONS='nostrip' \
    sudo -E perl install.pl --user-space-only --all
```
