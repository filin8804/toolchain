#!/bin/bash

TARGET="x86_64"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd)"
DIR="$(readlink -f "$DIR/..")"

echo "Adding ldd symlink..."
ln -fs "$DIR/lib/libc.so" "$DIR/bin/ldd"

echo "Setup paths for dynamic linker..."
echo "$DIR/lib:$DIR/local/lib" > "$DIR/etc/ld-musl-$TARGET.path"
