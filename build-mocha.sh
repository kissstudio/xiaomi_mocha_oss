#!/bin/bash

export ARCH="arm"
export KBUILD_BUILD_HOST=$(lsb_release -d | awk -F":"  '{print $2}' | sed -e 's/^[ \t]*//' | sed -r 's/[ ]+/-/g')
export KBUILD_BUILD_USER="arttttt"

clean_build=0
config="mocha_user_defconfig"
dtb_name="tegra124-mocha-prod.dtb"

# config="tegra12_android_defconfig"
# dtb_name="tegra124-mocha.dtb"
dtb_only=0
kernel_name=$(git rev-parse --abbrev-ref HEAD)
cpus_count=$(grep -c ^processor /proc/cpuinfo)

ROOT_DIR=$PWD
OUTPUT_DIR="$ROOT_DIR/out"
BUILDING_DIR=$OUTPUT_DIR/kernel_obj
ANYKERNEL_DIR=$ROOT_DIR/AnyKernel2

ERROR=0
HEAD=1
WARNING=2
mkdir -p $OUT_DIR $BUILDING_DIR
function printfc() {
	if [[ $2 == $ERROR ]]; then
		printf "\e[1;31m$1\e[0m"
		return
	fi;
	if [[ $2 == $HEAD ]]; then
		printf "\e[1;32m$1\e[0m"
		return
	fi;
	if [[ $2 == $WARNING ]]; then
		printf "\e[1;35m$1\e[0m"
		return
	fi;
}

function generate_version()
{
	if [[ -f "$ROOT_DIR/.git/HEAD"  &&  -f "$ANYKERNEL_DIR/anykernel.sh" ]]; then
		local updated_kernel_name
		eval "$(awk -F"="  '/kernel.string/{print "anykernel_name="$2}' $ANYKERNEL_DIR/anykernel.sh)"
		eval "$(echo $kernel_name | awk -F"-"  '{print "current_branch="$2}')"
		if [[ ("$current_branch" == "stable" || "$current_branch" == "staging") ]]; then
			updated_kernel_name=$kernel_name
		else
			if [[ ! -f "$ROOT_DIR/version" ]]; then
				echo "build_number=0" > $ROOT_DIR/version
			fi;

			awk -F"="  '{$2+=1; print $1"="$2}' $ROOT_DIR/version > tmpfile
			mv tmpfile $ROOT_DIR/version
			eval "$(awk -F"="  '{print "current_build="$2}' $ROOT_DIR/version)"
			export LOCALVERSION="-$current_branch-build$current_build"
			updated_kernel_name=$kernel_name"-build"$current_build
		fi;

		if [[ $CI == true ]]; then
			updated_kernel_name="SmokeR24.1"
		fi

		sed -i s/$anykernel_name/$updated_kernel_name/ $ANYKERNEL_DIR/anykernel.sh
	fi;
}

function make_zip()
{
	if [[ -d "$ANYKERNEL_DIR" ]]; then
		printfc "\nCreating a zip archive\n\n" $HEAD
	else
		printfc "\nFolder $ANYKERNEL_DIR does not exist\n\n" $ERROR
		return
	fi;

	if [[ -f "$OUTPUT_DIR/zImage" ]]; then
		if [[ ! -d "$PWD/anykernel/kernel/" ]]; then
			mkdir $PWD/anykernel/kernel/
		fi;
		cp $OUTPUT_DIR/zImage $PWD/anykernel/kernel/
	else
		if [[ $dtb_only == 0 ]]; then
			printfc "file $OUTPUT_DIR/zImage does not exist\n\n" $ERROR
			return
		fi
	fi

	if [[ -f "$OUTPUT_DIR/dts/$dtb_name" ]]; then
		cp $OUTPUT_DIR/dts/$dtb_name $PWD/anykernel/kernel/dtb
	else
		if [[ $dtb_only == 0 ]]; then
			printfc "file $OUTPUT_DIR/dts/$dtb_name does not exist\n\n" $ERROR
			return
		fi
	fi

	cd $ANYKERNEL_DIR

	if [[ $CI == true ]]; then
		zip_name=$KERNEL_ZIP
	else
		zip_name="${kernel_name}_$(date +'%F').zip"
	fi

	zip -r $zip_name *

	if [[ -f "$PWD/$zip_name" ]]; then
		if [[ ! -d "$OUTPUT_DIR" ]]; then
			mkdir $OUTPUT_DIR
		fi;

		printfc "\n$zip_name created, moving to $OUTPUT_DIR" $HEAD
		mv "$PWD/$zip_name" $OUTPUT_DIR

		if [[ -f "$OUTPUT_DIR/$zip_name" ]]; then
			echo
			printfc "\nCompleted\n" $HEAD
		fi
	else
		printfc "\nFailed to create archive\n" $ERROR
		return
	fi
	cd $ROOT_DIR
}

function compile()
{
	local start=$(date +%s)
	clear

	if [[ "$clean_build" == 1 ]]; then
		make clean
		make mrproper
	fi

	generate_version
	make -C $ROOT_DIR O=$BUILDING_DIR $config

	make -C $ROOT_DIR O=$BUILDING_DIR -j$cpus_count ARCH=$ARCH CROSS_COMPILE=$toolchain zImage
	# make V=1 -j$cpus_count ARCH=$ARCH CROSS_COMPILE=$toolchain zImage > build_log_$(date +%F).log 2>&1

	printfc "\nbuild device tree\n\n" $HEAD

	make -C $ROOT_DIR O=$BUILDING_DIR -j$cpus_count ARCH=$ARCH CROSS_COMPILE=$toolchain $dtb_name

	local end=$(date +%s)
	local comp_time=$((end-start))
	printf "\e[1;32m\nkernel is build as %02d:%02d\n\e[0m" $((($comp_time/60)%60)) $(($comp_time%60))
	printfc "build number $current_build in branch $current_branch\n" $HEAD

	make_zip
}

function compile_dtb()
{
	clear

	dtb_only=1
	generate_version
	make $config
	make -j$cpus_count ARCH=$ARCH CROSS_COMPILE=$toolchain $dtb_name

	if [[ -f "$OUTPUT_DIR/dts/$dtb_name" ]]; then
		cp $OUTPUT_DIR/dts/$dtb_name $PWD/anykernel/kernel/dtb
	else
		printfc "file $OUTPUT_DIR/dts/$dtb_name does not exists\n\n" $ERROR
		return
	fi

	make_zip
}

function main()
{
	clear
	echo "---------------------------------------------------"
	echo "Perform a clean build?                            -"
	echo "---------------------------------------------------"
	echo "1 - Yes                                           -"
	echo "---------------------------------------------------"
	echo "2 - No                                            -"
	echo "---------------------------------------------------"
	echo "3 - Build dtb                                     -"
	echo "---------------------------------------------------"
	echo "4 - Quit                                          -"
	echo "---------------------------------------------------"
	printf %s "Your Choice: "
	read env

	case $env in
		1) clean_build=1;compile;;
		2) compile;;
		3) compile_dtb;;
		4) clear;return;;
		*) main;;
	esac
}

if [[ $CI == true ]]; then
	clean_build=1
	toolchain="arm-linux-gnueabihf-"
	compile
else
	toolchain="$HOME/gcc-linaro-arm-linux-gnueabihf-4.8-2014.04_linux/bin/arm-linux-gnueabihf-"
	main
fi
