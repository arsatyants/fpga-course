#!/usr/bin/env python3
"""Lesson 15: скриншот симуляції tb_moving_max з Vivado GUI на віртуальному дисплеї Xvfb
(робочий стіл не чіпається).

    screenshot.py <zoom_from_ns> <zoom_to_ns> <out.png> [tab_x tab_y]

Запускає vivado -mode gui -source vivado/sim_gui.tcl на DISPLAY=:99 (Xvfb піднімається, якщо його
немає), розтягує вікно на весь екран і, якщо задано tab_x/tab_y, робить подвійний клік по вкладці
waveform (у Vivado це "розгорнути панель"). Потребує: Xvfb, xwininfo, Pillow, libX11, libXtst."""
import ctypes, os, re, subprocess, sys, time

DISP = ":99"
W, H = 1920, 1080
HERE = os.path.dirname(os.path.abspath(__file__))
VIVADO_DIR = os.path.join(HERE, "..", "vivado")
VIVADO = os.environ.get("VIVADO", "/media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/2026.1/Vivado/bin/vivado")

x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p

def ensure_xvfb():
    if subprocess.run(["xdpyinfo", "-display", DISP], capture_output=True).returncode != 0:
        subprocess.Popen(["Xvfb", DISP, "-screen", "0", f"{W}x{H}x24", "-nolisten", "tcp"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2)

def vivado_window():
    tree = subprocess.run(["xwininfo", "-display", DISP, "-root", "-tree"], capture_output=True, text=True).stdout
    for line in tree.splitlines():
        if "Vivado 2026" in line and '("Vivado"' in line:
            return int(line.split()[0], 16)
    return None

def click(d, x, y, n=1):
    xtst.XTestFakeMotionEvent(ctypes.c_void_p(d), -1, x, y, 0)
    for _ in range(n):
        xtst.XTestFakeButtonEvent(ctypes.c_void_p(d), 1, 1, 0)
        xtst.XTestFakeButtonEvent(ctypes.c_void_p(d), 1, 0, 0)
    x11.XFlush(ctypes.c_void_p(d))

def main():
    z0, z1, out = sys.argv[1], sys.argv[2], sys.argv[3]
    tab = tuple(int(v) for v in sys.argv[4:6]) if len(sys.argv) >= 6 else None
    ensure_xvfb()
    ready = os.path.join(VIVADO_DIR, "gui_ready")
    if os.path.exists(ready): os.remove(ready)
    env = dict(os.environ, DISPLAY=DISP)
    p = subprocess.Popen([VIVADO, "-mode", "gui", "-nojournal", "-nolog", "-source", "sim_gui.tcl",
                          "-tclargs", z0, z1], cwd=VIVADO_DIR, env=env,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(300):
            if os.path.exists(ready): break
            time.sleep(1)
        else:
            sys.exit("Vivado не дійшов до gui_ready")
        time.sleep(3)
        d = x11.XOpenDisplay(DISP.encode())
        win = vivado_window()
        x11.XMoveResizeWindow(ctypes.c_void_p(d), ctypes.c_ulong(win), 0, 0, W, H)
        x11.XFlush(ctypes.c_void_p(d))
        time.sleep(3)
        if tab:
            click(d, *tab, n=2)
            time.sleep(3)
        xtst.XTestFakeMotionEvent(ctypes.c_void_p(d), -1, W - 5, H - 5, 0)  # курсор -- в кут, без підказок
        x11.XFlush(ctypes.c_void_p(d))
        time.sleep(1)
        x11.XCloseDisplay(ctypes.c_void_p(d))
        from PIL import ImageGrab
        ImageGrab.grab(bbox=(0, 0, W, H), xdisplay=DISP).save(out)
        print("saved", out)
    finally:
        p.terminate()
        os.remove(ready) if os.path.exists(ready) else None

if __name__ == "__main__":
    main()
