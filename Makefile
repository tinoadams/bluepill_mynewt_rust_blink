OPENOCD_HOST := "192.168.10.197"
OPENOCD_TARGET_DIR := '/home/pi'

PLATFORM := thumbv7m-none-eabi

clean:
	cargo clean
	cd mynewt && newt clean -v all

build: build-mynewt build-rust
	# package the Rust app+deps as one big ARM lib archive
	mkdir -p tmprustlib && rm -rf tmprustlib/*
	cd tmprustlib && \
		for i in $(PWD)/target/$(PLATFORM)/debug/deps/*.rlib; do arm-none-eabi-ar x $$i; done && \
		arm-none-eabi-ar r rustlib.a *.o || echo "No dependencies"
	# override the Mynewt Rust app stub
	[ -f tmprustlib/rustlib.a ] && cp -a tmprustlib/rustlib.a \
		mynewt/bin/targets/firmware/app/libs/rust_app/libs_rust_app.a || echo "..."
	# copy the Rust core lib to Mynewt by overriding the stub
	cp -a `rustc --print sysroot --target $(PLATFORM)`/lib/rustlib/$(PLATFORM)/lib/libcore-*.rlib \
		mynewt/bin/targets/firmware/app/libs/rust_libcore/libs_rust_libcore.a
	# force Mynewt to link app again using injected Rust libs
	rm mynewt/bin/targets/firmware/app/apps/firmware/firmware.*
	cd mynewt && \
		newt build firmware && \
		newt create-image -v firmware 1.0.0 -2

build-rust:
	RUST_BACKTRACE=full cargo build --target $(PLATFORM) -Z features=build_dep

build-mynewt: mynewt/repos
	cd mynewt && \
		for target in `ls targets`; do newt build "$$target" || echo "ignoring error... Rust code needs to be injected first"; done

mynewt/repos: 
	make mynewt-install

mynewt-install:
	cd mynewt && newt install || echo '...'
    
	# weird thing that the default Mynewt version contains modified files which prevent repos from upgrading
	cd mynewt/repos/mcuboot && git clean -f -x -d ; rm -rf ext/mbedtls/include/mbedtls
	# change repo Git config to prevent error when Windows docker is changing file modes
	for i in mynewt/repos/*; do cd $$i && git config core.fileMode false ; cd -; done
	
	cd mynewt && \
		newt target create firmware && \
		newt target set firmware bsp=@apache-mynewt-core/hw/bsp/bluepill && \
		newt target set firmware app=apps/firmware && \
		newt target set firmware build_profile=debug || echo "already exists"

	cd mynewt && \
		newt target create mcu_boot && \
		newt target set mcu_boot bsp=@apache-mynewt-core/hw/bsp/bluepill && \
		newt target set mcu_boot app=@mcuboot/boot/mynewt && \
		newt target set mcu_boot build_profile=optimized || echo "already exists"

	cd mynewt && newt upgrade -f

run-renode:
	docker run -v `pwd`:/workspace -w /workspace --rm -it -p 5000:5000 antmicro/renode \
		renode -P 5000 --disable-xwt -e 's @/workspace/renode/firmware.resc'

flash-st-link: copy-bins
	openocd -f openocd/st-link.ocd -f openocd/flash-init.ocd -f openocd/flash-boot.ocd -f openocd/flash-app.ocd -c exit

flash-rpi: copy-bins
	# run on shell: echo -e "\x1dclose\x0d" > openocd/close-telnet.txt
	
	# copy the folder including binaries to the openocd host
	scp -r openocd pi@$(OPENOCD_HOST):$(OPENOCD_TARGET_DIR)
	# make sure OpenOCD is running in the $(OPENOCD_TARGET_DIR) directory on the host for file paths in the intruction files to be correct
	# eg. cd $(OPENOCD_TARGET_DIR) && sudo openocd -f openocd/bitbang-swd.ocd
	{ cat openocd/flash-init.ocd openocd/flash-boot.ocd openocd/flash-app.ocd; sleep 5; cat openocd/close-telnet.txt ;} \
		| telnet $(OPENOCD_HOST) 4444 2>&1 3>&1 | tee flash-rpi.log
	# check for error in log
	grep -ai 'failed' flash-rpi.log && (echo "ERROR flashing device, check flash-rpi.log"; exit 1) || echo "DONE"

copy-bins:
	mkdir -p openocd/bin && rm -rf openocd/bin/*
	cp -a mynewt/bin/targets/mcu_boot/app/@mcuboot/boot/mynewt/mynewt.elf.bin openocd/bin/
	cp -a mynewt/bin/targets/firmware/app/apps/firmware/firmware.img openocd/bin/
	# ELF for debugging purposes
	cp -a mynewt/bin/targets/mcu_boot/app/@mcuboot/boot/mynewt/mynewt.elf openocd/bin/
	cp -a mynewt/bin/targets/firmware/app/apps/firmware/firmware.elf openocd/bin/

gdb:
	#break repos/apache-mynewt-core/kernel/os/src/os.c:262
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/os_arch_arm.c:297
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/os_arch_arm.c:274
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/m3/HAL_CM3.s:101
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/os_arch_arm.c:252
	#break repos/apache-mynewt-core/kernel/os/src/os.c:236
	#break rust/app/src/lib.rs:21
	#break rust/app/src/lib.rs:25

	( echo "target remote | openocd -f openocd/debug.ocd -c 'gdb_port pipe; log_output openocd/openocd.log'" ; echo "monitor reset halt" ; echo "load" ; cat ) | \
		gdb-multiarch -iex 'add-auto-load-safe-path .' mynewt/bin/targets/firmware/app/apps/firmware/firmware.elf
