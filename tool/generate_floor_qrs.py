"""Rebuild printable floor identifiers; does not invent surveyed coordinates."""

import json
from pathlib import Path

import qrcode
from reportlab.lib.colors import HexColor, black
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parents[1]


def main():
    markers = json.loads((ROOT / "docs/markers/floor_anchors.json").read_text())
    output = ROOT / "output/pdf"
    output.mkdir(parents=True, exist_ok=True)
    for marker in markers["markers"]:
        qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,
                           box_size=16, border=4)
        qr.add_data(marker["payload"])
        qr.make(fit=True)
        png = ROOT / "docs/markers" / f'{marker["id"]}.png'
        qr.make_image(fill_color="black", back_color="white").save(png)

        pdf = output / f'QR_{marker["id"]}.pdf'
        page = canvas.Canvas(str(pdf), pagesize=A4, invariant=1)
        width, height = A4
        page.setTitle(f'UNIMET AR - {marker["label"]}')
        page.setAuthor("UNIMET AR")
        page.setFillColor(HexColor("#17694d"))
        page.setFont("Helvetica-Bold", 12)
        page.drawString(25 * mm, height - 24 * mm, "UNIMET AR / PRUEBA DE CAMPO")
        page.setFillColor(black)
        page.setFont("Helvetica-Bold", 30)
        page.drawString(25 * mm, height - 43 * mm, marker["label"])
        page.setFont("Helvetica", 12)
        page.drawString(25 * mm, height - 53 * mm, "Identificador de piso - no es un anclaje AR calibrado")
        page.drawImage(str(png), (width - 160 * mm) / 2, 76 * mm,
                       width=160 * mm, height=160 * mm)
        page.setFont("Helvetica-Bold", 12)
        page.drawString(25 * mm, 66 * mm, f'ID: {marker["id"]}')
        page.setFont("Helvetica", 10)
        page.drawString(25 * mm, 59 * mm, marker["payload"])
        page.drawString(25 * mm, 47 * mm, "Escanear desde el boton QR de UNIMET AR.")
        page.drawString(25 * mm, 40 * mm, "Imprimir A4, escala 100%. No recortar el margen blanco.")
        page.drawString(25 * mm, 33 * mm, "Instalar solo despues de confirmar el piso y obtener permiso.")
        page.setLineWidth(1)
        page.line(25 * mm, 23 * mm, 75 * mm, 23 * mm)
        for x in [25, 75]:
            page.line(x * mm, 21 * mm, x * mm, 25 * mm)
        page.setFont("Helvetica", 9)
        page.drawString(80 * mm, 22 * mm, "Control de escala: 50 mm")
        page.save()
        print(pdf.relative_to(ROOT))


if __name__ == "__main__":
    main()
