ROOT_DIR=$(pwd)
OUT_DIR=$ROOT_DIR/out
MODULES_DIR=$OUT_DIR/modules
ANYKERNEL_DIR=$ROOT_DIR/AnyKernel2

FUNC_MAKEZIP()
{
	echo -e "\e[95mCloning AnyKernel2 git..."
	git clone "https://github.com/osm0sis/AnyKernel2" $ANYKERNEL_DIR
	echo -e "\e[95mModifying it for your device..."
	FILE=$ROOT_DIR/AnyKernel2/anykernel.sh
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
	cp $OUT_DIR/zImage zImage
	zip -r9 MochaKernel-$(date +%F).zip * -x README MochaKernel-$(date +%F).zip
	mv MochaKernel-$(date +%F).zip $OUT_DIR
	cd ..
	echo -e "\e[34mDone! Now Collect ur zip file.\n"
	
}

FUNC_MAKEZIP
