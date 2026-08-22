# UNIMET AR

Prototipo Flutter para probar guia visual sobre camara usando coordenadas locales.

## Estado

Este repo contiene el codigo Dart de la app. En esta maquina `flutter` no esta disponible en el PATH, asi que no se pudieron generar las carpetas nativas con `flutter create`.

Cuando tengas Flutter instalado/configurado, ejecuta dentro de esta carpeta:

```bash
powershell -ExecutionPolicy Bypass -File .\tool\setup_flutter_project.ps1
flutter run
```

## Prueba en casa

La app trae puntos falsos:

```text
CASA-ENTRADA: x=0, y=0
CASA-SALA: x=2, y=1
CASA-COCINA: x=5, y=1
CASA-CUARTO: x=5, y=-2
CASA-BANO: x=3, y=-2
```

Flujo:

1. Selecciona donde estas.
2. Selecciona destino.
3. Abre guia AR.
4. Mueve el slider de orientacion para simular hacia donde apunta el telefono.

Luego se puede reemplazar el slider por brujula/sensores del telefono.
