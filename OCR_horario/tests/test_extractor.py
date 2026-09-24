import unittest

from ocr_horarios.extractor import extraer_clases_texto


SAMPLE = """
PERIODO: 2025 - 007
PLAN HORARIO
DÍA HORA AULA ASIGNATURA SECCIÓN PROFESOR
Lunes 12:15:00-13:45:00 SL-006 Lab. de Prog FPTSP20 SIMULACIÓN FPTSP20-1 Quintero Dávila, José Luis
Miércoles 12:15:00-13:45:00 SL-006 Lab. de Prog FPTSP20 SIMULACIÓN FPTSP20-1 Quintero Dávila, José Luis
Martes 14:00:00-15:30:00 A2-OO7 1000-MA2-PB FPTSP19 OPTIMIZACION FPTSP19-1 Vivas García, Luis Alfonso
Evento Virtual FPTSP22 TALLER DE TRA FPTSP22-2 Peña Echezuria, José Alberto
Evento Virtual FGELI17 INTRODUCCION FGELI17-1 Ascanio Lara, Marisela
"""


class ExtractorTest(unittest.TestCase):
    def test_extrae_consolida_y_normaliza(self):
        classes = extraer_clases_texto(SAMPLE, "ejemplo.pdf")

        self.assertEqual(len(classes), 4)
        simulation = classes[0]
        self.assertEqual(simulation.dias, ("Lunes", "Miércoles"))
        self.assertEqual(simulation.hora, "12:15-13:45")
        self.assertEqual(simulation.aula, "SL-006")
        self.assertEqual(simulation.materia, "Simulación")
        self.assertEqual(simulation.seccion, "1")
        self.assertEqual(simulation.profesor, "José Luis Quintero Dávila")

        optimization = classes[1]
        self.assertEqual(optimization.aula, "A2-007")
        self.assertEqual(optimization.materia, "Optimización II")

        virtual = classes[2]
        self.assertEqual(virtual.aula, "Virtual")
        self.assertEqual(virtual.profesor, "José Alberto Peña Echezuria")

        elective = classes[3]
        self.assertEqual(elective.materia, "Introduccion")


if __name__ == "__main__":
    unittest.main()
