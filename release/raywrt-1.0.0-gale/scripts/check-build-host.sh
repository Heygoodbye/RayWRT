#!/bin/sh
set -eu

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[ "$(uname -s 2>/dev/null || true)" = Linux ] || fail 'Linux is required; Windows builds are unsupported.'
pass "Linux host: $(uname -sr)"

arch=$(uname -m)
case "$arch" in x86_64|amd64) pass "Host architecture: $arch";; *) fail "x86_64 host required; found $arch";; esac

for tool in git make gcc g++ ld python3 perl rsync tar xz zstd curl wget sha256sum awk sed grep find patch; do
	command -v "$tool" >/dev/null 2>&1 || fail "Missing required command: $tool"
done
pass 'Required compiler and build tools are present'

free_kb=$(df -Pk "${1:-$PWD}" | awk 'NR==2 {print $4}')
[ -n "$free_kb" ] || fail 'Could not determine free disk space.'
[ "$free_kb" -ge 41943040 ] || fail "At least 40 GiB free disk is required; found $((free_kb / 1024 / 1024)) GiB."
pass "Free disk: $((free_kb / 1024 / 1024)) GiB"

mem_kb=$(awk '/MemTotal:/ {print $2; exit}' /proc/meminfo)
[ -n "$mem_kb" ] || fail 'Could not determine RAM.'
[ "$mem_kb" -ge 8388608 ] || fail "At least 8 GiB RAM is required; found $((mem_kb / 1024 / 1024)) GiB."
pass "RAM: $((mem_kb / 1024 / 1024)) GiB"

for package in build-essential clang flex bison gawk gettext git libncurses-dev libssl-dev \
	python3-dev python3-setuptools rsync subversion swig unzip zlib1g-dev file wget bc \
	libelf-dev liblzma-dev libxml-parser-perl xsltproc zstd gcc-multilib g++-multilib; do
	dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -qx 'install ok installed' ||
		fail "Missing Ubuntu build dependency: $package"
done
pass 'Required OpenWrt Ubuntu build dependencies are installed'

printf 'PASS: build host checks complete\n'
