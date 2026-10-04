"""CoreEP2C5 joystick direction and pin map viewer."""
import tkinter as tk
from tkinter import ttk


BG = "#20242b"
PANEL = "#2b313b"
TEXT = "#f2f4f8"
MUTED = "#b9c1cc"
USED = "#2eaf72"
RESERVED = "#657184"
ACCENT = "#5aa9ff"


def label(canvas, x, y, text, fill=TEXT, size=13, weight="normal"):
    canvas.create_text(x, y, text=text, fill=fill, font=("Segoe UI", size, weight))


def main():
    root = tk.Tk()
    root.title("CoreEP2C5 joystick direction map")
    root.geometry("720x560")
    root.configure(bg=BG)
    root.resizable(False, False)

    ttk.Style().configure("TLabel", background=BG, foreground=TEXT, font=("Segoe UI", 11))
    ttk.Style().configure("Title.TLabel", background=BG, foreground=TEXT,
                          font=("Segoe UI", 18, "bold"))

    ttk.Label(root, text="CoreEP2C5 joystick direction map", style="Title.TLabel").pack(pady=(16, 4))
    ttk.Label(root, text="Press the physical joystick in the direction shown by each arrow.",
              style="TLabel").pack()

    canvas = tk.Canvas(root, width=500, height=330, bg=BG, highlightthickness=0)
    canvas.pack(pady=10)
    cx, cy = 250, 160
    canvas.create_oval(cx - 65, cy - 65, cx + 65, cy + 65, fill=PANEL, outline=ACCENT, width=3)
    canvas.create_oval(cx - 25, cy - 25, cx + 25, cy + 25, fill="#414957", outline=TEXT, width=2)

    directions = [
        (cx, 45, "UP", "PIN_139", USED, "starts recognition"),
        (cx, 275, "DOWN", "PIN_143", USED, "clears frame"),
        (90, cy, "LEFT", "PIN_142", RESERVED, "reserved"),
        (410, cy, "RIGHT", "PIN_141", RESERVED, "reserved"),
    ]
    for x, y, direction, pin, color, use in directions:
        if direction == "UP":
            canvas.create_line(cx, cy - 70, x, y + 25, fill=color, width=4, arrow=tk.LAST)
        elif direction == "DOWN":
            canvas.create_line(cx, cy + 70, x, y - 25, fill=color, width=4, arrow=tk.LAST)
        elif direction == "LEFT":
            canvas.create_line(cx - 70, cy, x + 38, y, fill=color, width=4, arrow=tk.LAST)
        else:
            canvas.create_line(cx + 70, cy, x - 38, y, fill=color, width=4, arrow=tk.LAST)
        label(canvas, x, y - 18 if direction in ("UP", "DOWN") else y - 30,
              direction, color, 15, "bold")
        label(canvas, x, y + 5 if direction in ("UP", "DOWN") else y,
              pin, TEXT, 11, "bold")
        label(canvas, x, y + 25 if direction in ("UP", "DOWN") else y + 30,
              use, MUTED, 10)

    canvas.create_oval(cx - 18, cy - 18, cx + 18, cy + 18, fill=RESERVED, outline=TEXT)
    label(canvas, cx, cy, "PRESS", TEXT, 9, "bold")
    label(canvas, cx, cy + 35, "PIN_137 · reserved", MUTED, 10)

    info = tk.Frame(root, bg=PANEL, padx=14, pady=10)
    info.pack(fill="x", padx=24, pady=(0, 12))
    tk.Label(info, text="Electrical rule: released = 1, pressed = 0 (active-low)",
             bg=PANEL, fg=TEXT, font=("Segoe UI", 11, "bold")).pack(anchor="w")
    tk.Label(info, text="Green = connected to the current downloaded ML wrapper. Gray = documented but unused.",
             bg=PANEL, fg=MUTED, font=("Segoe UI", 10)).pack(anchor="w", pady=(4, 0))
    tk.Label(info, text="This UI is a map, not a live hardware reader; the current SOF only exposes UP and DOWN.",
             bg=PANEL, fg=MUTED, font=("Segoe UI", 10)).pack(anchor="w", pady=(2, 0))

    root.mainloop()


if __name__ == "__main__":
    main()
