# OCR de Horarios UNIMET

Extractor local para planes de horario de la Universidad Metropolitana. Lee los
PDF, reconstruye las columnas, cruza cada código con el nombre completo de la
materia y exporta CSV/XLSX.

## Por qué no aplica OCR a todos los archivos

Los horarios incluidos contienen una capa de texto. Leer esa capa es más rápido
y preciso que reconocer visualmente la página, especialmente para códigos y
aulas como `A2-002`. Si se recibe un PDF escaneado, el programa puede usar
Tesseract como fallback local.

## Instalación

```powershell
python -m pip install -r requirements.txt
```

`openpyxl` viene incluido en esos requisitos para generar XLSX. Si no está
instalado, el programa mantiene la salida CSV y muestra un aviso.

## Interfaz gráfica

Ejecuta desde esta carpeta:

```powershell
python main.py
```

Se abrirá una ventana vertical donde puedes arrastrar un horario PDF o buscarlo
en el equipo. Después de validarlo, muestra las clases en seis categorías y
guarda automáticamente el CSV dentro de `resultados/`.

La interfaz solo acepta PDF que contengan las marcas del formato Plan Horario
UNIMET. El procesamiento es completamente local.

La antigua herramienta por comandos sigue disponible para procesamiento en lote:

```powershell
python -m ocr_horarios.cli . --salida resultados
```

El programa ignora automáticamente los PDF cuyo nombre contiene `flujograma`.

## Resultados

- Un CSV por horario con las columnas solicitadas.
- `todos_los_horarios.xlsx`, con una hoja por PDF.
- `todos_los_horarios.csv`, que añade `CODIGO`, `PERIODO` y `ARCHIVO` para
  permitir auditoría y distinguir trimestres.

Las clases que se repiten dos días con la misma hora, aula, sección y profesor
se consolidan en una sola fila, por ejemplo `Lunes / Miércoles`.

## Base de materias

`data/materias.json` contiene el cruce código-nombre obtenido del flujograma.
Puede ampliarse manualmente. Las electivas `FGE...` que no estén en el catálogo
conservan el nombre disponible en el horario; el programa nunca inventa el
nombre faltante.

## PDF escaneado (opcional)

Para habilitar OCR local:

```powershell
python -m pip install -r requirements-ocr.txt
```

También debe instalarse Tesseract OCR con el paquete de idioma español y dejar
`tesseract.exe` disponible en `PATH`. Esta dependencia no hace falta para los
PDF actuales.
