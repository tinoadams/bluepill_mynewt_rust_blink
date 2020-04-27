#define STM32F103xB 1

#include "sysinit/sysinit.h"
#include "os/os.h"
#include "bsp/bsp.h"
#include "hal/hal_gpio.h"

// we need C code to call sysinit() in order for the marco to be expanded
#include "/workspaces/blue_rust/mynewt/libs/mynewt_rust/src/mynewt_rust.c"
