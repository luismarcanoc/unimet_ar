from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .exporter import guardar_csv, guardar_excel
from .extractor import HorarioInvalidoError, extraer_horario
from .ocr_fallback import OcrNoDisponibleError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extrae horarios UNIMET a CSV y Excel.",
    )
    parser.add_argument(
        "entrada",
        nargs="?",
        default=".",
        help="PDF de horario o carpeta con PDFs (por defecto: carpeta actual)",
    )
    parser.add_argument(
        "--salida",
        default="resultados",
        help="Carpeta de salida (por defecto: resultados)",
    )
    parser.add_argument(
        "--sin-ocr",
        action="store_true",
        help="No intentar OCR cuando un PDF no tenga texto",
    )
    return parser


def _pdfs(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    return sorted(
        pdf
        for pdf in path.glob("*.pdf")
        if "flujograma" not in pdf.name.lower()
    )


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    input_path = Path(args.entrada).resolve()
    output_path = Path(args.salida).resolve()
    files = _pdfs(input_path)
    if not files:
        print(f"No se encontraron horarios PDF en {input_path}", file=sys.stderr)
        return 2

    groups: dict[str, list] = {}
    all_classes = []
    failures = 0
    for pdf in files:
        try:
            classes = extraer_horario(pdf, permitir_ocr=not args.sin_ocr)
        except (HorarioInvalidoError, OcrNoDisponibleError, ValueError) as exc:
            failures += 1
            print(f"ERROR {pdf.name}: {exc}", file=sys.stderr)
            continue

        groups[pdf.stem[:31]] = classes
        all_classes.extend(classes)
        guardar_csv(output_path / f"{pdf.stem}.csv", classes)
        print(f"OK {pdf.name}: {len(classes)} materias/clases consolidadas")

    if groups:
        guardar_csv(output_path / "todos_los_horarios.csv", all_classes, auditoria=True)
        try:
            guardar_excel(output_path / "todos_los_horarios.xlsx", groups)
        except RuntimeError as exc:
            print(f"AVISO: {exc}", file=sys.stderr)
            print("Los archivos CSV se generaron correctamente.", file=sys.stderr)
        print(f"Resultados guardados en: {output_path}")
    return 1 if failures else 0
