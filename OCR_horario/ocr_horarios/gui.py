from __future__ import annotations

import os
import re
import threading
from pathlib import Path
from tkinter import filedialog, messagebox
import tkinter as tk

from PIL import Image, ImageTk

from .exporter import guardar_csv
from .extractor import HorarioInvalidoError, extraer_clases_texto, extraer_texto_pdf
from .models import Clase

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
except ImportError:
    DND_FILES = None
    TkinterDnD = None


APP_DIR = Path(__file__).resolve().parent.parent
ASSET_PATH = APP_DIR / "assets" / "welcome-illustration.png"
RESULTS_DIR = APP_DIR / "resultados"
WINDOW_SIZE = "500x880"

COLORS = {
    "background": "#F5F8FC",
    "surface": "#FFFFFF",
    "navy": "#0B2054",
    "body": "#52678F",
    "blue": "#3473F4",
    "blue_dark": "#245DD4",
    "blue_soft": "#EDF4FF",
    "blue_line": "#9FC2FF",
    "line": "#DDE7F3",
    "teal": "#337E83",
    "teal_soft": "#E1F2F3",
    "green": "#5B784F",
    "green_soft": "#E9F0E5",
    "orange": "#9A4A2A",
    "orange_soft": "#FFF0E9",
    "error": "#B42318",
}


def validar_horario_unimet(text: str) -> None:
    normalized = re.sub(r"\s+", " ", text).upper()
    required = ("PLAN HORARIO", "PERIODO:", "ASIGNATURA", "PROFESOR")
    if any(marker not in normalized for marker in required):
        raise HorarioInvalidoError(
            "El PDF no corresponde al formato de Plan Horario UNIMET."
        )


def procesar_archivo(pdf_path: Path) -> list[Clase]:
    if pdf_path.suffix.lower() != ".pdf":
        raise HorarioInvalidoError("Solo se aceptan archivos PDF.")
    text = extraer_texto_pdf(pdf_path)
    validar_horario_unimet(text)
    return extraer_clases_texto(text, pdf_path.name)


def rounded_rectangle(
    canvas: tk.Canvas,
    x1: int,
    y1: int,
    x2: int,
    y2: int,
    radius: int,
    **kwargs,
) -> int:
    points = (
        x1 + radius,
        y1,
        x2 - radius,
        y1,
        x2,
        y1,
        x2,
        y1 + radius,
        x2,
        y2 - radius,
        x2,
        y2,
        x2 - radius,
        y2,
        x1 + radius,
        y2,
        x1,
        y2,
        x1,
        y2 - radius,
        x1,
        y1 + radius,
        x1,
        y1,
    )
    return canvas.create_polygon(points, smooth=True, splinesteps=24, **kwargs)


class ScrollFrame(tk.Frame):
    def __init__(self, master: tk.Misc, **kwargs) -> None:
        super().__init__(master, **kwargs)
        self.canvas = tk.Canvas(
            self,
            background=COLORS["background"],
            highlightthickness=0,
            borderwidth=0,
        )
        scrollbar = tk.Scrollbar(
            self, orient="vertical", command=self.canvas.yview, relief="flat"
        )
        self.content = tk.Frame(self.canvas, background=COLORS["background"])
        self.window_id = self.canvas.create_window(
            (0, 0), window=self.content, anchor="nw"
        )
        self.canvas.configure(yscrollcommand=scrollbar.set)
        self.canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        self.content.bind(
            "<Configure>",
            lambda _event: self.canvas.configure(scrollregion=self.canvas.bbox("all")),
        )
        self.canvas.bind(
            "<Configure>",
            lambda event: self.canvas.itemconfigure(self.window_id, width=event.width),
        )
        self.canvas.bind_all(
            "<MouseWheel>",
            lambda event: self.canvas.yview_scroll(int(-event.delta / 120), "units"),
        )


class HorarioApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("OCR de Horarios UNIMET")
        self.root.geometry(WINDOW_SIZE)
        self.root.resizable(False, False)
        self.root.configure(background=COLORS["background"])
        self.root.option_add("*Font", ("Segoe UI", 10))
        self.current_csv: Path | None = None
        self.loading = False
        self.welcome_photo = self._load_image((255, 235))
        self.results_photo = self._load_image((155, 140))

        self.container = tk.Frame(root, background=COLORS["background"])
        self.container.pack(fill="both", expand=True)
        self._build_welcome()
        self._build_results()
        self.show_welcome()

    def _load_image(self, size: tuple[int, int]) -> ImageTk.PhotoImage:
        image = Image.open(ASSET_PATH).convert("RGBA")
        image.thumbnail(size, Image.Resampling.LANCZOS)
        return ImageTk.PhotoImage(image, master=self.root)

    def _build_welcome(self) -> None:
        self.welcome = tk.Canvas(
            self.container,
            width=500,
            height=880,
            background=COLORS["background"],
            highlightthickness=0,
        )

        self.welcome.create_text(
            26,
            55,
            text="¡Bienvenido!",
            anchor="nw",
            fill=COLORS["navy"],
            font=("Segoe UI", 28, "bold"),
        )
        self.welcome.create_text(
            28,
            118,
            text="Carga o busca tu archivo de\nhorario para comenzar.",
            anchor="nw",
            fill=COLORS["body"],
            font=("Segoe UI", 12),
        )
        self.welcome.create_image(475, 17, image=self.welcome_photo, anchor="ne")

        rounded_rectangle(
            self.welcome,
            18,
            226,
            482,
            852,
            28,
            fill=COLORS["surface"],
            outline=COLORS["line"],
            width=1,
        )
        self.welcome.create_text(
            250,
            266,
            text="Cargar archivo del horario",
            fill=COLORS["navy"],
            font=("Segoe UI", 20, "bold"),
        )
        self.welcome.create_text(
            250,
            303,
            text="Selecciona un archivo desde tu dispositivo.",
            fill=COLORS["body"],
            font=("Segoe UI", 11),
        )

        self.drop_shape = rounded_rectangle(
            self.welcome,
            47,
            335,
            453,
            818,
            25,
            fill=COLORS["surface"],
            outline=COLORS["blue_line"],
            width=2,
            dash=(7, 7),
            tags=("drop",),
        )
        self.upload_circle = self.welcome.create_oval(
            190,
            382,
            310,
            502,
            fill=COLORS["blue_soft"],
            outline="",
            tags=("drop",),
        )
        self.welcome.create_text(
            250,
            442,
            text="⇧",
            fill=COLORS["blue"],
            font=("Segoe UI", 40, "bold"),
            tags=("drop",),
        )
        self.welcome.create_text(
            250,
            536,
            text="Arrastra tu archivo aquí",
            fill=COLORS["navy"],
            font=("Segoe UI", 17, "bold"),
            tags=("drop",),
        )
        self.welcome.create_text(
            250,
            572,
            text="o usa el botón para buscar",
            fill=COLORS["body"],
            font=("Segoe UI", 12),
            tags=("drop",),
        )

        self.button_shape = rounded_rectangle(
            self.welcome,
            102,
            618,
            398,
            680,
            18,
            fill=COLORS["blue"],
            outline="",
            tags=("browse",),
        )
        self.welcome.create_text(
            250,
            649,
            text="▱   Buscar archivo",
            fill="white",
            font=("Segoe UI", 14, "bold"),
            tags=("browse",),
        )
        self.welcome.create_text(
            250,
            734,
            text="▣  Tu archivo se procesa de forma segura y privada.",
            fill=COLORS["body"],
            font=("Segoe UI", 10),
        )
        self.status_id = self.welcome.create_text(
            250,
            780,
            text="",
            fill=COLORS["body"],
            font=("Segoe UI", 9),
            width=350,
            justify="center",
        )

        self.welcome.tag_bind("browse", "<Button-1>", lambda _event: self._select_file())
        self.welcome.tag_bind("browse", "<Enter>", self._browse_enter)
        self.welcome.tag_bind("browse", "<Leave>", self._browse_leave)
        self.welcome.configure(cursor="arrow")
        self._configure_drop()

    def _browse_enter(self, _event: tk.Event) -> None:
        if not self.loading:
            self.welcome.itemconfigure(self.button_shape, fill=COLORS["blue_dark"])
            self.welcome.configure(cursor="hand2")

    def _browse_leave(self, _event: tk.Event) -> None:
        self.welcome.itemconfigure(self.button_shape, fill=COLORS["blue"])
        self.welcome.configure(cursor="arrow")

    def _configure_drop(self) -> None:
        if DND_FILES is None or not getattr(self.root, "dnd_available", False):
            return
        self.welcome.drop_target_register(DND_FILES)
        self.welcome.dnd_bind("<<Drop>>", self._on_drop)
        self.welcome.dnd_bind("<<DropEnter>>", self._on_drop_enter)
        self.welcome.dnd_bind("<<DropLeave>>", self._on_drop_leave)

    def _on_drop_enter(self, event: tk.Event) -> str:
        self.welcome.itemconfigure(self.drop_shape, fill=COLORS["blue_soft"])
        return event.action

    def _on_drop_leave(self, event: tk.Event) -> str:
        self.welcome.itemconfigure(self.drop_shape, fill=COLORS["surface"])
        return event.action

    def _on_drop(self, event: tk.Event) -> str:
        self._on_drop_leave(event)
        paths = self.root.tk.splitlist(event.data)
        if len(paths) != 1:
            self._show_error("Carga un solo horario a la vez.")
        else:
            self._start_processing(Path(paths[0]))
        return event.action

    def _build_results(self) -> None:
        self.results = tk.Frame(self.container, background=COLORS["background"])
        header = tk.Canvas(
            self.results,
            width=500,
            height=188,
            background=COLORS["surface"],
            highlightthickness=0,
        )
        header.pack(fill="x")
        header.create_text(
            24,
            38,
            text="Horario de clases",
            anchor="nw",
            fill=COLORS["navy"],
            font=("Segoe UI", 25, "bold"),
        )
        self.result_subtitle_id = header.create_text(
            26,
            92,
            text="",
            anchor="nw",
            fill=COLORS["body"],
            font=("Segoe UI", 10),
            width=265,
        )
        header.create_image(492, 8, image=self.results_photo, anchor="ne")

        self.result_scroll = ScrollFrame(self.results, background=COLORS["background"])
        self.result_scroll.pack(fill="both", expand=True)
        body = self.result_scroll.content

        toolbar = tk.Frame(body, background=COLORS["background"])
        toolbar.pack(fill="x", padx=18, pady=(14, 10))
        self.period_label = tk.Label(
            toolbar,
            text="",
            font=("Segoe UI", 13, "bold"),
            foreground=COLORS["navy"],
            background=COLORS["background"],
        )
        self.period_label.pack(side="left")
        self._action_button(toolbar, "Otro horario", self.show_welcome, secondary=True).pack(
            side="right"
        )
        self._action_button(toolbar, "Abrir CSV", self._open_csv).pack(
            side="right", padx=(0, 8)
        )

        self.table = tk.Frame(
            body,
            background=COLORS["surface"],
            highlightbackground=COLORS["line"],
            highlightthickness=1,
        )
        self.table.pack(fill="x", padx=12, pady=(0, 20))
        for index, weight in enumerate((14, 12, 9, 18, 9, 18)):
            self.table.grid_columnconfigure(index, weight=weight, uniform="schedule")

    @staticmethod
    def _action_button(
        parent: tk.Misc,
        text: str,
        command,
        secondary: bool = False,
    ) -> tk.Button:
        return tk.Button(
            parent,
            text=text,
            command=command,
            foreground=COLORS["navy"] if secondary else "white",
            background=COLORS["surface"] if secondary else COLORS["blue"],
            activebackground=COLORS["blue_soft"] if secondary else COLORS["blue_dark"],
            activeforeground=COLORS["navy"] if secondary else "white",
            relief="flat",
            cursor="hand2",
            padx=13,
            pady=8,
            font=("Segoe UI", 9, "bold"),
        )

    def _select_file(self) -> None:
        if self.loading:
            return
        filename = filedialog.askopenfilename(
            parent=self.root,
            title="Seleccionar Plan Horario UNIMET",
            filetypes=(("Horario PDF", "*.pdf"),),
        )
        if filename:
            self._start_processing(Path(filename))

    def _start_processing(self, path: Path) -> None:
        if self.loading:
            return
        self.loading = True
        self.welcome.itemconfigure(self.status_id, text=f"Leyendo {path.name}...", fill=COLORS["blue"])
        self.welcome.itemconfigure(self.button_shape, fill="#A9BDE9")
        threading.Thread(target=self._process_worker, args=(path,), daemon=True).start()

    def _process_worker(self, path: Path) -> None:
        try:
            classes = procesar_archivo(path)
            RESULTS_DIR.mkdir(parents=True, exist_ok=True)
            output = RESULTS_DIR / f"{path.stem}.csv"
            guardar_csv(output, classes)
        except Exception as exc:
            self.root.after(0, self._processing_failed, str(exc))
            return
        self.root.after(0, self._processing_done, path, classes, output)

    def _processing_failed(self, error: str) -> None:
        self.loading = False
        self.welcome.itemconfigure(self.button_shape, fill=COLORS["blue"])
        self.welcome.itemconfigure(self.status_id, text=error, fill=COLORS["error"])
        messagebox.showerror("Horario no válido", error, parent=self.root)

    def _processing_done(self, path: Path, classes: list[Clase], output: Path) -> None:
        self.loading = False
        self.current_csv = output
        period = classes[0].periodo if classes else ""
        self.period_label.configure(text=f"Periodo {period}")
        self.results_header.itemconfigure(
            self.result_subtitle_id,
            text=f"{path.name}\n{len(classes)} clases procesadas",
        )
        self._render_table(classes)
        self.show_results()

    def _render_table(self, classes: list[Clase]) -> None:
        for child in self.table.winfo_children():
            child.destroy()
        headers = ("DÍAS", "HORA", "AULA", "MATERIA", "SECCIÓN", "PROFESOR")
        for column, title in enumerate(headers):
            tk.Label(
                self.table,
                text=title,
                font=("Segoe UI", 8, "bold"),
                foreground=COLORS["navy"],
                background=COLORS["blue_soft"],
                pady=12,
            ).grid(row=0, column=column, sticky="nsew")

        palettes = (
            (COLORS["orange_soft"], COLORS["orange"]),
            (COLORS["teal_soft"], COLORS["teal"]),
            (COLORS["green_soft"], COLORS["green"]),
        )
        for row_index, clase in enumerate(classes, start=1):
            row_background = COLORS["surface"] if row_index % 2 else "#FAFCFF"
            day_background, day_foreground = palettes[(row_index - 1) % len(palettes)]
            values = (
                " y\n".join(clase.dias).replace("Evento Virtual", "Evento\nVirtual"),
                clase.hora.replace("-", "\n–\n") if clase.hora else "Sin hora",
                clase.aula or "Sin aula",
                clase.materia,
                clase.seccion,
                clase.profesor,
            )
            for column, value in enumerate(values):
                tk.Label(
                    self.table,
                    text=value,
                    font=("Segoe UI", 8 if column not in (0, 3) else 9, "bold" if column == 0 else "normal"),
                    foreground=day_foreground if column == 0 else COLORS["navy"],
                    background=day_background if column == 0 else row_background,
                    wraplength=75 if column in (0, 3, 5) else 55,
                    justify="center",
                    padx=5,
                    pady=15,
                    highlightbackground=COLORS["line"],
                    highlightthickness=1,
                ).grid(row=row_index, column=column, sticky="nsew")

    def show_welcome(self) -> None:
        self.results.pack_forget()
        self.welcome.pack(fill="both", expand=True)
        self.welcome.itemconfigure(self.status_id, text="")
        self.welcome.itemconfigure(self.button_shape, fill=COLORS["blue"])
        self.current_csv = None

    def show_results(self) -> None:
        self.welcome.pack_forget()
        self.results.pack(fill="both", expand=True)
        self.result_scroll.canvas.yview_moveto(0)

    def _open_csv(self) -> None:
        if self.current_csv and self.current_csv.exists():
            os.startfile(self.current_csv)

    def _show_error(self, text: str) -> None:
        self.welcome.itemconfigure(self.status_id, text=text, fill=COLORS["error"])
        messagebox.showerror("Archivo no válido", text, parent=self.root)

    @property
    def results_header(self) -> tk.Canvas:
        return self.results.winfo_children()[0]


def create_root() -> tk.Tk:
    if TkinterDnD is not None:
        try:
            root = TkinterDnD.Tk()
            root.dnd_available = True
            return root
        except RuntimeError:
            if tk._default_root is not None:
                try:
                    tk._default_root.destroy()
                except tk.TclError:
                    pass
                tk._default_root = None
    root = tk.Tk()
    root.dnd_available = False
    return root


def main() -> None:
    root = create_root()
    HorarioApp(root)
    root.mainloop()
