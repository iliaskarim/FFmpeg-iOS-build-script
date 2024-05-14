#!/bin/sh
set -ex

# dirs
SOURCE="ffmpeg-4.3.1"
SCRATCH="scratch"
THIN=`pwd`/"thin" # must be an absolute path
FAT="FFmpeg-iOS"

rm -rf $SCRATCH
rm -rf $THIN
rm -rf $FAT

ARCHS="arm64 x86_64"
CONFIGURE_FLAGS="--disable-asm \
	--disable-debug \
    --disable-doc \
	--disable-libxcb \
	--disable-programs \
	--enable-avresample \
	--enable-cross-compile \
	--enable-gpl
	--enable-pic \
	--enable-postproc"
DEPLOYMENT_TARGET="16.4"

if [ ! -r $SOURCE ]; then
	echo 'FFmpeg source not found. Trying to download...'
	curl https://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj
fi

CWD=`pwd`
for ARCH in $ARCHS; do
	echo "building $ARCH..."
	mkdir -p "$SCRATCH/$ARCH"
	cd "$SCRATCH/$ARCH"

	CFLAGS="-arch $ARCH"
	CC="xcrun -sdk macosx clang"

	# force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.3)
	if [ "$ARCH" = "arm64" ]; then
		AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		EXPORT="GASPP_FIX_XCODE5=1"
	else
		AS="gas-preprocessor.pl -- $CC"
	fi

	LDFLAGS="$CFLAGS"

	TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
		--target-os=darwin \
		--arch=$ARCH \
		--cc="$CC" \
		--as="$AS" \
		$CONFIGURE_FLAGS \
		--extra-cflags="$CFLAGS" \
		--extra-ldflags="$LDFLAGS" \
		--prefix="$THIN/$ARCH" &>/dev/null

	make -j3 install $EXPORT  >/dev/null 2>build.log
	cd $CWD
done

echo "building fat binaries..."
mkdir -p $FAT/lib
set - $ARCHS
CWD=`pwd`
cd $THIN/$1/lib
for LIB in *.a; do
	cd $CWD
	lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
done

cd $CWD
cp -rf $THIN/$1/include $FAT

echo Done
