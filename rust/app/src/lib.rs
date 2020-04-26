#![no_std] //  Don't link with standard Rust library, which is not compatible with embedded systems
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

extern crate cortex_m; //  Declare the external library `cortex_m`

use core::panic::PanicInfo; //  Import `PanicInfo` type which is used by `panic()` below
use cortex_m::asm::bkpt; //  Import cortex_m assembly function to inject breakpoint

///  Import the custom interop helper library at `libs/mynewt_rust`
#[link(name = "libs_mynewt_rust")] //  Functions below are located in the Mynewt build output `libs_mynewt_rust.a`
extern "C" {
    ///  Initialise the Mynewt system.  Start the Mynewt drivers and libraries.  Equivalent to `sysinit()` macro in C.
    ///  C API: `void rust_sysinit()`
    pub fn rust_sysinit();

    pub fn hal_gpio_init_out(_: i32, _: i32) -> i32;
    pub fn hal_gpio_toggle(_: i32) -> i32;

    pub fn os_time_delay(_: u32);
}

static OS_TICKS_PER_SEC: u32 = 4000;
static G_LED_PIN: i32 = 45;

///  Main program that initialises the sensor, network driver and starts reading and sending sensor data in the background.
///  main() will be called at Mynewt startup. It replaces the C version of the main() function.
#[no_mangle] //  Don't mangle the name "main"
extern "C" fn main() -> ! {
    unsafe {
        rust_sysinit();
        hal_gpio_init_out(45, 1);
    }
    //  Main event loop
    loop {
        unsafe {
            /* Wait one second */
            os_time_delay(OS_TICKS_PER_SEC);
            /* Toggle the LED */
            hal_gpio_toggle(G_LED_PIN);
        }
    }
    //  Never comes here
}

/// This function is called on panic, like an assertion failure. We display the filename and line number and pause in the debugger. From https://os.phil-opp.com/freestanding-rust-binary/
#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    //  Pause in the debugger.
    bkpt();
    //  Loop forever so that device won't restart.
    loop {}
}
