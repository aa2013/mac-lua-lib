#!/usr/bin/env bash
set -euo pipefail

LUA_VERSION="${LUA_VERSION:-5.4.8}"
MIN_MACOS="${MIN_MACOS:-11.0}"
WORKDIR="${WORKDIR:-$(pwd)/.build}"
OUTDIR="${OUTDIR:-$(pwd)/dist/Lua-${LUA_VERSION}-macos-universal}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
  echo "tar is required" >&2
  exit 1
fi
if ! command -v lipo >/dev/null 2>&1; then
  echo "lipo is required (Xcode command line tools)" >&2
  exit 1
fi

LUA_TGZ="lua-${LUA_VERSION}.tar.gz"
LUA_URL="https://www.lua.org/ftp/${LUA_TGZ}"

SRC_TGZ_PATH="${WORKDIR}/${LUA_TGZ}"
SRC_ROOT="${WORKDIR}/lua-${LUA_VERSION}"
BUILD_ROOT="${WORKDIR}/build"

mkdir -p "${WORKDIR}" "${BUILD_ROOT}"

if [[ ! -f "${SRC_TGZ_PATH}" ]]; then
  echo "[1/6] Downloading ${LUA_TGZ}..."
  curl -fL "${LUA_URL}" -o "${SRC_TGZ_PATH}"
else
  echo "[1/6] Using cached ${SRC_TGZ_PATH}"
fi

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "[2/6] Extracting source..."
  tar -xzf "${SRC_TGZ_PATH}" -C "${WORKDIR}"
else
  echo "[2/6] Using existing source tree ${SRC_ROOT}"
fi

build_for_arch() {
  local arch="$1"
  local stage="${BUILD_ROOT}/${arch}"
  local src_copy="${stage}/src"

  echo "[3/6] Building Lua ${LUA_VERSION} for ${arch}..."
  rm -rf "${stage}"
  mkdir -p "${stage}"
  cp -R "${SRC_ROOT}" "${src_copy}"

  pushd "${src_copy}/src" >/dev/null

  make clean >/dev/null 2>&1 || true

  local common_flags
  common_flags="-O2 -fPIC -arch ${arch} -mmacosx-version-min=${MIN_MACOS}"

  make -j"${JOBS}" \
    CC="clang" \
    AR="ar rcu" \
    RANLIB="ranlib" \
    MYCFLAGS="${common_flags}" \
    MYLDFLAGS="-arch ${arch} -mmacosx-version-min=${MIN_MACOS}" \
    MYLIBS="" \
    all

  mkdir -p "${stage}/lib" "${stage}/include"

  clang -dynamiclib \
    -arch "${arch}" \
    -mmacosx-version-min="${MIN_MACOS}" \
    -install_name "@rpath/liblua.5.4.dylib" \
    -compatibility_version "5.4.0" \
    -current_version "${LUA_VERSION}" \
    -o "${stage}/lib/liblua.${LUA_VERSION}.dylib" \
    lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o lmem.o \
    lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o ltm.o lundump.o \
    lvm.o lzio.o lauxlib.o lbaselib.o lcorolib.o ldblib.o liolib.o lmathlib.o \
    loadlib.o loslib.o lstrlib.o ltablib.o lutf8lib.o linit.o

  cp lua.h luaconf.h lualib.h lauxlib.h lua.hpp "${stage}/include/"
  cp liblua.a "${stage}/lib/liblua.a"

  popd >/dev/null
}

build_for_arch "x86_64"
build_for_arch "arm64"

mkdir -p "${OUTDIR}/lib" "${OUTDIR}/include"

echo "[4/6] Merging static library..."
lipo -create \
  "${BUILD_ROOT}/x86_64/lib/liblua.a" \
  "${BUILD_ROOT}/arm64/lib/liblua.a" \
  -output "${OUTDIR}/lib/liblua.a"

echo "[5/6] Merging dynamic library..."
lipo -create \
  "${BUILD_ROOT}/x86_64/lib/liblua.${LUA_VERSION}.dylib" \
  "${BUILD_ROOT}/arm64/lib/liblua.${LUA_VERSION}.dylib" \
  -output "${OUTDIR}/lib/liblua.${LUA_VERSION}.dylib"

pushd "${OUTDIR}/lib" >/dev/null
ln -sf "liblua.${LUA_VERSION}.dylib" "liblua.5.4.dylib"
ln -sf "liblua.5.4.dylib" "liblua.dylib"
popd >/dev/null

cp "${BUILD_ROOT}/arm64/include/"*.h "${OUTDIR}/include/"
cp "${BUILD_ROOT}/arm64/include/lua.hpp" "${OUTDIR}/include/"

echo "[6/6] Done"
echo "Output: ${OUTDIR}"
file "${OUTDIR}/lib/liblua.${LUA_VERSION}.dylib"
lipo -archs "${OUTDIR}/lib/liblua.${LUA_VERSION}.dylib"
