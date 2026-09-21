/*
 * LED running light ("біжуча доріжка") for MicroPhase Z7-Lite-ES1 (MicroBlaze).
 * AXI GPIO led (4 bit, active-low), btn (4 bit, active-low), sw (2 bit).
 * AXI Timer generates interrupts via AXI INTC; ISR advances the LED position.
 *
 * Behavior:
 *  - sw[0] = 0 -> forward (LED0->LED1->LED2->LED3), sw[0] = 1 -> reverse
 *  - btn[0] pressed -> speed up (period / 2)
 *  - btn[1] pressed -> slow down (period * 2)
 *  - btn[2] pressed -> stop (pause)
 *  - btn[3] pressed -> resume
 * Buttons are edge-detected, not level-polled (single action per press).
 */

#include <stdio.h>
#include "xparameters.h"
#include "xgpio.h"
#include "xtmrctr.h"
#include "xintc.h"
#include "xil_exception.h"
#include "xil_printf.h"

#define LED_GPIO_BASEADDR  XPAR_AXI_GPIO_0_BASEADDR
#define BTN_GPIO_BASEADDR  XPAR_AXI_GPIO_1_BASEADDR
#define SW_GPIO_BASEADDR   XPAR_AXI_GPIO_2_BASEADDR
#define TMR_BASEADDR       XPAR_AXI_TIMER_0_BASEADDR
#define TMR_INT_ID         XPAR_MICROBLAZE_0_AXI_INTC_AXI_TIMER_0_INTERRUPT_INTR

/* Timer interval: default ~0.5 s @ 100 MHz. Buttons adjust. */
#define TIMER_LOAD_DEFAULT 1000000u
#define TIMER_LOAD_MIN     625000u

static XGpio   ledGpio, btnGpio, swGpio;
static XTmrCtr timer;
static XIntc   intc;

static volatile u32  ledPos     = 0;
static volatile int  direction  = 1;
static volatile u32  timerLoad  = TIMER_LOAD_DEFAULT;
static volatile int  paused     = 0;

static void timer_handler(void *CallBackRef)
{
    (void)CallBackRef;

    if (paused)
        return;

    /* Clear timer interrupt */
    u32 csr = XTmrCtr_GetControlStatusReg(timer.BaseAddress, 0);
    csr |= XTC_CSR_INT_OCCURED_MASK;
    XTmrCtr_SetControlStatusReg(timer.BaseAddress, 0, csr);

    ledPos = (u32)(((int)ledPos + direction) & 0x3);
    XGpio_DiscreteWrite(&ledGpio, 1, 1u << ledPos);
}

int main(void)
{
    XGpio_Initialize(&ledGpio, LED_GPIO_BASEADDR);
    XGpio_Initialize(&btnGpio, BTN_GPIO_BASEADDR);
    XGpio_Initialize(&swGpio,  SW_GPIO_BASEADDR);
    XGpio_SetDataDirection(&ledGpio, 1, 0x0);
    XGpio_SetDataDirection(&btnGpio, 1, 0xF);
    XGpio_SetDataDirection(&swGpio,  1, 0x3);
    XGpio_DiscreteWrite(&ledGpio, 1, 0xF);  /* all off (active low) */

    XTmrCtr_Initialize(&timer, TMR_BASEADDR);

    /* Interrupt controller */
    XIntc_Initialize(&intc, XPAR_INTC_SINGLE_DEVICE_ID);
    XIntc_Connect(&intc, TMR_INT_ID, (Xil_ExceptionHandler)timer_handler, &timer);
    XIntc_Start(&intc, XIN_REAL_MODE);
    XIntc_Enable(&intc, TMR_INT_ID);

    microblaze_register_handler((XInterruptHandler)XIntc_DeviceInterruptHandler, (void *)0);
    microblaze_enable_interrupts();

    /* Timer: down-count, auto-reload, interrupt enabled */
    timerLoad = TIMER_LOAD_DEFAULT;
    XTmrCtr_SetLoadReg(TMR_BASEADDR, 0, timerLoad);
    XTmrCtr_SetControlStatusReg(TMR_BASEADDR, 0,
        XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_AUTO_RELOAD_MASK |
        XTC_CSR_DOWN_COUNT_MASK | XTC_CSR_ENABLE_INT_MASK |
        XTC_CSR_LOAD_MASK | XTC_CSR_INT_OCCURED_MASK);
    XTmrCtr_SetControlStatusReg(TMR_BASEADDR, 0,
        XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_AUTO_RELOAD_MASK |
        XTC_CSR_DOWN_COUNT_MASK | XTC_CSR_ENABLE_INT_MASK |
        XTC_CSR_INT_OCCURED_MASK);

    XGpio_DiscreteWrite(&ledGpio, 1, 1u << ledPos);

    xil_printf("Lesson10 MicroBlaze LED running light started.\r\n");

    u32 prevBtn = 0xF;
    while (1) {
        u32 btn = XGpio_DiscreteRead(&btnGpio, 1) & 0xF;
        u32 sw  = XGpio_DiscreteRead(&swGpio,  1) & 0x3;
        u32 pressed = prevBtn & ~btn;

        direction = (sw & 0x1) ? -1 : 1;

        if (pressed & 0x1) {
            timerLoad >>= 1;
            if (timerLoad < TIMER_LOAD_MIN) timerLoad = TIMER_LOAD_MIN;
            xil_printf("speed up: %u ticks\r\n", timerLoad);
        }
        if (pressed & 0x2) {
            timerLoad <<= 1;
            if (timerLoad > (TIMER_LOAD_DEFAULT * 8)) timerLoad = TIMER_LOAD_DEFAULT * 8;
            xil_printf("slow down: %u ticks\r\n", timerLoad);
        }
        if (pressed & 0x4) { paused = 1; xil_printf("paused\r\n"); }
        if (pressed & 0x8) { paused = 0; xil_printf("resumed\r\n"); }

        prevBtn = btn;
        for (volatile int i = 0; i < 50000; i++) ;
    }
    return 0;
}