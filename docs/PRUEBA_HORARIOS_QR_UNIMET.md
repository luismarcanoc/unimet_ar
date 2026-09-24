# Prueba conjunta: horarios, salones reales y QR de pisos

Fecha: 23 de septiembre de 2026. Edificio propuesto: **A1**, por la cantidad de
salones y porque aparece en los horarios de ejemplo. Pisos propuestos: **PB y 1**.
Confirmar nomenclatura y disponibilidad antes de imprimir o instalar.

## Antes de salir

1. Ambos integrantes actualizan el repositorio y anotan el mismo commit.
2. Instalar la compilacion release segun [INTEGRACION_HORARIOS.md](INTEGRACION_HORARIOS.md).
3. Exportar el ultimo CSV real del registro; revisar visualmente varios nombres
   y pisos. No sustituir ubicaciones ausentes por puntos de casa.
4. Tener el CSV y un horario PDF en Archivos. Primero probar que se importan.
5. Imprimir estas dos hojas en A4 al 100%, sin ajustar a pagina:
   - [A1 - Planta baja](../output/pdf/QR_A1-PB.pdf).
   - [A1 - Piso 1](../output/pdf/QR_A1-P1.pdf).
6. Comprobar con regla la linea de control de 50 mm. La imagen cuadrada completa,
   incluyendo margen blanco, mide 160 mm. No recortar, plastificar con brillo
   fuerte ni colocar sobre superficies curvas.
7. Llevar cinta removible, regla, bateria cargada y una hoja para notas. Obtener
   permiso de instalacion; no bloquear senales o accesos.

Los QR y los PDF estan versionados; la companera los recibe con `git pull`.
No necesita ejecutar Python para imprimirlos.

## Instalacion y registro

1. Elegir una pared fija y bien iluminada junto a una referencia reconocible
   (por ejemplo el acceso a la escalera) en **cada piso confirmado**.
2. Colocar A1-PB solo en PB y A1-P1 solo en piso 1. No intercambiarlos.
3. Registrar para cada hoja: foto del lugar, referencia verbal, fecha, persona,
   altura del centro sobre el piso, dimensiones impresas y orientacion de la pared.
4. Si miden coordenadas, conservar metodo y precision. No convertir una lectura
   GPS imprecisa en una coordenada de ancla "exacta".
5. `docs/markers/floor_anchors.json` contiene identificadores y campos de
   medicion pendientes con `null` y `calibrated: false`. **Rellenar ese archivo
   no activa calibracion en la app**: aun falta implementar y verificar el enlace
   con ARKit sobre un sistema de referencia medido.

## Prueba A: horario y catalogo, sin QR

1. En **Salones**, importar el CSV real. Revisar cantidad aceptada y omitida.
2. Buscar un salon conocido de A1: cotejar nombre, piso y referencia con la puerta.
3. En **Horario**, cargar PDF, revisar todas las clases y confirmar.
4. Comparar manualmente contra el PDF: materia completa, seccion, profesor, dias,
   horas y aula. Una fila faltante es un fallo aunque otras se vean correctas.
5. Elegir una clase con aula registrada y abrir **Ir a [aula]**. Debe coincidir
   con el destino de buscar el mismo salon manualmente.
6. Verificar una clase virtual o un aula no registrada: no debe inventar destino.
7. Cerrar y volver a abrir la app. Horario y salones deben permanecer.
8. Exportar CSV a Archivos y reimportarlo. El contenido debe conservarse.
9. Cancelar una importacion o seleccionar un documento ajeno: el horario previo
   debe seguir disponible.

No se incluye un CSV ficticio para aprobar esta prueba. Si falta un aula real,
anotarla como pendiente de levantamiento y continuar con otra registrada.

## Prueba B: direccion GPS real

1. Elegir un salon real desde el horario o la busqueda, sin escanear QR.
2. Empezar a 30-50 m en un tramo peatonal seguro; primero exterior, luego pasillo
   recto del mismo piso. No usar esta guia para atravesar paredes o elegir escaleras.
