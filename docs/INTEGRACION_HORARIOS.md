# Integracion de horarios y navegacion UNIMET

Actualizado: 23 de septiembre de 2026.

## 1. Que se integro

La copia `OCR_horario/` procede de `luismarcanoc/OCR_horario`, commit
`c4ff817c1e8c5eeab44156198256cd85c6f28fd9`. Se conservaron los archivos de
trabajo, los siete horarios PDF, el flujograma, ocho CSV de resultados, el
catalogo de materias, la ilustracion y las pruebas. Se excluyen exclusivamente
metadatos Git anidados, entornos instalados y cache. La carpeta del escritorio
no se borro ni se modifico.

Python/Tkinter no se ejecuta dentro del iPhone. Su logica de lectura y cruce de
materias se adapto a Dart; los PDF digitales se leen con PDFium (`pdfrx`), y los
PDF sin texto se renderizan para reconocerlos con ML Kit en iOS/Android. El
catalogo y la ilustracion se usan directamente desde la copia del proyecto.
No hay servidor de OCR, clave API, suscripcion ni envio del horario desde la app.
La seleccion desde iCloud/Drive puede requerir descargar primero el archivo.

## 2. Actualizar la Mac y el iPhone

1. Dentro del repositorio, conservar cualquier cambio propio antes de actualizar:

   ```bash
   git status --short
   git pull --ff-only
   git log -1 --oneline
   flutter --version
   ```

2. Se requiere Flutter >=3.44 y Dart >=3.12. Esta integracion fue verificada en
   Windows con Flutter 3.47.1. Usar la misma version en ambas computadoras reduce
   diferencias. El iPhone necesita iOS 15.5 o superior.

3. CocoaPods ahora es necesario para el plugin OCR, aunque el proyecto use
   Swift Package Manager para otros plugins:

   ```bash
   pod --version
   ```

   Si no existe y ya tienen Homebrew: `brew install cocoapods`.

4. Preparar dependencias y verificar el codigo:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter build ios --debug --no-codesign
   ```

   El ultimo comando debe ejecutarse en la Mac: prepara dependencias nativas y
   comprueba compilacion sin instalar. Flutter coordina SPM y CocoaPods. Si pide
   actualizar el repositorio de Pods, ejecutar desde la raiz:

   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```

   No borrar ni regenerar `ios/`; contiene las implementaciones ARKit y sensores.
   Si CocoaPods modifica `ios/Podfile.lock` o la integracion de Xcode, revisar y
   compartir esos cambios mediante Git para fijar lo resuelto en la Mac.

5. Abrir `ios/Runner.xcworkspace` en **Xcode**, seleccionar Runner, mantener su
   Team y Bundle Identifier, seleccionar el iPhone y revisar firma automatica.
   Si falla un paso anterior, conservar el mensaje completo y no continuar
   tratando la compilacion como exitosa.

6. Con el iPhone conectado, ejecutar desde la raiz:

   ```bash
   flutter devices
   flutter run --release -d ID_DEL_IPHONE
   ```

   Sustituir el identificador. Hay dependencias nativas nuevas: un hot reload no
   es suficiente. No hace falta desinstalar la app ni borrar sus datos. Los plazos
   de firma de Apple siguen siendo los de su cuenta.

Android usa la misma UI y reconocimiento local. Se necesita Android SDK para
compilar; la prueba de ARKit se hace exclusivamente en iPhone.

## 3. Preparar archivos en el telefono

- Exportar el CSV de **coordenadas reales** desde formulario_salones. Debe incluir
  nombre del salon, piso, latitud y longitud; precision y referencia son utiles.
- Pasarlo a Archivos del iPhone junto con un PDF **Plan Horario UNIMET** o uno de
  los CSV individuales en `OCR_horario/resultados/`.
