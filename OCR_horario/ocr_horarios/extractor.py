from __future__ import annotations

import re
import unicodedata
from collections import OrderedDict
from pathlib import Path

from pypdf import PdfReader

from .catalog import CatalogoMaterias
from .models import Clase
from .ocr_fallback import extraer_texto_con_ocr


DIAS = ("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo")
ORDEN_DIAS = {dia: index for index, dia in enumerate(DIAS)}
ORDEN_DIAS["Evento Virtual"] = len(DIAS)

ROW_RE = re.compile(
    r"^(?P<dia>Lunes|Martes|Mi[eé]rcoles|Jueves|Viernes|S[aá]bado|Domingo)\s+"
    r"(?P<hora>\d{2}:\d{2}(?::\d{2})?-\d{2}:\d{2}(?::\d{2})?)\s+"
    r"(?P<body>.+)$",
    re.IGNORECASE,
)
VIRTUAL_RE = re.compile(r"^Evento\s+Virtual\s+(?P<body>.+)$", re.IGNORECASE)
COURSE_SECTION_RE = re.compile(r"\b(?P<codigo>[A-Z]{3,}\d{2})-(?P<seccion>\d+)\b")
COURSE_CODE_RE = re.compile(r"\b[A-Z]{3,}\d{2}\b")
ROOM_RE = re.compile(r"^(?P<aula>(?:A\d|SL)-[A-Z0-9]{3})\b", re.IGNORECASE)
PERIOD_RE = re.compile(r"PERIODO:\s*(\d{4})\s*-\s*(\d{3})", re.IGNORECASE)


class HorarioInvalidoError(ValueError):
    pass


def _sin_acentos(value: str) -> str:
    return "".join(
        char
        for char in unicodedata.normalize("NFD", value)
        if unicodedata.category(char) != "Mn"
    )


def _dia_canonico(value: str) -> str:
    normal = _sin_acentos(value).lower()
    return next((dia for dia in DIAS if _sin_acentos(dia).lower() == normal), value.title())


def _hora_corta(value: str) -> str:
    inicio, fin = value.split("-", 1)
    return f"{inicio[:5]}-{fin[:5]}"


def _aula_canonica(value: str) -> str:
    aula = value.upper().strip()
    prefix, number = aula.split("-", 1)
    number = number.replace("O", "0")
    return f"{prefix}-{number}"


def _profesor_nombre_apellido(value: str) -> str:
    clean = re.sub(r"\s+", " ", value).strip(" ,")
    if "," not in clean:
        return clean
    apellidos, nombres = (part.strip() for part in clean.split(",", 1))
    return f"{nombres} {apellidos}".strip()


def extraer_texto_pdf(pdf_path: Path, permitir_ocr: bool = True) -> str:
    reader = PdfReader(str(pdf_path))
    text = "\n".join(
        page.extract_text(extraction_mode="layout", layout_mode_space_vertically=False)
        or ""
        for page in reader.pages
    )
    if len(text.strip()) >= 100:
        return text
    if permitir_ocr:
        return extraer_texto_con_ocr(pdf_path)
    raise HorarioInvalidoError(f"{pdf_path.name} no contiene texto extraíble")


def _separar_body(body: str) -> tuple[str, str, str, str, str]:
    section_matches = list(COURSE_SECTION_RE.finditer(body))
    if not section_matches:
        raise HorarioInvalidoError(f"No se encontró código-sección en: {body}")

    section_match = section_matches[-1]
    codigo = section_match.group("codigo").upper()
    seccion = section_match.group("seccion")
    profesor = _profesor_nombre_apellido(body[section_match.end() :])
    before_section = body[: section_match.start()].rstrip()

    code_matches = [match for match in COURSE_CODE_RE.finditer(before_section) if match.group() == codigo]
    if not code_matches:
        code_matches = list(COURSE_CODE_RE.finditer(before_section))
    if not code_matches:
        raise HorarioInvalidoError(f"No se encontró código de materia en: {body}")

    code_match = code_matches[-1]
    printed_name = before_section[code_match.end() :].strip()
    location_part = before_section[: code_match.start()].strip()
    room_match = ROOM_RE.match(location_part)
    aula = _aula_canonica(room_match.group("aula")) if room_match else ""
    return aula, codigo, printed_name, seccion, profesor


def extraer_clases_texto(
    text: str,
    archivo: str,
    catalogo: CatalogoMaterias | None = None,
) -> list[Clase]:
    catalogo = catalogo or CatalogoMaterias()
    period_match = PERIOD_RE.search(text)
    periodo = "-".join(period_match.groups()) if period_match else ""
    clases: list[Clase] = []

    for raw_line in text.splitlines():
        line = re.sub(r"\s+", " ", raw_line).strip()
        row_match = ROW_RE.match(line)
        virtual_match = VIRTUAL_RE.match(line)
        if not row_match and not virtual_match:
            continue

        if row_match:
            dia = _dia_canonico(row_match.group("dia"))
            hora = _hora_corta(row_match.group("hora"))
            body = row_match.group("body")
        else:
            dia = "Evento Virtual"
            hora = ""
            body = virtual_match.group("body")

        aula, codigo, printed_name, seccion, profesor = _separar_body(body)
        if dia == "Evento Virtual" and not aula:
            aula = "Virtual"
        clases.append(
            Clase(
                dias=(dia,),
                hora=hora,
                aula=aula,
                materia=catalogo.nombre(codigo, printed_name),
                seccion=seccion,
                profesor=profesor,
                codigo=codigo,
                periodo=periodo,
                archivo=archivo,
            )
        )

    if not clases:
        raise HorarioInvalidoError(f"No se encontraron clases en {archivo}")
    return consolidar_clases(clases)


def consolidar_clases(clases: list[Clase]) -> list[Clase]:
    grouped: OrderedDict[tuple[str, ...], Clase] = OrderedDict()
    for clase in clases:
        key = clase.clave_consolidacion()
        if key not in grouped:
            grouped[key] = clase
            continue
        current = grouped[key]
        days = tuple(
            sorted(set(current.dias + clase.dias), key=lambda day: ORDEN_DIAS.get(day, 99))
        )
        grouped[key] = Clase(**{**current.__dict__, "dias": days})
    return list(grouped.values())


def extraer_horario(pdf_path: Path, permitir_ocr: bool = True) -> list[Clase]:
    text = extraer_texto_pdf(pdf_path, permitir_ocr=permitir_ocr)
    return extraer_clases_texto(text, pdf_path.name)

