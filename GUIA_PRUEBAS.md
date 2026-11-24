# Acampada València · guía de pruebas

GitHub Pages sirve `docs/`. Abre `index.html` para jugar una partida normal y `pruebas.html` para abrir el selector. En pruebas, cada punto carga una partida temporal. Puedes repetirlo desde **Pausa → Puntos de prueba**.

Para probar una rama antes de incorporarla a GitHub Pages, descarga el ZIP de la rama, extráelo y ejecuta este comando en el directorio del proyecto. En Windows puedes sustituir `python3` por `py`.

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory docs
```

Abre [la partida normal](http://localhost:8000/) o [el selector](http://localhost:8000/pruebas.html).

## Controles

| Punto | Qué hacer |
|---|---|
| Plaza | Camina con WASD o las flechas y pulsa E para interactuar. En móvil, usa el joystick y Acción. Abre el mapa con M o con el botón Mapa. |
| Noche y amanecer | Busca «Tu tienda» en el mapa. Entra con E o Acción junto a la marca azul. Tras el fundido, vuelve a pulsar para salir al amanecer. |
| Segunda asamblea | Da turnos de palabra y vota las propuestas que respondan a la prioridad de cada ronda. |
| Accesibilidad | Selecciona un objeto y toca una parcela libre. Prueba el recorrido con los visitantes. Cada ronda necesita un paso más ancho. |
| Redes | Centra la escena arrastrando el visor o con las flechas, ajusta el zoom y toma la foto. Asigna el pie y el público, publica y responde al comentario. Las fotos publicadas quedan en el perfil del teléfono. |
| Seguridad | Observa la plaza, selecciona el grupo que necesita apoyo, elige la respuesta y comunícala por radio. |
| Convivencia | Escucha las dos versiones, observa la tensión y confirma un acuerdo que responda a ambas necesidades. |
| Punto sanitario | Escucha a la persona en turno, atiende su petición y repón la reserva cuando se agote. Usa el aviso al equipo para las solicitudes de atención profesional. |

## Verificar y exportar

Usa Godot **4.7.2 estable** con GL Compatibility y las plantillas de exportación de esa misma versión. Los recursos necesarios están en el repositorio.

```sh
npm run verify
npm run build
npm run verify:release
```

`build` genera los perfiles **Web** y **Web Pruebas**, verifica que comparten el mismo motor, sustituye sus paquetes en `docs/` y actualiza ambos HTML. `verify:release` ejecuta las pruebas de Acampada y arranca cada PCK con Godot.
