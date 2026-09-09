from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
SOURCE_IMAGE = ROOT / "docs" / "markers" / "UNIMET_AR_TEST_MARKER.png"
OUTPUT_FILE = ROOT / "output" / "pdf" / "CASA_QR_001_20CM.pdf"


def draw_centered_text(page: canvas.Canvas, text: str, y: float, font: str, size: int) -> None:
    page.setFont(font, size)
    page.drawCentredString(A4[0] / 2, y, text)


def build_pdf() -> None:
    if not SOURCE_IMAGE.exists():
        raise FileNotFoundError(f"No se encontro el QR fuente: {SOURCE_IMAGE}")

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    page_width, page_height = A4
    qr_size = 200 * mm
    qr_x = (page_width - qr_size) / 2
    qr_y = 42 * mm

    pdf = canvas.Canvas(str(OUTPUT_FILE), pagesize=A4, pageCompression=1)
    pdf.setTitle("Marcador de prueba UNIMET AR - CASA-QR-001")
    pdf.setAuthor("Proyecto UNIMET AR")

    pdf.setFillColorRGB(0.04, 0.12, 0.29)
    draw_centered_text(
        pdf,
        "MARCADOR DE PRUEBA UNIMET AR",
        page_height - 14 * mm,
        "Helvetica-Bold",
        16,
    )

    pdf.setFillColorRGB(0.16, 0.29, 0.50)
    draw_centered_text(
        pdf,
        "IMPRIMIR A TAMANO REAL (100%) - NO AJUSTAR A PAGINA",
        page_height - 23 * mm,
        "Helvetica-Bold",
        10,
    )
    draw_centered_text(
        pdf,
        "El cuadrado completo debe medir exactamente 20 x 20 cm.",
        page_height - 30 * mm,
        "Helvetica",
        9,
    )

    pdf.drawImage(
        str(SOURCE_IMAGE),
        qr_x,
        qr_y,
        width=qr_size,
        height=qr_size,
        preserveAspectRatio=True,
        mask="auto",
    )

    pdf.setFillColorRGB(0.04, 0.12, 0.29)
    draw_centered_text(pdf, "CASA-QR-001", 34 * mm, "Helvetica-Bold", 14)

    ruler_width = 50 * mm
    ruler_y = 24 * mm
    ruler_x = (page_width - ruler_width) / 2
    pdf.setStrokeColorRGB(0.10, 0.30, 0.65)
    pdf.setLineWidth(1.2)
    pdf.line(ruler_x, ruler_y, ruler_x + ruler_width, ruler_y)
    pdf.line(ruler_x, ruler_y - 2 * mm, ruler_x, ruler_y + 2 * mm)
    pdf.line(
        ruler_x + ruler_width,
        ruler_y - 2 * mm,
        ruler_x + ruler_width,
        ruler_y + 2 * mm,
    )

    pdf.setFillColorRGB(0.16, 0.29, 0.50)
    draw_centered_text(
        pdf,
        "Esta linea debe medir 5 cm",
        17 * mm,
        "Helvetica-Bold",
        9,
    )
    draw_centered_text(
        pdf,
        "Colocar plano y vertical, con el centro del QR a 1.50 m del piso.",
        9 * mm,
        "Helvetica",
        8,
    )

    pdf.showPage()
    pdf.save()
    print(OUTPUT_FILE)


if __name__ == "__main__":
    build_pdf()
