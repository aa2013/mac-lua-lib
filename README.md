# mac-lua-lib (Lua 5.4.8 for macOS Universal)

这个仓库用于打包 **macOS 可用的 Lua 5.4.8 通用库（x86_64 + arm64）**，目标是给 Flutter Dart FFI 或其他框架直接引入，不负责 Flutter 业务实现。

Android 版本见[android-lua-lib](https://github.com/aa2013/android-lua-lib)

ios 版本见 [iOS-LuaFramework](https://github.com/aa2013/LuaFramework)

## 能力

- 从 Lua 官方源码 `5.4.8` 构建两套架构产物：
  - `x86_64`（Intel Mac）
  - `arm64`（Apple Silicon）
- 使用 `lipo` 合并成单个通用库（Universal Binary）
- 输出内容：
  - `lib/liblua.5.4.8.dylib`
  - `lib/liblua.5.4.dylib -> liblua.5.4.8.dylib`
  - `lib/liblua.dylib -> liblua.5.4.dylib`
  - `lib/liblua.a`
  - `include/*.h`

## 环境要求

- macOS
- Xcode Command Line Tools（提供 `clang` / `lipo`）
- `curl`, `tar`, `make`

## 本地打包

```bash
./scripts/build_universal_lua.sh
```

默认输出目录：

```text
dist/Lua-5.4.8-macos-universal
```

可选环境变量：

- `LUA_VERSION`：默认 `5.4.8`
- `MIN_MACOS`：默认 `11.0`
- `WORKDIR`：默认 `$(pwd)/.build`
- `OUTDIR`：默认 `$(pwd)/dist/Lua-${LUA_VERSION}-macos-universal`
- `JOBS`：默认 CPU 核心数

示例：

```bash
MIN_MACOS=10.13 OUTDIR=$PWD/out ./scripts/build_universal_lua.sh
```

## GitHub Actions 自动 CI 打包

仓库已提供工作流：

- `.github/workflows/build-macos-universal.yml`

触发方式：

- 手动触发：`workflow_dispatch`
- Push 到 `main` / `master` / `work`
- Push tag（`v*`）

CI 会自动完成：

1. 构建 Lua 5.4.8 的 `x86_64` 与 `arm64` 通用库
2. 验证产物架构（`lipo -archs`）
3. 打包 `dist/Lua-5.4.8-macos-universal.tar.gz`
4. 上传为 Actions Artifact（可直接下载）

## 验证架构

```bash
lipo -archs dist/Lua-5.4.8-macos-universal/lib/liblua.5.4.8.dylib
```

预期输出应包含：

```text
x86_64 arm64
```
