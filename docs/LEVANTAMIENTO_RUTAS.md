# Levantamiento de rutas peatonales UNIMET

La app ya puede calcular el camino mas corto sobre una red de pasos permitidos y
dar giros reales en cada tramo. Para evitar paredes, arboles y postes, esos
obstaculos se representan **no conectando** nodos a traves de ellos. El archivo
activo es `assets/campus_routes.json`; actualmente esta vacio porque no existen
mediciones verificadas de pasillos en el repositorio.

## Que registrar

1. Marcar un nodo en cada interseccion, giro, puerta, entrada, escalera y extremo
   de pasillo. En exterior, agregar nodos antes y despues de arboles, postes,
   jardineras o cambios de acera.
2. Registrar latitud, longitud, piso e identificador estable. Repetir lecturas y
   conservar precision; GPS de telefono en interiores no demuestra error de 2 m.
3. Conectar solo pares entre los que una persona realmente pueda caminar en linea
   recta. Una pared se evita omitiendo la conexion que la atravesaria.
4. Marcar `accessible: false` para conexiones cerradas o descartadas. Para rutas
   accesibles de silla de ruedas conviene separar posteriormente escaleras,
   rampas y ascensores con atributos propios.
5. Asociar cada nombre de salon normalizado con el nodo de su puerta en
   `destinations`. No asociar el centro GPS del edificio si la puerta esta en otro
   lugar.

Ejemplo minimo (las coordenadas son solo formato, no datos UNIMET):

```json
{
  "schemaVersion": 1,
  "nodes": [
    {"id": "A1-P1-GIRO-01", "latitude": 10.0, "longitude": -66.0, "floor": "1"},
    {"id": "A1-202-PUERTA", "latitude": 10.0, "longitude": -66.00001, "floor": "1"}
  ],
  "edges": [
    {"from": "A1-P1-GIRO-01", "to": "A1-202-PUERTA", "accessible": true}
  ],
  "destinations": {"A1-202": "A1-202-PUERTA"}
}
```

## Validacion obligatoria

- Dibujar cada arista sobre el mapa y revisar que no cruce infraestructura.
- Recorrer cada conexion en ambos sentidos y anotar cierres o escaleras.
- Verificar que el punto de inicio quede a menos de 35 m de la red; si no, la app
  muestra orientacion directa y avisa que esta fuera de la red cartografiada.
- Probar tres rutas con giros por piso y confirmar las instrucciones en sitio.
- Ejecutar `flutter analyze` y `flutter test` antes de compartir cambios.

ARKit dibuja el siguiente tramo, no descubre obstaculos. La red decide por donde
caminar; ARKit estabiliza la representacion visual de esa decision.

El archivo `Metro-Maps/assets/unimet.geojson` contiene poligonos de paredes y
pisos de A1 para niveles 1 y 2. Es una referencia util para revisar cruces, pero
no contiene puertas, ejes transitables ni conexiones de escaleras; por eso no se
convirtio automaticamente en una red navegable. `Metro-Maps` no fue modificado.
