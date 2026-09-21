/*
 * LED running light ("біжуча доріжка") for MicroPhase Z7-Lite-ES1 (Zynq PS).
 * AXI GPIO led (4 bit, active-low), btn (4 bit, active-low), sw (2 bit).
 * AXI Timer generates interrupts; ISR advances the LED position.
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
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_printf.h"

/* Timer interrupt interval: default ~0.5 s @ 50 MHz (FCLK0).
 * Adjusted by buttons: speed up halves period, slow down doubles it. */
#define TIMER_LOAD_DEFAULT 25000000u  /* 0.5 s @ 50 MHz */
#define TIMER_LOAD_MIN     1562500u   /* fastest step (~31 ms) */

#define GIC_BASE           XPAR_SCUGIC_0_CPU_BASEADDR
#define TMR_INT_ID         91          /* AXI Timer0 interrupt (IRQ_F2P bit 0 -> 61+32) */

#define LED_GPIO_BASEADDR  XPAR_AXI_GPIO_0_BASEADDR
#define BTN_GPIO_BASEADDR  XPAR_AXI_GPIO_1_BASEADDR
#define SW_GPIO_BASEADDR   XPAR_AXI_GPIO_2_BASEADDR
#define TMR_BASEADDR       XPAR_TMRCTR_0_BASEADDR

static XGpio  ledGpio, btnGpio, swGpio;
static XTmrCtr timer;
static XScuGic gic;

static volatile u32  ledPos     = 0;      /* 0..3 */
static volatile int  direction  = 1;      /* 1 forward, -1 reverse */
static volatile u32  timerLoad  = TIMER_LOAD_DEFAULT;
static volatile int  paused     = 0;

static void timer_handler(void *CallBackRef)
{
    (void)CallBackRef;

    if (paused)
        return;

    /* Clear pending interrupt: timer in compare mode auto-clears on TCSR write */
    u32 csr = XTmrCtr_GetControlStatusReg(timer.BaseAddress, 0);
    csr |= XTC_CSR_INT_OCCURED_MASK;
    XTmrCtr_SetControlStatusReg(timer.BaseAddress, 0, csr);

    /* Advance LED position with wrap */
    ledPos = (u32)(((int)ledPos + direction) & 0x3);
    XGpio_DiscreteWrite(&ledGpio, 1, 1u << ledPos);
}

static void setup_timer(void)
{
    /* Configure timer 0 in down-count, auto-reload, interrupt mode */
    u32 csr = XTmrCtr_GetControlStatusReg(TMRCTR_BASEADDR, 0);
    csr |= XTC_CSR_INT_OCCURED_MASK;
    XTmrCtr_SetControlStatusReg(TMRCTR_BASEADDR, 0, csr);
    XTmrCtr_SetLoadReg(TMRCTR_BASEADDR, 0, timerLoad);
    XTmrCtr_SetControlStatusReg(TMRCTR_BASEADDR, 0,
        XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_AUTO_RELOAD_MASK |
        XTC_CSR_DOWN_COUNT_MASK | XTC_CSR_ENABLE_INT_MASK |
        XTC_CSR_LOAD_MASK | XTC_CSR_INT_OCCURED_MASK);
    /* Release load */
    XTmrCtr_SetControlStatusReg(TMRCTR_BASEADDR, 0,
        XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_AUTO_RELOAD_MASK |
        XTC_CSR_DOWN_COUNT_MASK | XTC_CSR_ENABLE_INT_MASK |
        XTC_CSR_INT_OCCURED_MASK);
}

int main(void)
{
    int status;

    /* LEDs: all off (active low) */
    XGpio_Initialize(&ledGpio, LED_GPIO_BASEADDR);
    XGpio_Initialize(&btnGpio, BTN_GPIO_BASEADDR);
    XGpio_Initialize(&swGpio,  SW_GPIO_BASEADDR);
    XGpio_SetDataDirection(&ledGpio, 1, 0x0);
    XGpio_SetDataDirection(&btnGpio, 1, 0xF);
    XGpio_SetDataDirection(&swGpio,  1, 0x3);
    XGpio_DiscreteWrite(&ledGpio, 1, 0xF);

    XTmrCtr_Initialize(&timer, TMR_BASEADDR);

    /* GIC: connect timer interrupt (IRQ_F2P bit0 = ID 61) */
    XScuGic_Config *gicCfg = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
    XScuGic_CfgInitialize(&gic, gicCfg, gicCfg->CpuBaseAddress);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic);
    Xil_ExceptionEnable();
    XScuGic_Connect(&gic, TMR_INT_ID, (Xil_ExceptionHandler)timer_handler, &timer);
    XScuGic_Enable(&gic, TMR_INT_ID);

    /* Set timer interval and start */
    timerLoad = TIMER_LOAD_DEFAULT;
    XTmrCtr_SetResetValue(&timer, 0, timerLoad);
    XTmrCtr_Start(&timer, 0);

    /* Initial LED state */
    XGpio_DiscreteWrite(&ledGpio, 1, 1u << ledPos);

    xil_printf("Lesson10 Zynq LED running light started.\r\n");

    /* Button edge detection state (active-low) */
    u32 prevBtn = 0xF;

    while (1) {
        u32 btn = XGpio_DiscreteRead(&btnGpio, 1) & 0xF;
        u32 sw  = XGpio_DiscreteRead(&swGpio,  1) & 0x3;
        u32 pressed = prevBtn & ~btn; /* rising edge of press (0->1 transition in 'pressed') */

        /* sw[0] selects direction */
        direction = (sw & 0x1) ? -1 : 1;

        if (pressed & 0x1) {           /* btn[0]: speed up */
            timerLoad >>= 1;
            if (timerLoad < TIMER_LOAD_MIN)
                timerLoad = TIMER_LOAD_MIN;
            XTmrCtr_SetResetValue(&timer, 0, timerLoad);
            xil_printf("speed up: period = %u ticks\r\n", timerLoad);
        }
        if (pressed & 0x2) {           /* btn[1]: slow down */
            timerLoad <<= 1;
            if (timerLoad > (TIMER_LOAD_DEFAULT * 8))
                timerLoad = TIMER_LOAD_DEFAULT * 8;
            XTmrCtr_SetResetValue(&timer, 0, timerLoad);
            xil_printf("slow down: period = %u ticks\r\n", timerLoad);
        }
        if (pressed & 0x4) {           /* btn[2]: stop */
            paused = 1;
            xil_printf("paused\r\n");
        }
        if (pressed & 0x8) {           /* btn[3]: resume */
            paused = 0;
            xil_printf("resumed\r\n");
        }

        prevBtn = btn;
        for (volatile int i = 0; i < 50000; i++) ;  /* ~1 ms debounce */
    }

    return 0;
}