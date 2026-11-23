# Acampada València · guía rápida de pruebas

## Qué es

Hay dos carpetas. **PUBLICAR** actualiza el juego normal. **SOLO_PRUEBAS** es una copia local que abre un menú para saltar a nueve momentos del juego. En esa copia puedes jugar y reiniciar libremente. Al cerrar o recargar, el avance de prueba se pierde. Tu partida normal conserva su guardado.

## Probar en Windows

1. Extrae el ZIP. Abre **SOLO_PRUEBAS** con el Explorador de Windows.
2. En la barra de direcciones de esa carpeta, escribe **powershell** y pulsa **Enter**.
3. Pega este comando y pulsa **Enter**. Requiere Python instalado.

   ```powershell
   py -m http.server 8000 --bind 127.0.0.1
   ```

4. Abre [http://localhost:8000](http://localhost:8000) en el navegador. Elige la parte que quieras probar. Para simular un móvil en Chrome, Brave o Edge, pulsa **F12** y después **Ctrl + Shift + M**.
5. Para cambiar de prueba, cierra el minijuego si está abierto y pulsa **Pausa → Elegir punto de prueba**. También puedes recargar la página. Para apagar el servidor, pulsa **Ctrl + C** en PowerShell.

Este servidor solo escucha en tu PC. Para una prueba táctil en el iPhone, usa una vista previa privada en la que te asegures de que el acceso está restringido.

## Controles

| Paso | Ordenador | Móvil |
|---|---|---|
| Caminar y hablar | WASD o flechas, **E** para interactuar y **M** para abrir el mapa. | Joystick, **Acción** y **Mapa**. |
| Montar tienda | Arrastra la lona o usa las flechas y **E**. Encaja en verde, pulsa **E** rápido para levantar y usa flechas y **E** para las piquetas. | Arrastra la lona al círculo. Toca **Encajar** en verde, pulsa **Pulsa rápido** varias veces y toca las cuatro piquetas. |
| Almacén | **←/→** mueven, **↑** gira, **↓** baja y **Espacio** suelta la pieza. | Usa los botones debajo del tablero. |
| Cocina | Haz clic en dos piezas para intercambiarlas. En la recogida, usa **1–5**. | Toca dos piezas para intercambiarlas y después toca los carriles para recoger comida. |
| Segunda asamblea | Pulsa **E** en el círculo central. | Pulsa **Acción** en el círculo central. |
| Accesibilidad | Flechas o WASD para guiar al NPC hasta la **T**. | Usa las cuatro flechas del laberinto. |
| Redes | Pulsa **E** junto a cada punto del mapa y haz clic en **Tomar foto** o **Guardar vídeo**. Vuelve al punto de Redes y pulsa **Publicar y abrir Redes**. | Pulsa **Acción**, captura las tres piezas y vuelve a Redes a publicarlas. El **Teléfono** se abre junto a **Mapa**. |
| Seguridad | Haz clic en **Agitador** para enviar el aviso. Deja pasar a las personas mayores y menores. | Toca **Agitador** hasta completar los 15 avisos. |
| Convivencia | Haz clic en dos cartas para encontrar parejas. | Toca dos cartas para encontrar parejas. |
| Punto sanitario | Mantén pulsado el ratón sobre la pieza, arrastra a la bandeja y suelta dentro. | Mantén el dedo sobre la pieza, arrastra a la bandeja y suelta dentro. |

## Publicar, retirar o dejar de usar las pruebas

- **Publicar:** copia únicamente el contenido de **PUBLICAR** dentro del proyecto y sube esos cambios a GitHub Pages. La carpeta **SOLO_PRUEBAS** se queda fuera del repositorio.
- **Desactivar el menú de jugadores:** la compilación **Web** ya lo lleva desactivado. Solo la compilación separada **Web Pruebas** lo activa. Los parámetros de la URL no pueden abrir el menú de pruebas en la versión pública.
- **Quitar la copia de pruebas:** cierra PowerShell y borra **SOLO_PRUEBAS**. El juego publicado y sus partidas siguen funcionando. Si tampoco quieres volver a generar una copia de pruebas desde Godot, ve a **Proyecto → Exportar**, selecciona **Web Pruebas** y elimina ese perfil. Conserva el perfil **Web**.
