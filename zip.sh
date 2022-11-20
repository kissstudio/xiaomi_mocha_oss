ROOT_DIR=$(pwd)
OUT_DIR=$ROOT_DIR/out
MODULES_DIR=$OUT_DIR/modules
ANYKERNEL_DIR=$ROOT_DIR/AnyKernel2
OUT_FILE=MochaKernel-$(date +%F).zip




FUNC_MAKEZIP()
{
    if [ -d $ANYKERNEL_DIR/.github ];then
        cd $ANYKERNEL_DIR && git clean -fd
        cd ..
    else    
        echo -e "\e[95mCloning AnyKernel2 git..."
        git clone --depth=1 "https://github.com/osm0sis/AnyKernel2" $ANYKERNEL_DIR
    fi
	echo -e "\e[95mModifying it for your device..."
	FILE=$ANYKERNEL_DIR/anykernel.sh
	cp $MODULES_DIR/* $ANYKERNEL_DIR/modules/
	/bin/cat << EOF >$FILE
    kernel.string=Kernel by Nihhaar @ xda-developers
    
    do.devicecheck=1
    do.initd=1
    do.modules=1
    do.cleanup=1
    device.name1=mocha

    #Boot Partition
    block=/dev/block/platform/sdhci-tegra.3/by-name/LNX;
    is_slot_device=0;

    ## AnyKernel methods (DO NOT CHANGE)
    # import patching functions/variables - see for reference
    . /tmp/anykernel/tools/ak2-core.sh;
    
    
    ## AnyKernel permissions
    # set permissions for included ramdisk files
    chmod -R 755 $ramdisk
    chmod 644 $ramdisk/sbin/media_profiles.xml
    
    
    ## AnyKernel install
    dump_boot;
    write_boot;
    
    ## end install
EOF
	echo -e "\e[95mMaking kernel.zip file..."
	cd AnyKernel2
	rm -rf zImage
	cp $OUT_DIR/zImage zImage && echo "...zImage file copied."
    if [ -f $OUT_DIR/dtb ];then 
        mkdir -p $ANYKERNEL_DIR/kernel
        cp $OUT_DIR/dtb $ANYKERNEL_DIR/kernel/dtb && echo "...dtb file copied."
        
    fi
    echo "...zip archive"
	zip -r9 $OUT_FILE * -x README $OUT_FILE > ../zip.output 2>&1
	mv $OUT_FILE $OUT_DIR
	cd ..
	echo -e "\e[34mzip compression Done! $OUT_DIR/$OUT_FILE.\n"
	
}
FUN_ADB_PUSH(){
    echo -e -n "\e[33madb push to /sdcard (y/n)? "
    old_stty_cfg=$(stty -g)
    stty raw -echo
    answer=$( while ! head -c 1 | grep -i '[ny]' ;do true ;done )
    stty $old_stty_cfg

    if echo "$answer" | grep -iq "^y" ;then
        echo -e "\n"
        adb push $OUT_DIR/$OUT_FILE /sdcard
        return 0
    else
        echo -e "...user canceled.\n"
        return 0
    fi
}

FUNC_MAKEZIP
FUN_ADB_PUSH
