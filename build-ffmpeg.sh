#!/bin/sh
set -e

# dirs
SOURCE="ffmpeg-4.3.1"
SCRATCH="scratch"
THIN=`pwd`/"thin" # must be an absolute path
FAT="FFmpeg"

rm -rf $SCRATCH
rm -rf $THIN
rm -rf $FAT

ARCHS="arm64 x86_64"
CONFIGURE_FLAGS="--disable-asm --disable-debug --disable-doc --disable-libxcb --disable-programs --enable-avresample --enable-cross-compile --enable-gpl --enable-pic --enable-postproc"

if [ ! -r $SOURCE ]; then
	echo 'FFmpeg source not found. Trying to download...'
	curl https://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj
fi

CWD=`pwd`
for ARCH in $ARCHS; do
	echo "building $ARCH..."
	mkdir -p "$SCRATCH/$ARCH"
	cd "$SCRATCH/$ARCH"

	CC="xcrun -sdk macosx clang"
	CFLAGS="-arch $ARCH"
	LDFLAGS="$CFLAGS"

	TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
		--target-os=darwin \
		--arch=$ARCH \
		--cc="$CC" \
		$CONFIGURE_FLAGS \
		--extra-cflags="$CFLAGS" \
		--extra-ldflags="$LDFLAGS" \
		--prefix="$THIN/$ARCH" &>/dev/null

	make -j3 install >/dev/null 2>build.log
	cd $CWD
done

echo "building fat binaries..."
mkdir -p $FAT/lib
CWD=`pwd`
set - $ARCHS
cd $THIN/$1/lib
for LIB in *.a; do
	cd $CWD
	lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
done

cd $CWD
cp -rf $THIN/$1/include $FAT
cp $SCRATCH/$1/config.h $FAT

echo Done
