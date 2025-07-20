#!/bin/sh
SCRIPT_DIR=$(dirname $0)
echo "$( \
	echo "#include \"sqlite3.h\"" &&
	echo "int luaopen_cffi(void*);" &&
	emcc $SCRIPT_DIR/fake_dlfcn.c -DLIBRARY_TABLES="$( \
		$SCRIPT_DIR/mk_symtbl.sh cffi.a:libcffi-lua-5.1.a libsqlite3.a:sqlite3.o
	)" -E
)" | emcc -xc - -c -o fake_dlfcn.o -O3