3. Esperar estabilizacion y girar suavemente a ambos lados. Comparar la flecha
   con la direccion fisica del destino y anotar saltos o inversiones.
4. Caminar un tramo corto, detenerse y repetir. Hacer al menos tres intentos por
   destino, desde el mismo inicio, anotando interior/exterior y hora.
5. Cerca del salon puede aparecer falta de precision: no forzar una flecha cuando
   el error del GPS es mayor que la distancia restante. Comparar con la puerta.
6. Copiar diagnostico de la guia cuando falle. Registrar precision del telefono y
   del destino, distancia, rumbo, estado AR y cualquier mensaje de sensor.

Usar tambien [PRUEBA_FISICA_UNIMET.md](PRUEBA_FISICA_UNIMET.md) y
[PLANTILLA_RESULTADOS_GPS.md](PLANTILLA_RESULTADOS_GPS.md). Una persona observa el
camino y otra toma notas. Detenerse para mirar la pantalla; nunca en escaleras.

## Prueba C: QR de piso + destino real

1. Volver a la pantalla principal. Pulsar el icono QR dentro de la app, no la
   camara del sistema. Estos payloads no abren una web ni estan registrados como
   enlaces de apertura de la app.
2. Apuntar a A1-PB a unos 0.5-1.5 m, encuadrando todo el QR; ajustar distancia
   y luz si no se detecta. Debe aparecer **Piso identificado: A1 - Planta baja**
   (el separador visual puede variar) y el listado filtrado de salones A1/PB.
3. Abrir un destino real de ese piso. La guia sigue usando su GPS real.
4. Volver, escanear A1-P1 y comprobar que cambia a piso 1, sin mezclar resultados.
5. En Horario, seleccionar un destino de otro piso: debe advertir la diferencia.
6. Quitar el filtro con X y confirmar que la busqueda de otros edificios sigue
   disponible. Leer un QR ajeno: debe rechazarse sin cambiar el piso.
7. Repetir QR -> volver -> guia AR tres veces. Comprobar que la camara se libera
   entre pantallas y no aparece error 102. Guardar diagnostico si falla.
8. Cerrar/reabrir la app: el piso escaneado se descarta para evitar conservar un
   piso incorrecto en otra visita; el horario y el catalogo permanecen.

Los auditorios o departamentos con nombres sin prefijo de edificio siguen
disponibles en la busqueda general, pero no se asignan a A1 por suposicion. El CSV
actual no tiene una columna separada de edificio; conviene agregarla en una
iteracion del registro para filtrarlos de forma fiable.

**Esta prueba no demuestra precision QR+ARKit.** Un QR identifica un lugar solo
si se instala correctamente; no corrige el GPS ni calcula una ruta interior.
La prueba de anclaje preciso requiere completar las mediciones y la integracion
indicadas en la guia de horarios. La demo historica CASA-QR no sirve como prueba
de coordenadas de A1 y ya no se ofrece en el inicio.

## Hoja de resultados

| Dato | Valor a completar |
| --- | --- |
| Commit / modelo / iOS | |
| CSV real: nombre, fecha, numero de registros | |
| PDF horario y periodo | |
| Salon de destino, piso, referencia | |
| ID de QR / lugar fisico / altura / foto | |
| Inicio y distancia aproximada comprobada | |
| Precision GPS telefono / registro | |
| Flecha: estable, invertida, pausada, otro | |
| Estado AR / texto exacto de error | |
| Tiempo y distancia a la que se detecta QR | |
| Error observado al llegar / limite de la prueba | |
| Resultado de importacion, exportacion y persistencia | |

## Regenerar las hojas (solo si cambian los identificadores)

```bash
python3 -m pip install -r tool/requirements-qr.txt
python3 tool/generate_floor_qrs.py
flutter test
```

Mantener sincronizados `docs/markers/floor_anchors.json` y `lib/floor_markers.dart`;
la prueba comprueba sus payloads. Versionar JSON, PNG, PDF y documentos juntos.
No reutilizar una hoja ya instalada para identificar otro piso.
