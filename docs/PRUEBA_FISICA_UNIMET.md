# Prueba fisica de navegacion UNIMET AR

Esta prueba valida por separado la seleccion del salon, la direccion de la
brujula y el anclaje de las flechas al piso. Hazla con el iPhone en vertical.

## 1. Preparar la app

En la Mac:

```bash
git pull origin main
flutter pub get
flutter run --release
```

En el formulario de salones, toca `Exportar CSV`. Guarda el archivo en iCloud
Drive o en la app Archivos del iPhone.

En UNIMET AR:

1. Toca el boton de importar junto a `Cargar salones UNIMET`.
2. Selecciona el CSV exportado por el formulario.
3. Confirma que aparezca la cantidad correcta de salones.
4. Busca un salon por nombre, piso o referencia.
5. Seleccionalo y toca `Guiarme a...`.

## 2. Comprobar la direccion

Haz esta parte en un pasillo abierto y usa un destino que este al menos a 10 m.
La direccion GPS no es confiable cuando la distancia es parecida al margen de
error mostrado por la app.

1. Mira directamente hacia el destino: debe indicar `Sigue derecho`.
2. Gira 90 grados a la izquierda: debe indicar que gires a la derecha.
3. Gira 90 grados a la derecha del destino: debe indicar que gires a la izquierda.
4. Gira de espaldas: debe indicar `Date la vuelta`.
5. Repite lejos de puertas metalicas, ascensores y equipos electricos.

Anota para cada intento:

```text
Salon:
Distancia indicada:
Rumbo ARKit:
Rumbo del destino:
Precision de brujula:
Precision GPS:
Instruccion mostrada:
Instruccion correcta esperada:
```

## 3. Comprobar las flechas AR

1. Al abrir la guia, mueve el iPhone lentamente y apunta un poco hacia el piso.
2. Espera hasta leer `Ruta anclada al piso` y `AR: piso detectado`.
3. Confirma que aparecen varios indicadores azules siguiendo una sola direccion.
4. Mueve el telefono de lado sin caminar: las flechas deben quedarse en el mismo lugar fisico.
5. Camina hacia ellas: deben crecer al acercarte y quedar detras al pasarlas.
6. Despues de avanzar cerca de 1 m, la secuencia debe colocarse nuevamente por delante.

Si ARKit muestra `pocos detalles`, apunta a un piso con textura, juntas o cambios
de color. Evita mover el telefono bruscamente.

## 4. Probar un salon real

1. Elige un salon registrado con la mejor precision GPS disponible.
2. Inicia desde un punto conocido del mismo piso y suficientemente alejado.
3. Comprueba primero el sentido general del pasillo.
4. No uses el GPS para decidir una puerta cuando el margen de error sea mayor que
   la distancia restante. Para esa ultima parte se usaran los QR de anclaje.
5. Guarda una captura del panel inferior y anota cualquier giro incorrecto.

## 5. Prueba QR independiente

El boton `Probar QR + ARKit` sigue disponible. Usa
`output/pdf/CASA_QR_001_20CM.pdf` para comprobar escala y estabilidad sin GPS.
Esta prueba debe mostrar cuatro indicadores hacia la derecha del QR.
