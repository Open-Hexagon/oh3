#!/bin/bash
function build_luv() {
	ABI=$1
	API_LEVEL=$3
	NDK_PREFIX=${2}${API_LEVEL}-
	BIT=$4
	echo "Building luv for $ABI..."

	# Luajit
	echo "Building luajit..."
	cd deps/luajit
	make clean
	NDKDIR=$ANDROID_NDK
	NDKBIN=$NDKDIR/toolchains/llvm/prebuilt/linux-x86_64/bin
	NDKCROSS=$NDKBIN/$NDK_PREFIX
	NDKCC=$NDKBIN/${NDK_PREFIX}clang
	make HOST_CC="gcc -m$BIT" CROSS=$NDKCROSS \
	     STATIC_CC=$NDKCC DYNAMIC_CC="$NDKCC -fPIC" \
	     TARGET_LD=$NDKCC TARGET_AR="$NDKBIN/llvm-ar rcus" \
	     TARGET_STRIP=$NDKBIN/llvm-strip
	cd ../..
	echo "Done."

	# cmake
	echo "Running cmake configure..."
	mkdir -p build-$ABI
	cd build-$ABI
	cmake -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API_LEVEL -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DCMAKE_ANDROID_NDK_TOOLCHAIN_VERSION=clang -DCMAKE_SYSTEM_NAME=Android -DCMAKE_ANDROID_NDK=$ANDROID_NDK -DCMAKE_ANDROID_STL_TYPE=c++_static -DLUA_BUILD_TYPE=System -DLUAJIT_INCLUDE_DIR=../deps/luajit/src -DLUAJIT_LIBRARIES=../deps/luajit/src/libluajit.a ..
	echo "Done."

	# make
	echo "Building with make..."
	make
	echo "Done."

	# move lib
	cd ..
	mkdir -p libs/$ABI
	mv build-$ABI/luv.so ../love-anroid/app/src/main/jniLibs/$ABI/libluv.so
}

if [ -z "$ANDROID_NDK" ]; then
    echo "Need to set ANDROID_NDK"
    exit 1
fi
API=29
if [ -d "luv" ]; then
  echo "'luv' dir exists, redoing aborted build."
else
  echo "Cloning luv..."
  git clone https://github.com/luvit/luv --recursive
  echo "Done."
  # Fix linking issue
  echo "Applying patch to CMakeLists.txt"
  echo '
	--- a/CMakeLists.txt
	+++ b/CMakeLists.txt
	@@ -261,7 +261,7 @@ foreach(TARGET_NAME ${ACTIVE_TARGETS})
	   elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
	     target_link_libraries(${TARGET_NAME} ${LIBUV_LIBRARIES} rt)
	   else()
	-    target_link_libraries(${TARGET_NAME} ${LIBUV_LIBRARIES})
	+    target_link_libraries(${TARGET_NAME} ${LIBUV_LIBRARIES} ${LUAJIT_LIBRARIES})
	   endif()
	 endforeach()
  ' > luv.patch
  patch luv/CMakeLists.txt luv.patch
  rm luv.patch
  echo "Done."
fi
cd luv
build_luv armeabi-v7a armv7a-linux-androideabi $API 32
build_luv arm64-v8a aarch64-linux-android $API 64
build_luv x86 i686-linux-android $API 32
build_luv x86_64 x86_64-linux-android $API 64
