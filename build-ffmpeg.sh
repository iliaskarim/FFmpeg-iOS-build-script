#!/bin/sh
set -ex

# directories
FF_VERSION="4.3.1"
SOURCE="ffmpeg-$FF_VERSION"
FAT="FFmpeg-iOS"
SCRATCH="scratch"
THIN=`pwd`/"thin" # must be an absolute path

rm -rf $SCRATCH
rm -rf $THIN

CONFIGURE_FLAGS="--enable-cross-compile --disable-debug --disable-programs \
                 --disable-doc --enable-pic"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-audiotoolbox"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avresample"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-postproc --enable-gpl --disable-asm"

CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-libxcb"
# ARCHS="arm64"
# ARCHS="x86_64"
ARCHS="arm64 x86_64"

COMPILE="y"
LIPO="y"

# DEPLOYMENT_TARGET="8.0"
DEPLOYMENT_TARGET="16.4"


if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	# if [ ! `which yasm` ]
	# then
	# 	echo 'Yasm not found'
	# 	if [ ! `which brew` ]
	# 	then
	# 		echo 'Homebrew not found. Trying to install...'
    #                     ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
	# 			|| exit 1
	# 	fi
	# 	echo 'Trying to install Yasm...'
	# 	brew install yasm || exit 1
	# fi
	
	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		curl https://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
			|| exit 1
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		# if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		# then
		#     PLATFORM="iPhoneSimulator"
		#     CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		# else
		#     PLATFORM="iPhoneOS"
		#     CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		#     if [ "$ARCH" = "arm64" ]
		#     then
		        EXPORT="GASPP_FIX_XCODE5=1"
		#     fi
		# fi

		XCRUN_SDK=macosx
		# XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		# CC="clang"

		# force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.3)
		if [ "$ARCH" = "arm64" ]
		then
		    AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		else
		    AS="gas-preprocessor.pl -- $CC"
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"
		if [ "$X264" ]
		then
			CFLAGS="$CFLAGS -I$X264/include"
			LDFLAGS="$LDFLAGS -L$X264/lib"
		fi
		if [ "$FDK_AAC" ]
		then
			CFLAGS="$CFLAGS -I$FDK_AAC/include"
			LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		fi

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
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

echo Done
