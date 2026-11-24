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

Después de la segunda asamblea se abre **Redes → Seguridad → Convivencia → Punto sanitario → Accesibilidad**. Tras cada actividad, vuelve a la entrada para recibir a cinco personas. Indica una parcela a quienes traigan tienda y monta las donaciones. Las nuevas comisiones se abren al llegar a 30, 35, 40 y 45 tiendas. Cierra el día en Organización al llegar a 50.

| Actividad | Cómo jugar |
|---|---|
| Segunda asamblea | Escucha a los delegados y vota propuestas sobre las necesidades de las cinco comisiones. |
| Redes | Activa el encargo en la plaza. Abre Móvil, entra en Instagram y guarda el nombre, la descripción y la imagen del perfil. Sigue las marcas del mapa, pulsa Acción junto a cada escena y fotografíala con Cámara. Publica las tres desde Galería. |
| Seguridad | Marca únicamente los personajes que llevan el rótulo «Aviso neonazi». Toca el personaje o usa las teclas 1 a 9. La ronda acaba al acertar 15 avisos. |
| Convivencia | Encuentra las parejas de objetos de la acampada. Son tres tableros de 4, 6 y 10 parejas, después del ensayo. |
| Punto sanitario | Mantén el dedo o el cursor pulsado sobre una pieza, sigue la cavidad hasta la bandeja y suelta. Las pinzas y la pieza detectan los bordes incluso con movimientos rápidos. |
| Accesibilidad | Usa el joystick, WASD o las flechas para guiar a la persona hasta la tienda dorada. Si se pierde de vista o un paso estrecho la deja atrás, vuelve a buscarla. |

Cada juego arcade incluye un ensayo y un resultado con opción de repetir. Para volver a iniciar Redes desde el principio, vuelve al selector de pruebas.

## Teléfono permanente

Cuando empiece el encargo de Redes, pulsa **P** en ordenador o **Móvil** junto al mapa en dispositivos táctiles. Usa Atrás, Inicio y Cerrar para navegar. El punto **Teléfono y aplicaciones** se suma a los 13 puntos anteriores y abre un teléfono de prueba con contactos y ejemplos narrativos. La partida normal comienza con la agenda de contactos, los chats y la galería vacíos.

- **Cámara y Galería.** Arrastra el visor, ajusta el zoom y dispara. Desliza el carrete lateralmente. Abre una captura para ampliarla, compartirla o eliminarla. Las fotos compartidas se conservan para que sus enlaces sigan funcionando.
- **Contactos, Mensajes y Teléfono.** Habla con los personajes en la plaza para recibir sus números ficticios. Consulta hilos individuales y grupales, adjuntos, llamadas entrantes y el historial.
- **Instagram.** Consulta el feed, el perfil, las historias, los comentarios y los mensajes directos. Empieza el encargo desde el punto de Redes de la plaza. Sus publicaciones quedan en el perfil y sus imágenes en la galería.
- **Correo, Notas y Archivos.** Redacta correo con adjuntos y consulta las bandejas de entrada, enviados y borradores. Puedes escribir notas y compartir archivos recibidos.
- **Mapa, Agenda, Reloj y Ajustes.** El mapa del móvil muestra las ubicaciones descubiertas y permite abrir el mapa habitual. El reloj interno gobierna alarmas y convocatorias. Los temporizadores miden segundos de exploración o de uso del móvil.
- **Avisos.** Al pulsarlos, se abren sus aplicaciones y elementos. Durante una actividad, los avisos esperan a que vuelvas a la exploración.

Las aplicaciones son simulaciones locales. El teléfono se guarda con la partida y el selector mantiene su propio estado de prueba.
