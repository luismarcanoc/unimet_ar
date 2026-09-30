# UNIMET AR + Horarios

Aplicacion Flutter para importar un Plan Horario UNIMET, consultar clases y
buscar salones con las coordenadas reales del registro. El PDF se procesa en el
telefono; no se envia a un servidor. El OCR original de escritorio se conserva
completo en `OCR_horario/`, junto con sus siete horarios, flujograma, catalogo,
ilustracion, pruebas y resultados CSV.

## Empezar

- [Integracion, instalacion y uso](docs/INTEGRACION_HORARIOS.md).
- [Prueba conjunta en UNIMET: horario, GPS y dos QR](docs/PRUEBA_HORARIOS_QR_UNIMET.md).
- [Instalacion desde cero en Mac](docs/INSTALACION_MAC_COMPLETA.md).
- [Android](docs/TUTORIAL_ANDROID.md).
- [Diagnostico detallado de GPS](docs/PRUEBA_FISICA_UNIMET.md).
- [Levantamiento de rutas y obstáculos](docs/LEVANTAMIENTO_RUTAS.md).

Se requiere Flutter >=3.44, Dart >=3.12 e iOS >=15.5. En la Mac ahora se necesita
CocoaPods para ML Kit, aunque otros plugins usen Swift Package Manager.

```bash
flutter pub get
flutter analyze
flutter test
flutter run --release -d ID_DEL_TELEFONO
```

En Mac, instalar CocoaPods (`brew install cocoapods`) si falta. La primera
compilacion descarga dependencias; seguir la guia de integracion antes de abrir
`ios/Runner.xcworkspace` en Xcode. No usar `flutter create` sobre este proyecto.

## Flujo Actual

1. **Salones:** importar el CSV real exportado desde el formulario de registro.
2. **Horario:** importar un PDF de Plan Horario o el CSV individual del OCR.
3. Revisar y confirmar las clases; filtrar por dia o exportar el horario a CSV.
4. Elegir **Ir al salon** desde una clase o buscarlo en **Salones**.
5. Opcional: leer uno de los QR de A1 con el boton QR de la app.

Las materias se cruzan por codigo con el catalogo completo. Las sesiones que
comparten materia, hora, aula, seccion y profesor se agrupan por dias. Un aula
sin registro no recibe coordenadas de otra: se muestra sin destino disponible.

No se generan puntos de casa ni coordenadas ficticias. Los registros personales
de versiones anteriores permanecen guardados, pero no aparecen en esta interfaz.
Los datos importados se guardan en ese telefono; importar un archivo no sincroniza
automaticamente otros dispositivos.

## QR Imprimibles

- [A1 - Planta baja](output/pdf/QR_A1-PB.pdf).
- [A1 - Piso 1](output/pdf/QR_A1-P1.pdf).

Son pisos propuestos pendientes de confirmar en campo. Estos QR **identifican
el piso y filtran salones; no recalibran GPS ni posicionan anclas ARKit**. Su
registro conserva coordenadas y orientacion sin asignar, nunca inventadas.
La guia a los salones sigue usando las coordenadas importadas.

## Limites Importantes

La app usa rutas transitables cuando el salón y el usuario estan conectados a la
red `assets/campus_routes.json`; mientras esa red siga vacia, avisa y usa
orientacion directa. No detecta paredes o arboles por GPS ni garantiza precision
de 2 metros. Se conservan el filtro
GPS, la pausa con mala precision, el rumbo de camara y el diagnostico anterior.
ARKit y el OCR de imagen deben comprobarse fisicamente en iPhone; en Android la
guia conserva su implementacion de camara y brujula.

Las pruebas antiguas CASA-QR y su codigo nativo se conservan como referencia,
pero no son destinos ni acciones de la nueva pantalla principal. No confundir
sus instrucciones historicas con la prueba actual de A1.

## Estructura

| Ruta | Uso |
| --- | --- |
| `lib/campus_home.dart` | Horario, busqueda, importacion y seleccion real |
| `lib/schedule.dart` | Validacion, materias, agrupacion y CSV |
| `lib/schedule_import.dart` | PDFium y OCR ML Kit en el telefono |
| `lib/salon_csv.dart` | CSV del formulario de coordenadas |
| `lib/floor_markers.dart`, `lib/floor_scanner.dart` | Identificacion de pisos |
| `lib/main.dart`, `lib/gps_navigation.dart` | Guia GPS y AR existente |
| `OCR_horario/` | Proyecto Python original completo, sin entornos ni cache |
| `docs/markers/floor_anchors.json` | Registro de QR y mediciones pendientes |
| `tool/generate_floor_qrs.py` | Regeneracion de los QR y hojas PDF |
| `output/pdf/` | Documentos imprimibles versionados |

Las siete muestras PDF se prueban contra los CSV originales en `flutter test`.
Los PDF contienen datos personales de ejemplo del proyecto original; no hacer
publico el repositorio ni redistribuir esas muestras sin revisar su contenido.
