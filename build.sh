#!/bin/bash
ROOT_DIR=$(pwd)
export ARCH=arm
DEFCONFIG=mocha_user_defconfig
dtb_name="tegra124-mocha-prod.dtb"
CROSS_COMPILER=$ROOT_DIR/toolchain/arm-eabi-5.3/bin/arm-eabi-
OUT_DIR=$ROOT_DIR/out
BUILDING_DIR=$OUT_DIR/kernel_obj
MODULES_DIR=$OUT_DIR/modules
ANYKERNEL_DIR=$ROOT_DIR/AnyKernel2
JOBS=16 #2 x Number of cores
mkdir -p $OUT_DIR $BUILDING_DIR $MODULES_DIR

# prepare using defconfig
make -C $ROOT_DIR O=$BUILDING_DIR ARCH=$ARCH $DEFCONFIG
FUNC_CLEANUP()
{
	echo -e -n "\n\e[95mCleaning up..."
	make mrproper
	rm -rf $OUTPUT_DIR
	rm -f $ROOT_DIR/arch/arm/boot/dts/$dtb_name
	mkdir -p $OUT_DIR $BUILDING_DIR $MODULES_DIR
	echo -e "\e[34mAll clean!"
}

FUNC_COMPILE()
{
	echo -e -n "\n\e[95mStarting the build..."
	
	# actually make things
	make -j$JOBS -C $ROOT_DIR O=$BUILDING_DIR ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILER
	cp $BUILDING_DIR/arch/arm/boot/zImage $OUT_DIR/zImage
	echo -e "\e[34mJob done!"

	

	echo -e -n "\n\e[95mCopying the Modules..."
	rm -rf $MODULES_DIR
	mkdir $MODULES_DIR
	find . -name "*.ko" -exec cp {} $MODULES_DIR \;
	echo -e "\e[34m...compile done!"

	FUNC_MAKEZIP
}

FUNC_MAKEZIP()
{
	printf "\nbuild device tree\n\n" $HEAD
	make -C $ROOT_DIR O=$BUILDING_DIR ARCH=$ARCH $dtb_name CROSS_COMPILE=$CROSS_COMPILER
	
	`echo -e -n "\n\e[95mcopying dtb file..."`
	cp $BUILDING_DIR/arch/arm/boot/dts/$dtb_name $OUT_DIR/dtb

	sh $ROOT_DIR/zip.sh
}

echo -e "\e[33mDo you want to clean build directory (y/n)? "
old_stty_cfg=$(stty -g)
stty raw -echo
answer=$( while ! head -c 1 | grep -i '[ny]' ;do true ;done )
stty $old_stty_cfg

if echo "$answer" | grep -iq "^y" ;then
    FUNC_CLEANUP
    FUNC_COMPILE
else
    rm -r $OUT_DIR/zImage
    FUNC_COMPILE
fi
