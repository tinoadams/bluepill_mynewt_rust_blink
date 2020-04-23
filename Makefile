clean:
	cargo clean
	cd mynewt && newt clean -v all

build-rust:
	# RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust PATH="/opt/rust/bin:$PATH" /usr/bin/sudo /opt/rust/bin/
	cargo build --target thumbv7m-none-eabi

build-newt: mynewt/repos
	cd mynewt && \
		for target in `ls targets`; do newt build "$$target"; done && \
		newt create-image -v bluepill_app 1.0.0 -2

mynewt/repos: 
	make newt-install

newt-install:
	cd mynewt && \
		newt install && \
		newt upgrade && \
		newt target create mcu_boot && \
		newt target set mcu_boot bsp=@apache-mynewt-core/hw/bsp/bluepill && \
		newt target set mcu_boot app=@mcuboot/boot/mynewt && \
		newt target set mcu_boot build_profile=optimized ; \
		newt target create bluepill_app && \
		newt target set bluepill_app bsp=@apache-mynewt-core/hw/bsp/bluepill && \
		newt target set bluepill_app app=apps/blinky && \
		newt target set bluepill_app build_profile=debug
	# weird thing that the default Mynewt version contains modified files which prevent mcuboot from upgrading
	rm -rf mynewt/repos/mcuboot/ext/mbedtls
	# let Mynewt upgrade after removing modified files
	cd mynewt && \
		newt install && \
		newt upgrade

run-renode:
	docker run -v `pwd`:/workspace -w /workspace --rm -it -p 5000:5000 antmicro/renode \
		renode -P 5000 --disable-xwt -e 's @/workspace/renode/bluepill_app.resc'

flash-device:
	mkdir -p openocd/bin
	# cp -a ../mynewt/bin/targets/mcu_boot/app/boot/mynewt/mynewt.elf.bin openocd/bin/
	# cp -a ../mynewt/bin/targets/bluepill_boot/app/apps/boot_stub/boot_stub.elf.bin openocd/bin/
	# cp -a ../mynewt/bin/targets/bluepill_app/app/apps/blinky/blinky.img openocd/bin/
	# scp -r openocd pi@openocd.local:~
	{ cat openocd/flash-init.ocd openocd/flash-boot.ocd openocd/flash-app.ocd ; sleep 5; echo -e '\x1dclose\x0d' ;} | telnet 192.168.10.197 4444
	# ssh pi@openocd.local 'cd openocd && sudo openocd -f flash-init.ocd -f flash-boot.ocd'
	# ssh pi@openocd.local 'cd openocd && sudo openocd -f flash-init.ocd -f flash-app.ocd'
	# ssh pi@openocd.local 'cd openocd && sudo openocd -f flash-init.ocd -f flash-bin.ocd'
