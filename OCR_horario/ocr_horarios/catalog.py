from __future__ import annotations

import json
import re
from pathlib import Path


CATALOG_PATH = Path(__file__).resolve().parent.parent / "data" / "materias.json"


def normalizar_codigo(value: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", value.upper())


class CatalogoMaterias:
    def __init__(self, path: Path = CATALOG_PATH) -> None:
        data = json.loads(path.read_text(encoding="utf-8"))
        self._materias = {
            normalizar_codigo(code): name.strip() for code, name in data.items()
        }

    def nombre(self, codigo: str, nombre_impreso: str = "") -> str:
        code = normalizar_codigo(codigo)
        if code in self._materias:
            return self._materias[code]

        # Las electivas FGE no pertenecen al flujograma. Se conserva el nombre
        # disponible en el horario para no inventar información.
        fallback = re.sub(r"\s+", " ", nombre_impreso).strip(" -")
        return fallback.title() if fallback else f"Materia {code}"

