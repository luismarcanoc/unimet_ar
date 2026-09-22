# Prueba GPS y flechas en UNIMET

Actualizado: 22 de septiembre de 2026.

Esta prueba usa GPS y no necesita QR. La guia apunta en linea recta al destino:
no calcula una ruta por pasillos ni determina el piso actual. El objetivo es
medir estabilidad, sentido de giro y comportamiento cuando falta precision.

## 1. Instalar la misma version en la Mac y el iPhone

En una terminal, dentro de la carpeta clonada `unimet_ar`:

```bash
git status --short
git pull --ff-only
git log -1 --oneline
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --release -d ID_DEL_IPHONE
```

Reemplaza `ID_DEL_IPHONE` por el identificador de `flutter devices`.
Si Git avisa de cambios locales, conservalos antes de continuar; no los descartes.
Confirma que estas en `main`. Hay cambios nativos iOS: es necesario recompilar.
Anota el commit instalado, modelo del telefono y version de iOS.

Esta guia y la plantilla de resultados estan versionadas: se reciben con pull.
La instalacion desde cero sigue en [INSTALACION_MAC_COMPLETA.md](INSTALACION_MAC_COMPLETA.md).
Una vez iniciada la version release se puede desconectar el cable.
Activa ubicacion precisa y camara en Ajustes > UNIMET AR. Usa el iPhone en vertical
y evita ahorro de energia durante la comparacion.

## 2. Preparar destinos

1. Exporta el CSV del formulario y guardalo en Archivos del iPhone.
2. Importalo desde `Cargar salones UNIMET`.
3. Comprueba nombre, piso, referencia y ubicacion fisica del destino. No uses un
   punto de casa estando en UNIMET. Un destino mal registrado tambien desvia la flecha.
4. Elige un punto visible en exterior y un salon del mismo piso en un pasillo recto.
5. Empieza a unos 30-50 m, por un trayecto peatonal permitido. Repite primero en
   exterior y luego en interior, conservando el mismo punto de salida por intento.

Una persona camina y otra toma notas. No caminen por escaleras mirando la pantalla.

## 3. Interpretar los estados

| Estado | Significado |
| --- | --- |
| Estabilizando ubicacion | Esperar tres lecturas distintas durante al menos dos segundos. |
| GPS activo e instruccion | Hay datos suficientes para una direccion aproximada. |
| Ubicacion imprecisa | Lectura descartada o margen del telefono mayor a 25 m. |
| Esperando un GPS actualizado | Mas de 8 s sin una lectura aceptada. |
| Sin precision para indicar un giro | Destino demasiado cercano respecto al error combinado. |
| Zona del destino; confirma el salon | Confirmar puerta y piso visualmente; no significa llegada exacta. |
| Levanta la camara hacia el pasillo | La camara apunta casi verticalmente y su rumbo es ambiguo. |
| Esperando orientacion fiable | Falta rumbo reciente, la brujula es imprecisa o ARKit esta recuperandose. |
| La sesion AR se detuvo | Copiar diagnostico antes de tocar Reintentar AR. |

El icono azul ahora apunta al destino respecto a la camara, igual que el texto;
no representa una brujula apuntando al norte. En PAUSA no hay flechas de direccion.

El filtro descarta datos invalidos, antiguos, con error mayor de 50 m y saltos
incompatibles con caminar. Suaviza movimientos pequenos sin reducir artificialmente
el margen de error. Una lectura aceptada aun puede ser insuficiente para guiar.
Se habilita la direccion a partir del doble de la suma de los errores del telefono
y del destino. Ejemplo: +/-5 m en ambos exige al menos 20 m de separacion.
Sin precision del destino se usa un margen provisional de 15 m y se informa que
es desconocida. Estos umbrales son conservadores; se ajustaran con las pruebas.

## 4. Ejecutar las pruebas

### Quieto y giros

1. Abre la guia y espera GPS y orientacion fiables.
2. Mueve lentamente la camara para detectar el piso y luego mira al pasillo,
   ligeramente inclinado hacia abajo.
3. Permanece quieto 20 s y observa saltos de distancia o direccion.
4. Mirando al destino debe indicar `Sigue derecho`.
5. Gira 90 grados a la izquierda: debe indicar giro a la derecha.
6. Gira 90 grados a la derecha del destino: debe indicar giro a la izquierda.
7. Mira en sentido contrario: debe indicar `Date la vuelta`.
8. Repite tres veces, incluyendo un giro que cruce el norte si el lugar lo permite.

Compara con la direccion visible del destino, no solamente con otra brujula.

### Caminar y acercarse

1. Camina lentamente 10-20 m. La distancia debe disminuir de manera general.
2. Las flechas deben conservar su direccion al mover la camara y actualizarse
   por delante al avanzar. Anota cambios bruscos o giros incorrectos.
3. Cerca de la puerta la guia debe pausarse por incertidumbre. Confirma el salon
   y el piso visualmente. Anota distancia indicada y distancia real aproximada.
4. Esta prueba GPS no debe mostrar `Llegaste` ni un aro verde de llegada.

### Recuperacion

1. Apunta directamente al piso: no debe inventar giros. Levanta la camara hacia
   el pasillo y comprueba que se recupera al estabilizarse.
2. Entra en una zona cubierta y observa si aumenta el error o aparece PAUSA.
3. Bloquea el telefono unos segundos y vuelve a la app: debe esperar datos
   recientes antes de reanudar la guia.
4. Si aparece error 102 u otro error AR, copia el diagnostico y prueba
   `Reintentar AR`. Anota si recupera camara y flechas.

## 5. Compartir resultados

Toca el icono de copiar (dos hojas) en la barra superior. Copia hasta 180 muestras
de diagnostico, aproximadamente tres minutos, para pegarlas en un archivo o chat
del equipo. Hazlo justo despues del fallo y antes de salir de la guia.

El registro vive en memoria mientras la guia esta abierta; no se envia a ningun
servidor. Incluye coordenadas recibidas y filtradas, lecturas descartadas, precision
del destino, rumbos, estado AR y estado de la guia. Compartelo con el equipo de pruebas.
No permite saber por si mismo donde estaba realmente la puerta.

Completa [PLANTILLA_RESULTADOS_GPS.md](PLANTILLA_RESULTADOS_GPS.md) por intento y
adjunta video o captura con la direccion que esperabas ver.

## 6. Criterios de validacion fisica

- Tres repeticiones correctas de los cuatro giros con senal suficiente.
- Sin cambios bruscos de sentido estando quieto.
- Flechas, icono e instruccion coinciden cuando estan activos.
- Datos antiguos, saltos o mala precision pausan la guia.
- Apuntar verticalmente al piso no produce un giro falso.
- Recuperacion despues de bloqueo o perdida de seguimiento.
- Error observado al acercarse a la puerta registrado, sin prometer +/-2 m.

Aprobar los tests de Flutter no demuestra precision GPS ni estabilidad AR en UNIMET.

## Referencia tecnica

ARKit usa `gravityAndHeading`: -Z representa norte verdadero y +X este segun la
[documentacion de Apple](https://developer.apple.com/documentation/arkit/arconfiguration/worldalignment-swift.enum/gravityandheading).
En iOS no se mezcla ese rumbo con el rumbo de camara magnetico de `flutter_compass`.
La prueba QR anterior permanece separada de este protocolo GPS.
