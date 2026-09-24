from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Clase:
    dias: tuple[str, ...]
    hora: str
    aula: str
    materia: str
    seccion: str
    profesor: str
    codigo: str
    periodo: str
    archivo: str

    def clave_consolidacion(self) -> tuple[str, ...]:
        return (
            self.hora,
            self.aula,
            self.codigo,
            self.materia,
            self.seccion,
            self.profesor,
            self.periodo,
            self.archivo,
        )

    def fila_publica(self) -> dict[str, str]:
        return {
            "DIAS": " / ".join(self.dias),
            "HORA": self.hora,
            "AULA": self.aula,
            "MATERIA(ASIGNATURA)": self.materia,
            "SECCION": self.seccion,
            "PROFESOR": self.profesor,
        }

    def fila_auditoria(self) -> dict[str, str]:
        return {
            **self.fila_publica(),
            "CODIGO": self.codigo,
            "PERIODO": self.periodo,
            "ARCHIVO": self.archivo,
        }

