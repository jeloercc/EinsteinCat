# EinsteinCat 🐈‍⬛

<p align="center"><img src="Resources/cat_page0.png" width="112" alt="EinsteinCat"></p>

Un gato que corre en la barra de menú de macOS: entre más se usa el CPU, más rápido corre.
También aparece un gatito animado en la tira de control de la Touch Bar.

Está basado en [Menubar RunCat](https://github.com/Kyome22/menubar_runcat) de Takuto Nakamura
(Apache-2.0) y usa sus mismas animaciones.

## Qué hace

- **Barra de menú:** el gato corre más rápido cuanto más se usa el CPU. Mide el CPU cada 5 segundos.
- **Menú del gato:**
  - *Show CPU Usage* muestra el % de CPU al lado del gato.
  - *About* abre el panel "Acerca de".
  - *Quit* cierra la app.
- **Touch Bar:** un gatito animado en la tira de control (la parte derecha de la Touch Bar).
  Usa **APIs privadas** de macOS, como se explica abajo.
- No aparece en el Dock ni en Cmd-Tab (`LSUIElement`).

## Requisitos

- macOS 15 (Sequoia) en una Mac Intel (`x86_64`).
- Command Line Tools de Apple, que traen `swiftc`. **No hace falta Xcode.**
- Una Touch Bar, solo para la parte de la Touch Bar. Sin ella, la barra de menú funciona igual.

## Compilar y ejecutar

```sh
./build.sh                    # crea build/EinsteinCat.app
open build/EinsteinCat.app    # la abre como app normal
```

Para ver los mensajes de la app (útil para depurar), ábrela desde la terminal:

```sh
build/EinsteinCat.app/Contents/MacOS/EinsteinCat
```

### Qué hace `build.sh`

Hace a mano lo que Xcode haría por dentro:

1. Borra `build/EinsteinCat.app` si ya existe y crea la estructura `Contents/MacOS` y `Contents/Resources`.
2. Compila con `swiftc -swift-version 5`. El código original es Swift 5.
   - `-import-objc-header Sources/TouchBarPrivate.h` le da a Swift las declaraciones de las APIs privadas.
3. Copia `Info.plist` y los PNG del gato.
4. Revisa el plist con `plutil -lint`.
5. Firma la app ad-hoc con `codesign --sign -`, sin certificado.

## Estructura

```
EinsteinCat/
├── Sources/
│   ├── main.swift            arranque de la app (original)
│   ├── AppDelegate.swift     barra de menú y animación (original, modificado)
│   ├── CPU.swift             medición del CPU con host_statistics (original)
│   ├── TouchBar.swift        gatito en la tira de control (nuevo)
│   └── TouchBarPrivate.h     declaraciones de las APIs privadas de la Touch Bar (nuevo)
├── Resources/                cat_page0.png … cat_page4.png (5 cuadros de la animación)
├── Info.plist
├── build.sh
├── CLAUDE.md                 contexto y plan del proyecto
└── LICENSE                   Apache-2.0
```

## La Touch Bar y las APIs privadas

macOS no tiene una forma pública de que una app ponga algo en la tira de control. EinsteinCat usa
lo mismo que [MTMR](https://github.com/Toxblh/MTMR):

| API | Tipo | Cómo se usa |
|---|---|---|
| `+[NSTouchBarItem addSystemTrayItem:]` / `removeSystemTrayItem:` | Métodos privados de AppKit | Declarados en `TouchBarPrivate.h` |
| `DFRElementSetControlStripPresenceForIdentifier` | Función C privada de `DFRFoundation` | Se carga con `dlopen`/`dlsym` al arrancar |

`DFRFoundation` no se puede enlazar al compilar, porque desde macOS 11 su binario no está en
el disco: vive en la caché compartida de dyld. Por eso se carga en tiempo de ejecución.
Si no se encuentra, la app lo avisa en el registro y la barra de menú sigue funcionando.

Como son APIs privadas, **Apple puede cambiarlas o quitarlas** en cualquier versión de macOS.

### Avisos

- **MTMR y EinsteinCat no pueden estar abiertos a la vez.** Mientras MTMR muestra su barra,
  tapa la tira de control.
- La tira de control siempre está a la derecha. La posición del gatito la decide macOS.
- La animación de la Touch Bar se limita a 30 cuadros por segundo para no gastar CPU de más.

## Estado

| Fase | Qué | Estado |
|---|---|---|
| 0 | Herramientas y recursos | ✅ |
| 1 | `Info.plist` + `build.sh`: el gato corre en la barra de menú | ✅ |
| 2 | Gatito animado en la tira de control de la Touch Bar | En curso |
| 3 | Al tocarlo, el gato cruza la Touch Bar | Pendiente |
| 4 | Instalar en `/Applications` y abrir al iniciar sesión | Pendiente |

## Problemas conocidos

- **No se detiene al dormir la Mac.** Viene del original: `setNotifications()` existe pero nunca se llama.
- El gatito de la Touch Bar **no siempre apareció de inmediato** en las pruebas, y todavía no se sabe por qué.
- La app usó entre 5 % y 8 % de un núcleo en una medición rápida. Falta ver cuánto de eso es la Touch Bar.
- Los textos del menú siguen en inglés ("Menubar RunCat") y la app no tiene ícono propio.
- Al tocar el gatito de la Touch Bar solo se escribe un mensaje en el registro. La acción real es la Fase 3.

## Créditos y licencia

- Código e imágenes originales: **Takuto Nakamura**, [Menubar RunCat](https://github.com/Kyome22/menubar_runcat),
  licencia [Apache-2.0](LICENSE). Los archivos originales conservan su encabezado de copyright, y los
  que se cambiaron lo indican en el encabezado.
- La forma de usar las APIs privadas de la Touch Bar está basada en [MTMR](https://github.com/Toxblh/MTMR)
  de Anton Palgunov.
- EinsteinCat se distribuye bajo la misma licencia Apache-2.0.
