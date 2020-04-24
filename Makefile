## These config vals also need to be set in .vscode/launch.json
OPENOCD_SSH_KEY := /home/tinada/rsa_id
OPENOCD_HOST := 192.168.10.197

PLATFORM := thumbv7m-none-eabi

clean:
	cargo clean
	cd mynewt && newt clean -v all

build: build-rust build-newt
	# package the Rust app+deps as one big ARM lib archive
	mkdir -p tmprustlib && rm -rf tmprustlib/*
	cd tmprustlib && \
		for i in $(PWD)/target/$(PLATFORM)/debug/deps/*.rlib; do arm-none-eabi-ar x $$i; done && \
		arm-none-eabi-ar r rustlib.a *.o || echo "No dependencies"
	# override the Mynewt Rust app stub
	[ -f tmprustlib/rustlib.a ] && cp -a tmprustlib/rustlib.a \
		mynewt/bin/targets/bluepill_app/app/libs/rust_app/libs_rust_app.a || echo "..."
	# copy the Rust core lib to Mynewt by overriding the stub
	cp -a `rustc --print sysroot --target $(PLATFORM)`/lib/rustlib/$(PLATFORM)/lib/libcore-*.rlib \
		mynewt/bin/targets/bluepill_app/app/libs/rust_libcore/libs_rust_libcore.a
	# force Mynewt to link app again using injected Rust libs
	rm mynewt/bin/targets/bluepill_app/app/apps/blinky/blinky.*
	cd mynewt && \
		newt build bluepill_app && \
		newt create-image -v bluepill_app 1.0.0 -2

build-rust:
	RUST_BACKTRACE=full cargo build --target $(PLATFORM)

build-newt: mynewt/repos
	cd mynewt && \
		for target in `ls targets`; do newt build "$$target"; done

mynewt/repos: 
	make newt-install

newt-install:
	cd mynewt && newt install || echo '...'
    
	# weird thing that the default Mynewt version contains modified files which prevent repos from upgrading
	cd mynewt/repos/mcuboot && git clean -f -x -d || echo '...'
	# change repo Git config to prevent error when Windows docker is changing file modes
	for i in mynewt/repos/*; do cd $$i && git config core.fileMode false ; cd -; done
	
	cd mynewt && \
		newt target create bluepill_app && \
		newt target set bluepill_app bsp=@apache-mynewt-core/hw/bsp/bluepill && \
		newt target set bluepill_app app=apps/blinky && \
		newt target set bluepill_app build_profile=debug || echo "already exists"

	cd mynewt && \
		newt target create mcu_boot && \
		newt target set mcu_boot bsp=@apache-mynewt-core/hw/bsp/bluepill && \
		newt target set mcu_boot app=@mcuboot/boot/mynewt && \
		newt target set mcu_boot build_profile=optimized || echo "already exists"

	cd mynewt && newt upgrade -f

run-renode:
	docker run -v `pwd`:/workspace -w /workspace --rm -it -p 5000:5000 antmicro/renode \
		renode -P 5000 --disable-xwt -e 's @/workspace/renode/bluepill_app.resc'

flash-device:
	mkdir -p openocd/bin
	cp -a mynewt/bin/targets/mcu_boot/app/boot/mynewt/mynewt.elf.bin openocd/bin/
	cp -a mynewt/bin/targets/bluepill_app/app/apps/blinky/blinky.img openocd/bin/
	scp -i $(OPENOCD_SSH_KEY) -r openocd pi@$(OPENOCD_HOST):~
	{ cat openocd/flash-init.ocd openocd/flash-boot.ocd openocd/flash-app.ocd ; sleep 5; echo -e '\x1dclose\x0d' ;} | telnet $(OPENOCD_HOST) 4444
	# ssh pi@openocd.local 'cd openocd && sudo openocd -f flash-init.ocd -f flash-boot.ocd'

gdb:
	#break repos/apache-mynewt-core/kernel/os/src/os.c:262
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/os_arch_arm.c:297
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/os_arch_arm.c:274
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/m3/HAL_CM3.s:101
	#break repos/apache-mynewt-core/kernel/os/src/arch/cortex_m3/os_arch_arm.c:252
	#break repos/apache-mynewt-core/kernel/os/src/os.c:236
	#break rust/app/src/lib.rs:21
	#break rust/app/src/lib.rs:25
	( echo "target remote $(OPENOCD_HOST):3333" ; echo "load" ; cat ) | gdb-multiarch -iex 'add-auto-load-safe-path .' mynewt/bin/targets/bluepill_app/app/apps/blinky/blinky.elf