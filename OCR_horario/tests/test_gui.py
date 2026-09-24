import unittest

from ocr_horarios.extractor import HorarioInvalidoError
from ocr_horarios.gui import validar_horario_unimet


class ValidacionGuiTest(unittest.TestCase):
    def test_acepta_marcadores_del_plan_horario(self):
        validar_horario_unimet(
            "PERIODO: 2025 - 007 PLAN HORARIO DÍA ASIGNATURA PROFESOR"
        )

    def test_rechaza_otro_pdf(self):
        with self.assertRaises(HorarioInvalidoError):
            validar_horario_unimet("FLUJOGRAMA DE INGENIERÍA DE SISTEMAS")


if __name__ == "__main__":
    unittest.main()
