# Instalacion Completa En Mac - UNIMET AR

Este documento explica como preparar una Mac desde cero para instalar, compilar y ejecutar la app Flutter `unimet_ar` en un iPhone fisico.

## 1. Requisitos

Necesitas:

- Mac con macOS actualizado.
- Xcode instalado.
- Flutter instalado.
- CocoaPods instalado.
- Git instalado.
- Apple ID.
- iPhone fisico.
- Cable USB compatible con datos.

Recomendado:

- Tener al menos 20 GB libres.
- Usar una red estable.
- Mantener el iPhone desbloqueado durante la primera instalacion.

## 2. Instalar Xcode

1. Abre `App Store`.
2. Busca `Xcode`.
3. Instala Xcode.
4. Abre Xcode una vez.
5. Acepta licencias y componentes adicionales si los pide.

Luego abre Terminal y corre:

```bash
sudo xcodebuild -license accept
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verifica:

```bash
xcodebuild -version
```

Debe mostrar una version de Xcode.

## 3. Instalar Homebrew

Homebrew facilita instalar herramientas en macOS.

En Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Cuando termine, sigue las instrucciones que Homebrew imprime para agregarlo al PATH.

En Macs Apple Silicon normalmente sera algo como:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

En Macs Intel puede ser:

```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

Verifica:

```bash
brew --version
```

## 4. Instalar Git

En Terminal:

```bash
brew install git
```

Verifica:

```bash
git --version
```

## 5. Instalar Flutter

Opcion recomendada con Homebrew:

```bash
brew install --cask flutter
```

Cierra y abre Terminal de nuevo.

Verifica:

```bash
flutter --version
```

Si `flutter` no aparece, revisa el PATH o corre:

```bash
which flutter
```

## 6. Revisar Flutter Doctor

Corre:

```bash
flutter doctor
```

Flutter mostrara que partes estan listas y que falta.

Para este proyecto debe quedar bien especialmente:

```text
Flutter
Xcode
Connected device
```

Si Flutter indica problemas de iOS, sigue las recomendaciones que imprime.

## 7. Instalar CocoaPods

CocoaPods gestiona dependencias iOS.

Primero intenta:

```bash
sudo gem install cocoapods
```

Verifica:

```bash
pod --version
```

Si hay problemas con Ruby/Gem, alternativa con Homebrew:

```bash
brew install cocoapods
```

Luego:

```bash
pod --version
```

## 8. Obtener El Proyecto

### Opcion A: Clonar Desde GitHub

En la carpeta donde quieras trabajar:

```bash
git clone URL_DEL_REPO
cd unimet_ar
```

Ejemplo:

```bash
cd ~/Documents
git clone https://github.com/USUARIO/unimet_ar.git
cd unimet_ar
```

### Opcion B: Copiar La Carpeta

Tambien puedes copiar la carpeta completa `unimet_ar` desde Windows hacia la Mac.

Si haces esto, evita copiar carpetas generadas pesadas si no hacen falta:

```text
build/
.dart_tool/
```

Luego en la Mac:

```bash
cd ruta/a/unimet_ar
```

## 9. Instalar Dependencias Flutter

Dentro de `unimet_ar`:

```bash
flutter pub get
```

Si hay errores de iOS pods:

```bash
cd ios
pod install
cd ..
```

## 10. Verificar Permiso De Camara

El proyecto ya trae permiso de camara en:

```text
ios/Runner/Info.plist
```

Debe existir:

```text
NSCameraUsageDescription
```

con un texto parecido a:

```text
La camara se usa para mostrar la guia AR sobre el entorno.
```

Este permiso es obligatorio porque la app usa la camara para el overlay tipo AR.

## 11. Abrir El Proyecto En Xcode

Dentro de `unimet_ar`:

```bash
open ios/Runner.xcworkspace
```

Importante:

```text
Abre Runner.xcworkspace, no Runner.xcodeproj.
```

## 12. Configurar Firma En Xcode

En Xcode:

1. Selecciona `Runner` en el panel izquierdo.
2. Selecciona el target `Runner`.
3. Entra en `Signing & Capabilities`.
4. Marca `Automatically manage signing`.
5. En `Team`, elige tu Apple ID/equipo.
6. Cambia `Bundle Identifier` a uno unico.

Ejemplos:

