# Tutorial Android - UNIMET AR

Este documento explica como instalar, ejecutar y usar el prototipo `unimet_ar` sin depender del chat.

## 1. Que Es Este Proyecto

`unimet_ar` es un prototipo Flutter para probar la parte visual de realidad aumentada del mapa UNIMET. Permite marcar ubicaciones reales como puntos de interes y volver a ellas con la camara, el GPS y la brujula del telefono.

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
- agrega permisos de camara y ubicacion en Android,
- agrega permisos de camara y ubicacion en iOS,
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

Durante el primer uso aparecera una guia de dos pasos. Despues:

1. Toca el boton `+` de `Marca tu ubicacion actual`.
2. Escribe un nombre y toca `Marcar aqui`.
3. Acepta camara, ubicacion y ubicacion precisa cuando Android los pida.
4. Alejate varios metros del punto. Para GPS, una prueba exterior suele ser mas estable que una dentro de una habitacion.
5. Toca el punto para dejarlo seleccionado como unico destino.
6. Toca `Guiarme a...`.
7. Gira el telefono: la brujula y la flecha se orientaran automaticamente.

Los puntos quedan guardados en ese telefono y pueden borrarse con el icono de papelera. La app impide registrar otro punto a menos de 2 metros de uno existente.

## 10. Que Validamos Con Esta Prueba

Esta version sirve para validar:

- registro y seleccion de un destino,
- posicion actual mediante GPS,
- calculo de distancia y direccion en vivo,
- overlay sobre camara,
- permisos de camara y ubicacion,
- brujula automatica,
- claridad de instrucciones visuales.

Todavia no valida:

- posicion interior con precision garantizada de 2 metros,
- anclaje 3D real a superficies mediante ARCore/ARKit,
- rutas reales de UNIMET,
- conexion con backend de salones.

## 11. Prueba En Casa Recomendada

Marca un punto en la entrada o patio, alejate al menos 10 metros y abre la guia hacia ese punto. Comprueba que la distancia cambie al caminar y que la flecha rote al girar el telefono. Si la lectura oscila, separa el telefono de metal, imanes, computadoras o bocinas y muevelo dibujando un ocho para recalibrar la brujula.

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

### La Brujula No Responde O Apunta Mal

- confirma que la ubicacion precisa este activa,
- alejate de objetos metalicos o magneticos,
- mueve el telefono lentamente en forma de ocho,
- prueba fuera del edificio para comparar la lectura.

### Quiero Probar Sin Telefono

Puedes generar soporte web:

```powershell
flutter create --platforms web .
flutter run -d chrome
```

Esto sirve para pantallas y logica. La camara puede comportarse distinto en navegador.

## 13. Proximos Pasos Del Proyecto

Despues de probar en Android fisico, las siguientes mejoras naturales son:

1. Conectar con el backend de salones en Vercel/Neon.
2. Cargar salones reales como destinos.
3. Calcular rutas interiores por pasillos, escaleras y pisos.
4. Sustituir el overlay por anclajes 3D de ARCore/ARKit.
5. Combinar GPS con puntos de referencia interiores para mejorar precision.

## 14. Archivos Que Normalmente Se Editan

La logica de puntos, ubicacion, brujula y guia esta en `lib/main.dart`.

Para agregar dependencias:

```text
pubspec.yaml
```

Despues corre:

```powershell
flutter pub get
```
