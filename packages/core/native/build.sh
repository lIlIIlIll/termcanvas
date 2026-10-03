#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
# Parallel downstream builds publish only complete archives.
scratch=$(mktemp -d build/spawn.XXXXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
"${CC:-cc}" -std=c11 -O2 -fPIC -Wall -Wextra -Werror -c spawn.c -o "$scratch/spawn.o"
"${AR:-ar}" rcs "$scratch/libtermcanvas_posix.a" "$scratch/spawn.o"
mv "$scratch/libtermcanvas_posix.a" build/libtermcanvas_posix.a
