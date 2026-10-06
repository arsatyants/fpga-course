# Lesson 12 — кадр 320x200 через AXI DMA (MicroBlaze)

Домашнє завдання до лекції 12, на основі прикладу "Проєкт 3" (`FPGA/lesson_12/Example/DMA_MB/DMA_MB_3`).
Плата: MicroPhase Z7-Lite-ES1 (xc7z010clg400-1), Vivado/Vitis 2026.1.

## Система

```
 зовнішні порти                 frame_rx_axis (власний)            AXI DMA (S2MM, Simple)
 pix_clk  ──────────┐   ┌──────────────────────────────────┐     ┌──────────────┐
 pix_data[7:0] ─────┼──►│ IOB-регістри → FSM → 4B→32b       │     │              │  M_AXI_S2MM
 pix_valid ─────────┤   │ → async FIFO (Gray) pix_clk→aclk  ├────►│ S_AXIS_S2MM  ├──────┐
 pix_fsync ─────────┘   │                         M_AXIS    │     └──────▲───────┘      │
                        └──────▲──────────────┬────────────┘            │ S_AXI_LITE   ▼
                          start│        status│ {ovf,busy}              │        SmartConnect ──► axi4_full_ram
 btn (KEY2) ──► AXI GPIO 0 ────┘              │                         │        (2 SI x 4 MI)   0xC000_0000, 64 KB
                ch1 in / ch2 out              ▼                         │              ▲
 led[1:0] ◄──── AXI GPIO 1 ch1 out / ch2 in ◄─┘                         └── MicroBlaze ┘ (M_AXI_DP)
```

| Блок | Адреса | Примітка |
|---|---|---|
| axi_gpio_0 | 0x4000_0000 | ch1: `btn` (вхід, active-low), ch2: `start` → frame_rx_axis |
| axi_gpio_1 | 0x4001_0000 | ch1: `led[1:0]` (active-low: led0 = OK, led1 = помилка), ch2: status (bit0 busy, bit1 overflow) |
| axi_dma_0 | 0x41E0_0000 | лише S2MM, без SG, `c_sg_length_width = 16` (бо 64000 > 16383 за замовчуванням) |
| axi4_full_ram_0 | 0xC000_0000 | `ADDR_WIDTH = 16`, `MEM_DEPTH = 16000` |

### Розрахунок пам'яті

320 × 200 = **64000 байт** = 64000 / 4 = **16000 32-бітних слів** → `MEM_DEPTH = 16000`.
Адресний простір у байтах має покривати 64000 → `ADDR_WIDTH = 16` (2¹⁶ = 65536 ≥ 64000; 15 біт = 32768 замало).
Вікно в Address Editor = 2^ADDR_WIDTH = 64 KB. Довжина транзакції DMA 64000 потребує регістра довжини ≥ 16 біт.

## Модуль `rtl/frame_rx_axis.v`

Вхідні сигнали (власне рішення, "паралельна камера" як DVP):

| Порт | Призначення |
|---|---|
| `pix_clk` | такт джерела (у симуляції 40 МГц, асинхронний до 100 МГц системи; на платі — SRCC-пін U14) |
| `pix_data[7:0]` | піксель, 1 байт на такт |
| `pix_valid` | байт дійсний (DE/HREF); 0 у горизонтальному/вертикальному бланкінгу |
| `pix_fsync` | 1 разом із першим пікселем кадру — без маркера неможливо знайти межу кадру, якщо приймач увімкнули посеред потоку |

Поведінка:
* до `start` (і після прийнятого кадру) — стан IDLE, вхідні порти ігноруються;
* фронт `start` (з GPIO через 2-FF синхронізатор у домен `pix_clk`) → стан ARM: чекає `pix_fsync`;
* CAPT: приймає рівно 64000 байт, пакує по 4 (little-endian: перший піксель у `[7:0]`),
  пише `{tlast, word}` в асинхронний FIFO (`rtl/async_fifo.v`, Gray-вказівники, 16 слів);
* вихід FIFO (FWFT) = AXI4-Stream master: `tvalid = !empty`, `tlast` на 16000-му слові, `tkeep = 4'hF`;
  повністю підтримує backpressure (`tready`);
* `status = {overflow, busy}` (синхронізовані в домен `aclk`) — для програми через GPIO.

## Програма MicroBlaze `vitis/main.c`

1. ініціалізація GPIO, DMA (Simple mode), `start = 0`;
2. очікування натискання кнопки (відпущена → натиснута, 32 однакові читання поспіль — фільтр брязкоту);
3. `XAxiDma_SimpleTransfer(0xC0000000, 64000, DEVICE_TO_DMA)` — **спочатку** DMA;
4. `start = 1` — приймач озброєний, захоплює наступний повний кадр;
5. чекає `!XAxiDma_Busy`, `start = 0`, перевіряє DMASR (помилки), фактичну довжину (= 64000) та overflow;
   led0 = OK або led1 = помилка; повертається до п.2 (кожне натискання — новий кадр).