```text
com.unimet.ar.prototype
com.luismarcanoc.unimetar
com.tesis.unimetar
```

Si Xcode dice que el identifier ya existe, usa otro.

## 13. Preparar El iPhone

1. Conecta el iPhone a la Mac.
2. Desbloquea el iPhone.
3. Si aparece `Trust This Computer`, toca `Trust`.
4. Mantén el iPhone conectado.

En iOS recientes puede hacer falta activar Developer Mode:

```text
Settings > Privacy & Security > Developer Mode
```

Activalo y reinicia el iPhone si lo pide.

## 14. Verificar Que Flutter Ve El iPhone

En Terminal:

```bash
flutter devices
```

Debe aparecer el iPhone.

Si no aparece:

- desbloquea el iPhone,
- acepta `Trust This Computer`,
- cambia el cable,
- abre Xcode,
- revisa Developer Mode,
- corre `flutter doctor`.

## 15. Ejecutar En iPhone Desde Flutter

Dentro de `unimet_ar`:

```bash
flutter run
```

Si hay varios dispositivos:

```bash
flutter devices
flutter run -d ID_DEL_IPHONE
```

La primera compilacion puede tardar.

## 16. Ejecutar En iPhone Desde Xcode

Tambien puedes hacerlo desde Xcode:

1. Abre `ios/Runner.xcworkspace`.
2. Selecciona tu iPhone arriba.
3. Presiona el boton `Run`.

Si Xcode instala la app pero iOS no la deja abrir:

```text
Settings > General > VPN & Device Management
```

Busca tu Apple ID/equipo y toca:

```text
Trust
```

## 17. Usar La App En iPhone

Al abrir la app:

1. Selecciona `Estoy en`.
2. Selecciona `Quiero ir a`.
3. Toca `Abrir guia AR`.
4. Acepta permiso de camara.
5. Veras la camara con una flecha encima.
6. Mueve el slider de orientacion simulada.

Por ahora el slider simula la brujula del telefono.

Mas adelante se reemplazara por orientacion real con sensores.

## 18. Comandos Rapidos

Desde `unimet_ar`:

```bash
flutter pub get
flutter doctor
flutter devices
flutter run
```

Para abrir Xcode:

```bash
open ios/Runner.xcworkspace
```

Para instalar pods manualmente:

```bash
cd ios
pod install
cd ..
```

## 19. Problemas Comunes

### Flutter No Detecta Xcode

Corre:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
flutter doctor
```

### Falta Aceptar Licencia De Xcode

```bash
sudo xcodebuild -license accept
```

### CocoaPods Falla

Prueba:

```bash
sudo gem install cocoapods
```

o:

```bash
brew install cocoapods
```

Luego:

```bash
cd ios
pod install
cd ..
```

### Error De Bundle Identifier

Cambia el bundle identifier en:

```text
Xcode > Runner > Signing & Capabilities > Bundle Identifier
```

Usa uno unico.

### iPhone No Confia En La App

En el iPhone:

```text
Settings > General > VPN & Device Management
```

Confia en el desarrollador.

### Camara No Abre

Revisa:

```text
Settings > Privacy & Security > Camera
```

La app debe tener permiso.

Tambien revisa `Info.plist`.

### Error Con Pods Despues De Cambiar Dependencias

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run
```

## 20. Flujo Recomendado Del Equipo

Pueden trabajar asi:

1. Editar codigo Flutter en Windows o Mac.
2. Subir cambios al repo.
3. En la Mac hacer pull.
4. Probar en iPhone.
5. Ajustar firma solo en Xcode si hace falta.

El codigo principal esta en:

```text
lib/main.dart
```

El iPhone no necesita codigo Swift nuevo para este prototipo.

## 21. Checklist Final

Antes de probar en iPhone:

```text
[ ] Xcode instalado
[ ] Flutter instalado
[ ] CocoaPods instalado
[ ] flutter doctor sin errores graves
[ ] Proyecto clonado/copiadado en la Mac
[ ] flutter pub get ejecutado
[ ] Runner.xcworkspace abierto en Xcode
[ ] Signing configurado
[ ] iPhone conectado y confiado
[ ] Developer Mode activado si iOS lo pide
[ ] flutter devices muestra el iPhone
[ ] flutter run ejecuta la app
```
