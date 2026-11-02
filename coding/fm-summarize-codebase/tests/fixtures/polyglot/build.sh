#!/usr/bin/env bash
set -euo pipefail

# Prints usage.
usage() {
  echo "usage: ${0##*/} [-h]"
}

function cleanup {
  rm -rf "$TMP"
}

function build() (
  cd src && make
)

main() {
  local n=${#ARR[@]}
  usage
  cleanup
}

main "$@"