## Testbench

* `tb/pix_source.vh` — модель джерела: 40 МГц, рядок 320 + 40 тактів бланкінгу, 2000 тактів
  вертикального бланкінгу (кадр = 1.85 мс), значення пікселя `(x + 2y + 7·frame) & 0xFF` —
  номер кадру закодований у даних, тож TB знає, який саме кадр потрапив у пам'ять;
  у бланкінгу на шині — випадкове сміття.
* `tb/tb_frame_rx_axis.v` — модульний тест (швидкий, без MicroBlaze): ігнорування до start,
  прийом наступного повного кадру при start посеред кадру, 16000 слів, TLAST, випадковий TREADY,
  ігнорування після кадру, overflow.
* `tb/tb_design_1.v` — системний тест (Behavioral Simulation усього BD з реальним ELF):
  кадри йдуть з t=0, кнопка натискається на 400 мкс, перевіряється LED від програми,
  кількість слів у DMA, **усі 16000 слів axi4_full_ram** і відсутність трафіку після кадру.

## Збірка та запуск

```bash
# 0. модульний тест (≈20 с)
tb/run_unit.sh

# 1. Vivado-проєкт + BD + XSA (pre-synthesis)
cd vivado && vivado -mode batch -source create_project.tcl

# 2. BSP + ELF (xsdb/HSI, як у lesson10)
../vitis/build_app.sh

# 3. системна Behavioral Simulation з ELF у LMB
vivado -mode batch -source sim.tcl
grep -E "ok:|FAIL|PASSED|FAILED" FRAME_DMA_MB/FRAME_DMA_MB.sim/sim_1/behav/xsim/simulate.log

# 4. (опційно) bitstream з ELF + XSA для плати
vivado -mode batch -source impl.tcl
```

## Зміна в axi4_full_ram (ip_repo)

`ip_repo/Axi4_full_ram` — копія IP з прикладу з однією правкою: запис/читання масиву `mem`
винесено в окремий `always` без reset. В оригіналі доступ до `mem` стоїть усередині `always`
з асинхронним reset — для 256 слів Vivado розкладав пам'ять на тригери, а для 16000 слів
(512000 біт) синтез падає: `Synth 8-3391 Unable to infer a block/distributed RAM`.
AXI-протокол і такти не змінились (системна симуляція дає той самий результат).

## Результати (2026-10-06, Vivado 2026.1)

Модульний тест (`tb/run_unit.sh`):
```
ok:   T1 no output before start
ok:   T2 captured first full frame after start
ok:   T2 exactly 16000 words
ok:   T2 data + TLAST match
ok:   T3 no output after frame done
ok:   T4 overflow flagged when sink stalls
UNIT TEST PASSED
```

Системна Behavioral Simulation (`vivado/sim.tcl`, реальний ELF у LMB):
```
ok:   до кнопки в DMA не пройшло жодного слова (кадр 0 ігнорується)
[400 us]  кнопка натиснута
[427.6 us] MicroBlaze: start=1 (джерело передає кадр 0)
[3653 us] LED = 10
ok:   програма MicroBlaze повідомила OK (DMA без помилок, 64000 байт, без overflow)
ok:   в DMA пройшло рівно 16000 слів, один TLAST
      перевірка axi4_full_ram: очікується кадр 1  -> 16000/16000 слів збіглися
ok:   після кадру вхід знову ігнорується
SYSTEM TEST PASSED
```

Implementation (`vivado/impl.tcl`): WNS = +1.58 нс (100 МГц / 40 МГц), 6639 LUT (38 %),
33 BRAM tile (55 %: 16 — LMB 64 KB, 16 — кадрова RAM, 1 — DMA). Bitstream з ELF: `vivado/design_1_wrapper.bit`.
На платі зовнішнє джерело кадрів не перевірялось.

### Перевірка на платі через JTAG (xsdb, без джерела кадрів)

> Плата завантажується з SD (`BOOT_MODE = 5`), і програма на ARM перезавантажує PL через кілька секунд
> після прошивки по JTAG. Перед тестом зупинити обидва ядра Cortex-A9 (`stop`) або перемкнути boot на JTAG / вийняти SD.

* MicroBlaze стартує з ELF у bitstream; GPIO/DMA в очікуваному стані очікування (`DMASR = 0x1`, LED вимкнені).
* axi4_full_ram (0xC000_0000): запис/читання першого, середнього, останнього слова та блоку 1024 слів — 0 розбіжностей.
* Після натискання KEY2: `start = 1`, `DMACR = 0x00010003` (RS), `DMASR = 0x0` (без помилок),
  `LENGTH = 0xFA00` (64000) — DMA чекає на потік. `status.busy = 0`, бо без `pix_clk` фронт `start`
  не доходить до домену приймача — очікувано. Повний захоплення кадру потребує джерела на JP1.
