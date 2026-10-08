#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${repo_root}/build/qemu/src"
source_url="https://github.com/seawyvern/qemu.git"
source_commit="4fc49f46dc95d4a27de2509e7fceb2931e91faeb"
source_version="11.1.2"
build_dir="${repo_root}/build/qemu/build/${source_commit}"
default_install_dir="${repo_root}/build/qemu/install"

if [[ -n "${QEMU_INSTALL_DIR:-}" ]]; then
  install_dir="$QEMU_INSTALL_DIR"
elif [[ -t 0 ]]; then
  printf 'Install QEMU %s to [%s]: ' "$source_version" "$default_install_dir" >&2
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
for tool in git make gcc g++ python3 pkg-config ninja nproc realpath; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done
if ((${#missing_tools[@]})); then
  printf 'Missing tools required to build QEMU: %s\n' "${missing_tools[*]}" >&2
  printf 'On Ubuntu/Debian, install the build prerequisites with:\n' >&2
  printf '  sudo apt-get update\n' >&2
  printf '  sudo apt-get install git build-essential python3 python3-venv python3-pip python3-setuptools python3-wheel pkg-config ninja-build coreutils libglib2.0-dev zlib1g-dev libfdt-dev\n' >&2
  exit 1
fi

install_dir="$(realpath -m "$install_dir")"
validate_build_paths "$install_dir"
for work_dir in "$source_dir" "$build_dir"; do
  work_dir="$(realpath -m "$work_dir")"
  if [[ "$install_dir" == "$work_dir" || "$install_dir" == "$work_dir/"* ||
        "$work_dir" == "$install_dir/"* || "$install_dir" == / ]]; then
    printf 'Install path overlaps the source or build directory: %s\n' "$install_dir" >&2
    exit 1
  fi
done

jobs="${QEMU_JOBS:-$(nproc)}"
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  printf 'QEMU_JOBS must be a positive integer: %s\n' "$jobs" >&2
  exit 1
fi

verify_install() {
  local version machines
  [[ -x "${install_dir}/bin/qemu-system-riscv64" ]] || return 1
  version="$("${install_dir}/bin/qemu-system-riscv64" --version)" || return 1
  version="${version%%$'\n'*}"
  [[ "$version" == "QEMU emulator version ${source_version}" ||
     "$version" == "QEMU emulator version ${source_version} "* ]] || return 1
  machines="$("${install_dir}/bin/qemu-system-riscv64" -machine help)" || return 1
  [[ "$machines" =~ (^|$'\n')virt[[:space:]] ]] || return 1
  printf '%s\n' "${version%%$'\n'*}"
}

if [[ -f "${install_dir}/.source-commit" ]] &&
   [[ "$(cat "${install_dir}/.source-commit")" == "$source_commit" ]] &&
   verify_install; then
  printf 'Already installed at %s\n' "$install_dir"
  exit 0
fi

if ! python3 -c 'import sys, venv; sys.exit(sys.version_info < (3, 9))'; then
  printf 'QEMU requires Python >= 3.9 with venv support.\n' >&2
  exit 1
fi
if ! pkg-config --atleast-version=2.66.0 glib-2.0 || ! pkg-config --exists zlib; then
  printf 'QEMU requires GLib >= 2.66.0 and zlib development packages.\n' >&2
  printf 'On Ubuntu/Debian: sudo apt-get install libglib2.0-dev zlib1g-dev\n' >&2
  exit 1
fi
if [[ -e "$install_dir" && ! -d "$install_dir" ]]; then
  printf 'Install path is not a directory: %s\n' "$install_dir" >&2
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
  printf 'Unexpected QEMU source remote in %s\n' "$source_dir" >&2
  exit 1
fi
if [[ -n "$(git -C "$source_dir" status --porcelain)" ]]; then
  printf 'QEMU source has local changes: %s\n' "$source_dir" >&2
  exit 1
fi
if ! git -C "$source_dir" cat-file -e "${source_commit}^{commit}" 2>/dev/null; then
  git -C "$source_dir" fetch origin "$source_commit"
fi
git -C "$source_dir" checkout --detach "$source_commit"
if [[ "$(cat "${source_dir}/VERSION")" != "$source_version" ]]; then
  printf 'Unexpected QEMU version at pinned commit\n' >&2
  exit 1
fi

mkdir -p "$build_dir"
(
  cd "$build_dir"
  "${source_dir}/configure" --prefix="$install_dir" \
    --target-list=riscv64-softmmu --without-default-features \
    --enable-tcg --enable-fdt --disable-docs
  make -j "$jobs"
  make install
)

if ! verify_install; then
  printf 'Installation did not produce QEMU %s with the RISC-V virt machine\n' "$source_version" >&2
  exit 1
fi
printf '%s\n' "$source_commit" > "${install_dir}/.source-commit"
printf 'Installed at %s\n' "${install_dir}/bin/qemu-system-riscv64"
printf 'Use %s/bin in PATH\n' "$install_dir"
