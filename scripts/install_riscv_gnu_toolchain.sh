#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${repo_root}/build/riscv-gnu-toolchain/src"
build_root="${repo_root}/build/riscv-gnu-toolchain/build"
default_install_dir="${repo_root}/build/riscv-gnu-toolchain/install"
source_url="git@github.com:seawyvern/riscv-gnu-toolchain.git"
source_branch="master"
gdb_dir="${source_dir}/gdb"
# GDB 17.2 lacks upstream binutils-gdb commit 5f66aee7; backport it here.
gprofng_patch="${repo_root}/scripts/patches/gprofng-call-util.patch"

remove_applied_gprofng_patch() {
  if [[ -e "${gdb_dir}/.git" ]] &&
     ! git -C "$gdb_dir" diff --quiet -- gprofng/src/collector_module.h &&
     git -C "$gdb_dir" apply --reverse --check "$gprofng_patch"; then
    git -C "$gdb_dir" apply --reverse "$gprofng_patch"
  fi
}

if [[ -n "${RISCV_GNU_TOOLCHAIN_INSTALL_DIR:-}" ]]; then
  install_dir="$RISCV_GNU_TOOLCHAIN_INSTALL_DIR"
elif [[ -t 0 ]]; then
  printf 'Install RISC-V GNU toolchain at [%s]: ' "$default_install_dir" >&2
  IFS= read -r install_dir
  install_dir="${install_dir:-$default_install_dir}"
else
  install_dir="$default_install_dir"
fi

case "$install_dir" in
  '~') install_dir="$HOME" ;;
  '~/'*) install_dir="$HOME/${install_dir:2}" ;;
esac
if [[ "$install_dir" != /* ]]; then
  printf 'Install path must be absolute (or start with ~/): %s\n' "$install_dir" >&2
  exit 1
fi

source "${repo_root}/scripts/lib/validate_build_paths.sh"
validate_build_paths "$repo_root" "$install_dir"

missing_tools=()
for tool in git make gcc g++ autoconf automake bison flex gawk makeinfo \
            gperf libtoolize bc patch curl python3 nproc; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done
if ((${#missing_tools[@]})); then
  printf 'Missing tools required to build the RISC-V GNU toolchain: %s\n' \
    "${missing_tools[*]}" >&2
  if command -v apt-get >/dev/null 2>&1; then
    printf 'On Ubuntu/Debian, install the prerequisites listed by the toolchain README:\n' >&2
    printf '  sudo apt-get update\n' >&2
    printf '  sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev meson ninja-build git cmake libglib2.0-dev expect device-tree-compiler libslirp-dev libzstd-dev libncurses-dev\n' >&2
  else
    printf 'Install the missing tools with your system package manager, then rerun this script.\n' >&2
  fi
  exit 1
fi

jobs="${RISCV_GNU_TOOLCHAIN_JOBS:-$(nproc)}"
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  printf 'RISCV_GNU_TOOLCHAIN_JOBS must be a positive integer: %s\n' "$jobs" >&2
  exit 1
fi

mkdir -p "$(dirname "$source_dir")"
if [[ ! -d "${source_dir}/.git" ]]; then
  if [[ -e "$source_dir" ]]; then
    printf 'Source directory already exists and is not a Git checkout: %s\n' "$source_dir" >&2
    exit 1
  fi
  git clone --filter=blob:none "$source_url" "$source_dir"
fi

if [[ "$(git -C "$source_dir" remote get-url origin)" != "$source_url" ]]; then
  printf 'Unexpected toolchain source remote in %s\n' "$source_dir" >&2
  exit 1
fi
remove_applied_gprofng_patch
if [[ -n "$(git -C "$source_dir" status --porcelain)" ]]; then
  printf 'Toolchain source has local changes: %s\n' "$source_dir" >&2
  exit 1
fi

git -C "$source_dir" fetch origin "$source_branch"
source_commit="$(git -C "$source_dir" rev-parse 'FETCH_HEAD^{commit}')"
git -C "$source_dir" checkout --detach "$source_commit"
git -C "$source_dir" submodule update --init gdb
if ! git -C "$gdb_dir" apply --check "$gprofng_patch"; then
  printf 'gprofng source patch no longer applies; review the GDB submodule revision\n' >&2
  exit 1
fi
git -C "$gdb_dir" apply "$gprofng_patch"
trap remove_applied_gprofng_patch EXIT

build_dir="${build_root}/${source_commit}"
if [[ -f "${build_dir}/Makefile" ]] &&
   ! grep -Fxq "INSTALL_DIR := ${install_dir}" "${build_dir}/Makefile"; then
  printf 'Build directory was configured for another install path: %s\n' "$build_dir" >&2
  exit 1
fi
if [[ -e "$install_dir" && ! -d "$install_dir" ]]; then
  printf 'Install path is not a directory: %s\n' "$install_dir" >&2
  exit 1
fi
if [[ -d "$install_dir" && ! -d "$build_dir" &&
      -n "$(find "$install_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  printf 'Install directory is not empty; use an empty directory for a new toolchain version: %s\n' "$install_dir" >&2
  exit 1
fi

mkdir -p "$build_dir"
(
  cd "$build_dir"
  "${source_dir}/configure" --prefix="$install_dir" \
    --with-arch=rv64g --with-abi=lp64d --with-cmodel=medany
)
printf 'Building Newlib in %s\n' "$build_dir"
make -C "$build_dir" -j "$jobs" newlib
printf 'Newlib build completed\n'
printf 'Building Linux in %s\n' "$build_dir"
make -C "$build_dir" -j "$jobs" linux
printf 'Linux build completed\n'
if [[ ! -x "${install_dir}/bin/riscv64-unknown-elf-gcc" ||
      ! -x "${install_dir}/bin/riscv64-unknown-linux-gnu-gcc" ]]; then
  printf 'Toolchain build finished without installing both Newlib and Linux compilers\n' >&2
  exit 1
fi

printf '%s\n' "$source_commit"
for compiler in riscv64-unknown-elf-gcc riscv64-unknown-linux-gnu-gcc; do
  compiler_version="$("${install_dir}/bin/${compiler}" --version)"
  printf '%s\n' "${compiler_version%%$'\n'*}"
done
printf 'Installed at %s\n' "$install_dir"
printf 'Use %s/bin in PATH\n' "$install_dir"
