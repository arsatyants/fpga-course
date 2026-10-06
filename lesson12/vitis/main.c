/*
 * Lesson 12 homework -- MicroBlaze: capture one 320x200 frame by button press.
 *
 * HW (see vivado/bd.tcl):
 *   axi_gpio_0  ch1 = btn   (in,  1 bit, active-low, PL_KEY2)
 *               ch2 = start (out, 1 bit) -> frame_rx_axis.start
 *   axi_gpio_1  ch1 = led   (out, 2 bit, active-low: led[0] = frame OK, led[1] = error)
 *               ch2 = frame_rx_axis.status (in: bit0 busy, bit1 FIFO overflow)
 *   axi_dma_0   S2MM only, Simple mode  (frame_rx_axis M_AXIS -> axi4_full_ram)
 *   axi4_full_ram @ 0xC0000000, 64 KB (frame = 64000 B = 16000 words)
 *
 * Logic "start after button":
 *   1. after reset the receiver is idle, start = 0 -> external pixel ports are ignored;
 *   2. wait for a button press (active-low, short glitch filter);
 *   3. arm DMA S2MM for exactly one frame (64000 B) into the RAM;
 *   4. start = 1 (rising edge arms frame_rx_axis: it waits for the next
 *      frame-start marker and streams exactly one frame, TLAST on the last word);
 *   5. wait for DMA idle, start = 0, check DMA status / length / overflow, show on LEDs;
 *   6. wait for button release and repeat (every press = one new frame).
 */

#include "xparameters.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xgpio.h"
#include "xaxidma.h"

#define DMA_BASE        XPAR_AXI_DMA_0_BASEADDR

/* SDT BSP (Vitis Unified IDE): drivers are looked up by base address;
   legacy BSP (hsi generate_app, build_app.sh): by DEVICE_ID. */
#ifdef SDT
  #define CTL_GPIO_ID   XPAR_AXI_GPIO_0_BASEADDR
  #define LED_GPIO_ID   XPAR_AXI_GPIO_1_BASEADDR
  #define DMA_ID        XPAR_AXI_DMA_0_BASEADDR
#else
  #define CTL_GPIO_ID   XPAR_AXI_GPIO_0_DEVICE_ID
  #define LED_GPIO_ID   XPAR_AXI_GPIO_1_DEVICE_ID
  #define DMA_ID        XPAR_AXI_DMA_0_DEVICE_ID
#endif

#if defined(XPAR_AXI4_FULL_RAM_0_BASEADDR)
  #define RAM_BASE      XPAR_AXI4_FULL_RAM_0_BASEADDR
#else
  #define RAM_BASE      0xC0000000u          /* bd.tcl: assign_bd_address */
#endif

#define FRAME_W         320
#define FRAME_H         200
#define FRAME_BYTES     (FRAME_W * FRAME_H)  /* 64000 B = 16000 x 32-bit words */

#define CH1             1
#define CH2             2

#define BTN_PRESSED     0                    /* active-low */
#define BTN_STABLE_N    32                   /* consecutive equal reads = glitch filter */

/* LED codes (active-low on the board) */
#define LED_NONE        0x3
#define LED_OK          0x2                  /* led[0] on */
#define LED_ERR         0x1                  /* led[1] on */

#define ST_BUSY         0x1
#define ST_OVERFLOW     0x2

/* Results, visible through the debugger (and in the simulation waveform) */
volatile u32 frames_ok    = 0;
volatile u32 frames_err   = 0;
volatile u32 last_dmasr   = 0;
volatile u32 last_length  = 0;
volatile u32 last_status  = 0;
volatile int stage        = 0;   /* 1 wait btn, 2 capturing, 3 done, <0 init error */

static XGpio   ctl_gpio, led_gpio;
static XAxiDma dma;

/* Wait until the button has the given level for BTN_STABLE_N reads in a row */
static void wait_btn_level(u32 level)
{
    int n = 0;
    while (n < BTN_STABLE_N) {
        if ((XGpio_DiscreteRead(&ctl_gpio, CH1) & 1) == level) n++;
        else n = 0;
    }
}

int main(void)
{
    XGpio_Initialize(&ctl_gpio, CTL_GPIO_ID);
    XGpio_Initialize(&led_gpio, LED_GPIO_ID);
    XGpio_SetDataDirection(&ctl_gpio, CH1, 0x1);  /* btn   in  */
    XGpio_SetDataDirection(&ctl_gpio, CH2, 0x0);  /* start out */
    XGpio_SetDataDirection(&led_gpio, CH1, 0x0);  /* led   out */
    XGpio_SetDataDirection(&led_gpio, CH2, 0x3);  /* status in */
    XGpio_DiscreteWrite(&ctl_gpio, CH2, 0);       /* receiver idle */
    XGpio_DiscreteWrite(&led_gpio, CH1, LED_NONE);

    XAxiDma_Config *cfg = XAxiDma_LookupConfig(DMA_ID);
    if (cfg == NULL)                    { stage = -1; goto fail; }
    if (XAxiDma_CfgInitialize(&dma, cfg) != XST_SUCCESS) { stage = -2; goto fail; }
    if (XAxiDma_HasSg(&dma))            { stage = -3; goto fail; }
    XAxiDma_IntrDisable(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    while (1) {
        /* ---- 1. wait for a button press (released -> pressed) ---- */
        stage = 1;
        wait_btn_level(!BTN_PRESSED);
        wait_btn_level(BTN_PRESSED);

        /* ---- 2. arm DMA first, then the receiver ---- */
        stage = 2;
        XGpio_DiscreteWrite(&led_gpio, CH1, LED_NONE);
        if (XAxiDma_SimpleTransfer(&dma, RAM_BASE, FRAME_BYTES,
                                   XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
            frames_err++;
            XGpio_DiscreteWrite(&led_gpio, CH1, LED_ERR);
            continue;
        }
        XGpio_DiscreteWrite(&ctl_gpio, CH2, 1);          /* start: rising edge */

        while (XAxiDma_Busy(&dma, XAXIDMA_DEVICE_TO_DMA))
            ;
        XGpio_DiscreteWrite(&ctl_gpio, CH2, 0);

        /* ---- 3. check result ---- */
        last_dmasr  = XAxiDma_ReadReg(DMA_BASE + XAXIDMA_RX_OFFSET, XAXIDMA_SR_OFFSET);
        last_length = XAxiDma_ReadReg(DMA_BASE + XAXIDMA_RX_OFFSET, XAXIDMA_BUFFLEN_OFFSET);
        last_status = XGpio_DiscreteRead(&led_gpio, CH2);
        XAxiDma_IntrAckIrq(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

        if ((last_dmasr & XAXIDMA_ERR_ALL_MASK) == 0 &&
            last_length == FRAME_BYTES &&
            (last_status & ST_OVERFLOW) == 0) {
            frames_ok++;
            XGpio_DiscreteWrite(&led_gpio, CH1, LED_OK);
        } else {
            frames_err++;
            XGpio_DiscreteWrite(&led_gpio, CH1, LED_ERR);
        }
        stage = 3;
    }

fail:
    XGpio_DiscreteWrite(&led_gpio, CH1, LED_ERR);
    while (1)
        ;
    return 0;
}
