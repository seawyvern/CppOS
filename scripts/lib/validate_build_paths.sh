#!/usr/bin/env bash

# Configure-generated build recipes do not consistently quote paths.
validate_build_paths() {
  local LC_ALL=C
  local build_path
  for build_path in "$@"; do
    if [[ ! "$build_path" =~ ^/[a-zA-Z0-9/._+-]*$ ]]; then
      printf 'Build and install paths must be absolute and use only ASCII letters, digits, /, ., _, +, and -: %q\n' \
        "$build_path" >&2
      return 1
    fi
  done
}
