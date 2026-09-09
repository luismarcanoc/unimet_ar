# UNIMET AR

Prototipo Flutter para probar una guia visual tipo AR usando la ubicacion y los
sensores de un telefono real.

La primera version esta pensada para pruebas fisicas en casa:

- marcas uno o mas puntos de interes,
- eliges un unico destino,
- abres una vista con camara,
- ves una flecha tridimensional y la distancia aproximada,
- la brujula del telefono orienta la flecha automaticamente,
- la ubicacion en vivo actualiza la distancia mientras caminas.

Los puntos quedan guardados localmente en el telefono. Esta fase permite probar
el flujo en casa antes de conectar la aplicacion con los salones reales.

## Guia Completa

Lee el tutorial paso a paso aqui:

[docs/TUTORIAL_ANDROID.md](docs/TUTORIAL_ANDROID.md)

Para iPhone/macOS:

[docs/TUTORIAL_IOS.md](docs/TUTORIAL_IOS.md)

Instalacion completa desde cero en Mac:

[docs/INSTALACION_MAC_COMPLETA.md](docs/INSTALACION_MAC_COMPLETA.md)

## Comandos Rapidos

Desde esta carpeta:

```powershell
flutter pub get
flutter devices
flutter run
```

Si necesitas regenerar Android/iOS:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\setup_flutter_project.ps1
```

## Estructura Importante

```text
lib/main.dart                      Codigo principal del prototipo
pubspec.yaml                       Dependencias Flutter
android/                           Proyecto Android generado
ios/                               Proyecto iOS generado
tool/setup_flutter_project.ps1     Script para regenerar el proyecto nativo
docs/TUTORIAL_ANDROID.md           Tutorial de instalacion, ejecucion y uso
docs/TUTORIAL_IOS.md               Tutorial para compilar/probar en iPhone
docs/INSTALACION_MAC_COMPLETA.md   Instalacion completa en Mac desde cero
```

## Estado Actual

El proyecto ya tiene:

- Flutter app base.
- Soporte Android/iOS generado.
- Permiso de camara en Android.
- Permiso de camara en iOS.
- Permisos de ubicacion en Android/iOS.
- Registro, seleccion y borrado de puntos de interes.
- Prevencion de puntos duplicados a menos de 2 metros.
- Tutorial emergente durante el primer uso.
- Brujula automatica y seguimiento de ubicacion en vivo.
- Guia visual con flecha tridimensional sobre la camara.
- Prueba nativa iOS con QR, ARKit World Tracking y flechas 3D ancladas.

## Prueba QR + ARKit En iPhone

La hoja A4 lista para imprimir esta en:

```text
output/pdf/CASA_QR_001_20CM.pdf
```

Abre ese archivo en una computadora, imprime al 100% y desactiva `Ajustar a pagina`.
Confirma que el QR mida exactamente 20 x 20 cm y que la linea de control mida 5 cm.
Pegalo plano y vertical, con el centro a 1,50 m del piso. Tambien se conservan las
versiones PNG, SVG y HTML en `docs/markers/`.

En el iPhone:

1. Abre `Probar QR + ARKit`.
2. Mueve el telefono lentamente mientras ARKit reconoce el entorno.
3. Apunta al marcador `CASA-QR-001` desde 1 o 2 metros.
4. Al detectarlo apareceran cuatro flechas sobre el piso hacia la derecha del QR.

Esta prueba solo aparece en iOS. La ruta mide 3 metros y sirve para comprobar
anclaje, escala y estabilidad antes de incorporar los salones reales.

Para probarlo en telefono real, conecta un Android con Depuracion USB activa y corre:

```powershell
flutter run
```
