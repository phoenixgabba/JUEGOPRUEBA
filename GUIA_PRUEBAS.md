# Acampada València · guía de pruebas

GitHub Pages sirve `docs/`. Abre `index.html` para jugar una partida normal y `prueba.html` para abrir el selector. En pruebas, cada punto carga una partida temporal. Puedes repetirlo desde **Pausa → Puntos de prueba**.

Para probar una rama antes de incorporarla a GitHub Pages, descarga el ZIP de la rama, extráelo y ejecuta este comando en el directorio del proyecto. En Windows puedes sustituir `python3` por `py`.

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory docs
```

Abre [la partida normal](http://localhost:8000/) o [el selector](http://localhost:8000/prueba.html).

## Controles

| Punto | Qué hacer |
|---|---|
| Plaza | Camina con WASD o las flechas y pulsa E para interactuar. En móvil, usa el joystick y Acción. Abre el mapa con M o con el botón Mapa. |
| Noche y amanecer | Busca «Tu tienda» en el mapa. Entra con E o Acción junto a la marca azul. Tras el fundido, vuelve a pulsar para salir al amanecer. |

## Verificar y exportar

Usa Godot **4.7.2 estable** con GL Compatibility y las plantillas de exportación de esa misma versión. Los recursos necesarios están en el repositorio.

```sh
npm run verify
npm run build
npm run verify:release
```

`build` genera los perfiles **Web** y **Web Pruebas**, verifica que comparten el mismo motor, sustituye sus paquetes en `docs/` y actualiza ambos HTML. `verify:release` ejecuta las pruebas de Acampada y arranca cada PCK con Godot.

## Actividades del Día 2

Cada actividad empieza con un ensayo interactivo. Al final, revisa la puntuación, repite con otro escenario o vuelve a la plaza para registrar el resultado.

| Actividad | Mecánica y decisiones |
|---|---|
| Segunda asamblea | Escucha a los delegados y forma paquetes de propuestas con tres reservas independientes. Algunas se refuerzan y otras compiten por el mismo resultado. Puedes financiar una enmienda y volver a votar. El acuerdo determina la reserva inicial de una comisión posterior. |
| Accesibilidad | Mueve tiendas, cajas y mesas, pinta carriles y acerca bancos a los itinerarios largos. Los tres perfiles de movilidad comparten la cuadrícula con velocidades y requisitos diferentes. La puntuación mide llegadas, acceso asistido, espera y abandonos. |
| Redes | Sigue acontecimientos animados con el visor, ajusta el zoom, encuadra y espera el momento de acción. El carrete y la batería son limitados. Recorta las tomas, ajusta el pie y publica crónicas, avisos o dípticos para los tres encargos. El perfil conserva las publicaciones y sus imágenes recreables. |
| Seguridad | Lee las señales de los cuatro cuadrantes, observa antes de intervenir y desplaza a tres especialistas con fatiga y relevos. Las rondas previenen aglomeraciones. Puedes solicitar apoyo externo en casos confirmados. Las intervenciones injustificadas descuentan puntos. |
| Convivencia | Alterna entre las dos voces de cada conflicto. Escuchar, precisar y explorar concesiones abre información distinta según la confianza y la tensión. Combina dos condiciones, propón un pacto o un piloto, y usa pausas o seguimiento cuando se atasque la negociación. El desempeño influye en el bienestar de la plaza. |
| Punto sanitario | Identifica peticiones en recepción y dirige cada ficha a agua, mantas o enlace profesional. Dos voluntarios con especialidades diferentes cubren estaciones, cola y almacén. La puntuación considera atención, espera, reposición y abandonos. |

Los turnos en tiempo real de Accesibilidad, Redes, Seguridad y Punto sanitario rondan los tres minutos de simulación, con margen para recuperar los objetivos pendientes. La asamblea y Convivencia avanzan al deliberar, sin un temporizador que impida leer o discutir una propuesta.
