# Tutorial iPhone / macOS - UNIMET AR

Este documento explica como trabajar con este proyecto Flutter si van a probarlo en un iPhone.

## 1. Punto Clave

El codigo Flutter puede desarrollarse en Windows, macOS o Linux.

Pero para compilar e instalar la app nativa en un iPhone necesitas obligatoriamente:

- una Mac con macOS,
- Xcode instalado,
- Flutter instalado en esa Mac,
- un Apple ID,
- un iPhone conectado por cable o configurado para desarrollo inalambrico.

En Windows puedes editar el codigo Dart, hacer commits y preparar la logica. Lo que no puedes hacer desde Windows es firmar e instalar una app iOS nativa en un iPhone.

## 2. Que Ya Esta Listo En Este Repo

El repo ya tiene:

```text
ios/
ios/Runner.xcworkspace
ios/Runner/Info.plist
lib/main.dart
pubspec.yaml
```

Tambien tiene el permiso de camara en:

```text
ios/Runner/Info.plist
```

La clave configurada es:

```text
NSCameraUsageDescription
```

con el texto:

```text
La camara se usa para mostrar la guia AR sobre el entorno.
```

## 3. Preparar La Mac

En la Mac instala:

1. Xcode desde App Store.
2. Flutter.
3. CocoaPods, si Flutter lo pide.

Verifica:

```bash
flutter doctor
```

Si Flutter pide aceptar licencias de Xcode:

```bash
sudo xcodebuild -license accept
```

Si falta CocoaPods:

```bash
sudo gem install cocoapods
```

Luego:

```bash
flutter doctor
```

hasta que iOS quede sin errores importantes.

## 4. Llevar El Proyecto A La Mac

Puedes hacerlo de cualquiera de estas formas:

- clonar el repo desde GitHub,
- copiar la carpeta completa,
- usar una rama compartida.

Recomendado:

```bash
git clone URL_DEL_REPO
cd unimet_ar
```

Luego:

```bash
flutter pub get
```

## 5. Abrir En Xcode

En la Mac, dentro del proyecto:

```bash
open ios/Runner.xcworkspace
```

Importante: abre `Runner.xcworkspace`, no `Runner.xcodeproj`.

En Xcode:

1. Selecciona `Runner`.
2. Entra en `Signing & Capabilities`.
3. Activa `Automatically manage signing`.
4. En `Team`, elige tu Apple ID o equipo.
5. Cambia el `Bundle Identifier` a algo unico.

Ejemplo:

```text
com.unimet.ar.prototype
```

Si ese bundle ya existe o Xcode se queja, usa algo mas especifico:

```text
com.luismarcanoc.unimetar
```

## 6. Conectar El iPhone

1. Conecta el iPhone a la Mac.
2. Desbloquea el iPhone.
3. Si aparece `Trust This Computer`, toca `Trust`.
4. En Xcode, selecciona tu iPhone como dispositivo.

En iPhone puede hacer falta activar Developer Mode:

```text
Settings > Privacy & Security > Developer Mode
```

Activalo y reinicia el iPhone si iOS lo pide.

## 7. Ejecutar Desde Flutter

En la Mac:

```bash
flutter devices
```

Debe aparecer el iPhone.

Luego:

```bash
flutter run
```

Si hay varios dispositivos:

```bash
flutter run -d ID_DEL_IPHONE
```

## 8. Ejecutar Desde Xcode

Tambien puedes correr desde Xcode:

1. Abre `ios/Runner.xcworkspace`.
2. Selecciona tu iPhone.
3. Presiona `Run`.

Si Xcode instala la app pero iOS no la abre por confianza del desarrollador:

```text
Settings > General > VPN & Device Management
```

Busca tu Apple ID/equipo y toca `Trust`.

## 9. Errores Comunes En iPhone

### Xcode Pide Bundle Identifier Unico

Cambia:

```text
Runner > Signing & Capabilities > Bundle Identifier
```

Ejemplo:

```text
com.unimet.ar.prototype
```

### No Aparece El iPhone

Prueba:

- desbloquear el iPhone,
- aceptar `Trust This Computer`,
- cambiar cable,
- abrir Xcode una vez,
- correr `flutter doctor`,
- activar Developer Mode.

### Error De Pods

Corre:

```bash
cd ios
pod install
cd ..
flutter run
```

### Camara No Abre

Revisa en iPhone:

```text
Settings > Privacy & Security > Camera
```

La app debe tener permiso.

Tambien revisa que `Info.plist` tenga:

```text
NSCameraUsageDescription
```

## 10. Desarrollo Windows + Mac

Pueden trabajar asi:

1. Editan codigo Flutter en Windows.
2. Hacen commit/push.
3. En la Mac hacen pull.
4. Prueban en iPhone.
5. Si hay ajustes iOS de firma, se hacen en Xcode.

Normalmente el codigo principal sigue estando en:

```text
lib/main.dart
```

Eso no depende de la Mac.

Lo que si depende de la Mac:

- compilar para iOS,
- firmar la app,
- instalar en iPhone,
- usar Xcode,
- TestFlight/App Store.

## 11. Comandos Rapidos En Mac

```bash
cd unimet_ar
flutter pub get
flutter doctor
flutter devices
flutter run
```

Si quieres abrir Xcode:

```bash
open ios/Runner.xcworkspace
```

## 12. Recomendacion Para Este Proyecto

Desarrollen la mayor parte de la logica Flutter en cualquier computadora.

Cuando toque probar iPhone:

```text
Mac + Xcode + iPhone fisico
```

No hace falta reescribir la app en Swift. Flutter ya genera el proyecto iOS y usa el mismo codigo Dart.
