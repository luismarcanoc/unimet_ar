# UNIMET AR

Prototipo Flutter para probar una guia visual tipo AR usando coordenadas locales.

La primera version esta pensada para pruebas fisicas en casa:

- eliges donde estas,
- eliges un destino,
- abres una vista con camara,
- ves una flecha y distancia aproximada,
- simulas la orientacion del telefono con un slider.

Luego el slider se reemplaza por sensores del telefono y los puntos de prueba por salones reales.

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
- Dependencia `camera`.
- Datos falsos para prueba en casa.
- Pantalla de guia con camara/fallback.

Para probarlo en telefono real, conecta un Android con Depuracion USB activa y corre:

```powershell
flutter run
```
