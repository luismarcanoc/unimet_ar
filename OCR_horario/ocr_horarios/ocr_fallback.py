from __future__ import annotations

from pathlib import Path


class OcrNoDisponibleError(RuntimeError):
    pass


def extraer_texto_con_ocr(pdf_path: Path, idioma: str = "spa") -> str:
    """Renderiza un PDF escaneado y aplica Tesseract localmente.

    Esta ruta solo se usa cuando el PDF no contiene una capa de texto útil.
    Requiere requirements-ocr.txt y Tesseract instalado en el sistema.
    """
    try:
        import fitz
        import pytesseract
        from PIL import Image
    except ImportError as exc:
        raise OcrNoDisponibleError(
            "El PDF parece escaneado. Instala requirements-ocr.txt y Tesseract "
            "con el idioma español para habilitar el OCR local."
        ) from exc

    paginas: list[str] = []
    try:
        document = fitz.open(pdf_path)
        for page in document:
            pixmap = page.get_pixmap(matrix=fitz.Matrix(3, 3), alpha=False)
            image = Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)
            paginas.append(pytesseract.image_to_string(image, lang=idioma))
    except pytesseract.TesseractNotFoundError as exc:
        raise OcrNoDisponibleError(
            "Tesseract no está instalado o no está disponible en PATH."
        ) from exc

    return "\n".join(paginas)

