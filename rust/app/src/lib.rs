#![no_std] //  Don't link with standard Rust library, which is not compatible with embedded systems
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]
#![feature(core_panic)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

// extern crate core;
extern crate cortex_m; //  Declare the external library `cortex_m`

use core::mem::MaybeUninit;
use core::option::Option::Some;
// use core::panic;
use core::panic::PanicInfo; //  Import `PanicInfo` type which is used by `panic()` below
use cortex_m::asm::bkpt; //  Import cortex_m assembly function to inject breakpoint
                         // use cstr_core::CStr;

// static OS_TICKS_PER_SEC: u32 = 4000;
static G_LED_PIN: i32 = 45;

extern "C" fn task1_handler(_arg: *mut ::cty::c_void) {
    loop {
        unsafe {
            /* Wait one second */
            os_time_delay(OS_TICKS_PER_SEC);
            /* Toggle the LED */
            hal_gpio_toggle(G_LED_PIN);
        }
    }
}

// ::cty::c_char
// pub fn to_cstr(s: &[u8]) -> &[::cty::c_char] {
pub fn to_cstr(s: &[u8]) -> *const ::cty::c_char {
    // if s.last() != Some(&0) {
    //     panic!("non null terminated slice given")
    // }
    let slice = unsafe { &*(s as *const [u8] as *const [::cty::c_char]) };
    slice.as_ptr()
}

// impl Send for i8;
// unsafe impl Sync for i8 {}

///  Declare a `void *` pointer that will be passed to C functions
type Ptr = *mut ::cty::c_void;
///  Declare a `NULL` pointer that will be passed to C functions
const NULL: Ptr = core::ptr::null_mut();

const TASK1_TASK_PRI: u8 = OS_TASK_PRI_HIGHEST as u8;
const TASK1_STACK_SIZE: u16 = 64;
// zeroed task stack
static mut TASK1_STACK: [os_stack_t; TASK1_STACK_SIZE as usize] =
    [0 as os_stack_t; TASK1_STACK_SIZE as usize];
// uninitialised task object
static mut TASK1: MaybeUninit<os_task> = MaybeUninit::<os_task>::uninit();
static TASK1_NAME: &str = "task1";

///  Main program that initialises the sensor, network driver and starts reading and sending sensor data in the background.
///  main() will be called at Mynewt startup. It replaces the C version of the main() function.
#[no_mangle] //  Don't mangle the name "main"
extern "C" fn main() -> ! {
    unsafe {
        rust_sysinit();
        hal_gpio_init_out(45, 1);

        os_task_init(
            TASK1.as_mut_ptr(),
            to_cstr(TASK1_NAME.as_bytes()),
            Some(task1_handler),
            NULL,
            TASK1_TASK_PRI,
            OS_WAIT_FOREVER as u32,
            TASK1_STACK.as_mut_ptr(),
            TASK1_STACK_SIZE,
        );
    }
    //  Main event loop
    loop {
        unsafe {
            os_eventq_run(os_eventq_dflt_get());
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
