# Tutorial Android - UNIMET AR

Este documento explica como instalar, ejecutar y usar el prototipo `unimet_ar` sin depender del chat.

## 1. Que Es Este Proyecto

`unimet_ar` es un prototipo Flutter para probar la parte visual de realidad aumentada del mapa UNIMET.

Por ahora no usa coordenadas GPS reales ni rutas reales de la universidad. Usa coordenadas locales de prueba, como si tu casa fuera un mini edificio:

```text
CASA-ENTRADA: x=0, y=0
CASA-SALA:    x=2, y=1
CASA-COCINA:  x=5, y=1
CASA-CUARTO:  x=5, y=-2
CASA-BANO:    x=3, y=-2
```

La app calcula:

```text
distancia desde posicion actual hasta destino
direccion/bearing hacia el destino
flecha relativa sobre la camara
```

## 2. Requisitos En La Computadora

Necesitas:

- Windows.
- Flutter instalado.
- Android Studio o Android SDK instalado.
- Un telefono Android fisico.
- Cable USB que transfiera datos, no solo carga.

Para verificar Flutter:

```powershell
flutter --version
flutter doctor
```

Si `flutter` no se reconoce, agrega Flutter al PATH o abre una terminal donde Flutter ya funcione.

## 3. Preparar El Proyecto

Abre una terminal en:

```powershell
C:\Users\lolui\Documents\TESIS\unimet_ar
```

Puedes hacerlo con:

```powershell
cd C:\Users\lolui\Documents\TESIS\unimet_ar
```

Instala dependencias:

```powershell
flutter pub get
```

Si por alguna razon faltan carpetas como `android/` o `ios/`, corre:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\setup_flutter_project.ps1
```

Ese script:

- corre `flutter create`,
- genera Android/iOS,
- restaura `lib/main.dart`,
- restaura `pubspec.yaml`,
- agrega permiso de camara en Android,
- agrega permiso de camara en iOS,
- corre `flutter pub get`.

## 4. Activar Opciones De Desarrollador En Android

En el telefono:

```text
Ajustes
Acerca del telefono
Numero de compilacion
```

Toca `Numero de compilacion` unas 7 veces.

Si pide PIN, colocalo.

Debe aparecer algo parecido a:

```text
Ya eres desarrollador
```

Rutas comunes segun marca:

```text
Samsung:
Ajustes > Acerca del telefono > Informacion de software > Numero de compilacion

Xiaomi / Redmi / POCO:
Ajustes > Acerca del telefono > Version MIUI / Version HyperOS

Motorola / Pixel:
Ajustes > Acerca del telefono > Numero de compilacion
```

## 5. Activar Depuracion USB

Despues de activar opciones de desarrollador:

```text
Ajustes
Sistema
Opciones de desarrollador
Depuracion USB
Activar
```

Rutas comunes:

```text
Samsung:
Ajustes > Opciones de desarrollador > Depuracion USB

Xiaomi / Redmi / POCO:
Ajustes > Ajustes adicionales > Opciones de desarrollador > Depuracion USB

Motorola / Pixel:
Ajustes > Sistema > Opciones de desarrollador > Depuracion USB
```

Tambien conviene activar:

```text
Instalar via USB
```

si el telefono lo muestra.

## 6. Conectar El Telefono

1. Conecta el telefono por USB.
2. Si aparece modo USB, elige:

```text
Transferencia de archivos
```

o:

```text
MTP
```

3. En el telefono debe aparecer:

```text
Permitir depuracion USB?
```

Marca:

```text
Permitir siempre desde esta computadora
```

y toca:

```text
Aceptar
```

## 7. Verificar Que Flutter Ve El Telefono

En la terminal:

```powershell
flutter devices
```

Debe aparecer algo parecido a:

```text
SM-A525F (mobile) - android-arm64 - Android
```

Si solo aparece:

```text
Windows
Chrome
Edge
```

entonces el telefono no esta conectado correctamente o no acepto la depuracion USB.

## 8. Ejecutar La App

Con el telefono detectado:

```powershell
flutter run
```

Si hay varios dispositivos:

```powershell
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

Ejemplo:

```powershell
flutter run -d R58N123ABC
```

La primera ejecucion puede tardar bastante porque compila Android.

## 9. Como Usar El Prototipo

Al abrir la app veras:

```text
UNIMET AR
Estoy en
Quiero ir a
Ruta calculada
Abrir guia AR
```

Uso:

1. En `Estoy en`, selecciona tu punto actual.
2. En `Quiero ir a`, selecciona el destino.
3. Revisa la distancia calculada.
4. Toca `Abrir guia AR`.
5. Acepta el permiso de camara si Android lo pide.
6. Mira la pantalla con camara y flecha.
7. Mueve el slider de `Orientacion simulada`.

El slider simula hacia donde apunta el telefono.

Cuando el slider coincide con la direccion correcta, la app dira:

```text
Sigue derecho
```

Si no coincide, dira cosas como:

```text
Gira a la derecha
Gira a la izquierda
Date la vuelta
```

## 10. Que Validamos Con Esta Prueba

Esta version sirve para validar:

- flujo de seleccion de origen/destino,
- calculo de distancia,
- calculo de direccion,
- overlay sobre camara,
- permiso de camara,
- claridad de instrucciones visuales.

Todavia no valida:

- brujula real del telefono,
- posicion interior automatica,
- rutas reales de UNIMET,
- conexion con backend de salones.

## 11. Prueba En Casa Recomendada

Usa tu casa como edificio falso.

Ejemplo:

```text
CASA-ENTRADA = puerta principal
CASA-SALA = sala
CASA-COCINA = cocina
CASA-CUARTO = cuarto
CASA-BANO = bano
```

Prueba estos flujos:

```text
Entrada -> Cocina
Sala -> Cuarto
Cuarto -> Bano
Cocina -> Entrada
```

Lo importante es ver si la flecha y las instrucciones se sienten comprensibles.

## 12. Problemas Comunes

### Flutter No Reconoce El Telefono

Prueba:

```powershell
flutter devices
```

Si no aparece:

- cambia el cable USB,
- activa transferencia de archivos,
- desactiva y reactiva Depuracion USB,
- acepta la ventana de permiso en el telefono,
- reinicia la terminal,
- corre `flutter doctor`.

### El Telefono Solo Carga

El cable puede ser solo de carga.

Usa un cable que permita datos.

### Error De Licencias Android

Corre:

```powershell
flutter doctor --android-licenses
```

Acepta las licencias con `y`.

### No Abre La Camara

Revisa que Android haya pedido permiso.

Tambien puedes verificar en:

```text
Ajustes > Apps > UNIMET AR > Permisos > Camara
```

Debe estar permitido.

### Quiero Probar Sin Telefono

Puedes generar soporte web:

```powershell
flutter create --platforms web .
flutter run -d chrome
```

Esto sirve para pantallas y logica. La camara puede comportarse distinto en navegador.

## 13. Proximos Pasos Del Proyecto

Despues de probar en Android fisico, las siguientes mejoras naturales son:

1. Reemplazar el slider por orientacion real del telefono.
2. Conectar con el backend de salones en Vercel/Neon.
3. Cargar salones reales como destinos.
4. Agregar modo universidad y modo casa.
5. Calcular rutas usando coordenadas reales/locales por salon.
6. Mejorar la flecha AR con pasos e instrucciones por tramo.

## 14. Archivos Que Normalmente Se Editan

Para cambiar puntos de prueba:

```text
lib/main.dart
```

Busca:

```text
const demoPoints
```

Para agregar dependencias:

```text
pubspec.yaml
```

Despues corre:

```powershell
flutter pub get
```