- El CSV de coordenadas y el de horario son distintos y se cargan por separado.
- No cargar `todos_los_horarios.csv`: mezcla periodos historicos y se rechaza.
- Cada telefono importa su propia copia. El repositorio comparte codigo,
  ejemplos, QR y documentos, no los datos privados que cada alumno importe.

No se ha incluido un catalogo supuesto de coordenadas: falta recibir y validar
el CSV real definitivo del equipo. Un PDF de horario contiene el nombre del
salon, no su latitud y longitud.

## 4. Uso

1. Abrir **Salones** y usar el icono de importar. Revisar cuantos registros se
   aceptan y cuantas filas se omiten antes de confirmar reemplazo del catalogo.
2. En **Horario**, pulsar **Cargar horario**. Limites: 20 MB y 10 paginas.
3. Revisar dias, hora, aula, materia completa, seccion numerica y profesor en
   orden nombre-apellido. Confirmar para guardar. Cancelar conserva el anterior.
4. Elegir un dia en el selector. El menu permite exportar CSV o quitar solo el
   horario; no elimina las coordenadas.
5. Pulsar **Ir a [aula]** para abrir la guia existente. Las clases virtuales o las
   aulas sin registro no permiten navegar. Si hay varios registros con el mismo
   nombre normalizado, seleccionar el correcto; no se adivina por proximidad.
6. Para un destino fuera del horario, usar **Salones** y buscar por nombre,
   piso o referencia. Se conservan los registros importados de versiones anteriores.
7. El boton QR identifica los dos pisos de prueba de A1. El filtro se quita con
   la X. Al cambiar de piso, escanear el QR correspondiente: el GPS no lo detecta.

Una materia con sesiones a distintas horas o aulas ocupa mas de una tarjeta.
Si comparten hora, aula, materia, profesor y seccion, sus dias se agrupan.
Los codigos desconocidos (por ejemplo electivas fuera del flujograma) conservan
el nombre impreso: no se inventa el nombre completo.

## 5. Pruebas y limites

```bash
flutter analyze
flutter test
```

La prueba de integracion abre los siete PDF reales con PDFium y compara todos
sus campos con los CSV del OCR Python. Incluye round-trip de exportacion,
rechazo de entradas invalidas, correspondencia exacta de aulas, QR y UI estrecha.

El proyecto Python sigue funcionando independientemente:

```bash
cd OCR_horario
python3 -m pip install -r requirements.txt
python3 -m unittest discover -s tests
python3 main.py
```

Su fallback OCR opcional requiere las dependencias de `requirements-ocr.txt` y
Tesseract segun su README; no son requisitos para instalar la app Flutter.

En iPhone falta verificar: compilacion nativa, permisos, PDF escaneado real con
ML Kit, exportacion a Archivos, QR impreso, transicion QR/camara AR y recorrido
GPS. Las pruebas de Windows no validan esos sensores ni sustituyen la visita.

## 6. Lo que falta para navegacion interior precisa

1. Recibir y verificar el catalogo real: nombres, pisos y calidad de coordenadas.
2. Confirmar los dos pisos y ubicaciones fisicas de los QR de A1.
3. Medir posicion, orientacion y altura de los marcadores; elegir el sistema de
   referencia local, medir desplazamientos a puertas y registrar incertidumbre.
4. Implementar la asociacion de deteccion de imagen ARKit con ese marco medido.
   Leer el texto de un QR no da automaticamente una pose 3D de precision.
5. Levantar un grafo de pasillos, puertas y escaleras para rutas transitables.

La version actual conserva orientacion GPS y AR existente, sin prometer llegada
a una puerta con error de 2 m. Ver la guia de campo antes de evaluar resultados.

## Referencias tecnicas

- [ML Kit: reconocimiento en iOS, dependencias nativas y lectura de bloques](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios).
- Las versiones efectivas de los plugins estan fijadas en `pubspec.lock`; sus
  requisitos locales prevalecen sobre ejemplos de otras versiones.
