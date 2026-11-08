# EinsteinCat — contexto para Claude

App propia para macOS: un gato en la barra de menú que corre más rápido según el uso de CPU,
y que también puede correr por la Touch Bar. Está basada en `Kyome22/menubar_runcat`
(licencia Apache-2.0), con las mismas animaciones.

## Cómo trabajar conmigo (leer primero)

- **Respóndeme en español.** Explica el porqué de cada paso. El objetivo también es aprender Swift/AppKit.
- **No supongas nada sobre mi sistema.** Si necesitas un dato, dame primero un comando que **solo lea**
  y espera el resultado. Los datos verificados están abajo; lo que no esté ahí, no lo des por hecho.
- **Antes de escribir o cambiar código, muéstrame el plan** (qué archivos, qué cambia, cómo se prueba)
  y espera mi "sí". No hagas nada que no te haya pedido.
- **Avanza por fases.** Una fase a la vez, y verifica que se cumpla su criterio de "terminado" antes de pasar a la siguiente.
- **Sé honesto sobre lo que no sabes.** Separa lo verificado de lo que es una hipótesis. Si algo depende de
  una API privada o no documentada, dilo.
- **Antes de cualquier comando que borre, sobrescriba o use `sudo`**, dime exactamente qué afecta.
- Si te equivocas, dilo directamente y corrígelo.

## Reglas de seguridad de esta Mac (no negociables)

- **Nunca toques la partición EFI interna (`disk0s1`)** ni el disco completo `disk0`. Ahí está el firmware
  del chip T1 (`EFI/APPLE/EMBEDDEDOS`). Si se borra, la Touch Bar y Touch ID dejan de funcionar.
  (Hay respaldo en el disco externo "julian" → `T1-backup/`.)
- **No sugieras actualizar a macOS Tahoe (26)** ni cambiar nada de OpenCore Legacy Patcher.
- **No uses Homebrew:** su instalador ya no acepta Macs Intel. Para herramientas de terminal se usa **MacPorts**.
- **No instales Xcode.** Todo se compila con `swiftc` de las Command Line Tools.

## Entorno verificado

| Cosa | Valor |
|---|---|
| Mac | MacBook Pro 15" 2017 (MacBookPro14,3), i7 2.8 GHz 4 núcleos, 16 GB, chip T1, Touch Bar |
| GPU | Intel HD 630 + Radeon Pro 555 |
| macOS | Sequoia 15.8.2 (24H232), instalado con OpenCore Legacy Patcher 2.5.1 (Mac sin soporte oficial) |
| Arquitectura | `x86_64` (Intel) |
| Swift | 6.1.2, target `x86_64-apple-macosx15.0` (Command Line Tools en `/Library/Developer/CommandLineTools`) |
| sourcekit-lsp | `/Library/Developer/CommandLineTools/usr/bin/sourcekit-lsp` |
| git | 2.39.5 |
| Gestor de paquetes | MacPorts 2.12.7 (`/opt/local`) |
| Editor | VS Code con la extensión Swift (swiftlang) |
| Touch Bar | `TouchBarServer` corriendo; existe `/System/Library/PrivateFrameworks/DFRFoundation.framework` |
| Prueba de Touch Bar | **MTMR v0.27 funciona** en esta Mac → las APIs privadas de Touch Bar "system modal" sí funcionan aquí |
| Otros | Unshaky está corriendo (filtra rebotes del teclado). No tiene relación con este proyecto. |

**MTMR y EinsteinCat usan la misma parte de la Touch Bar.** Al probar la Touch Bar, MTMR tiene que estar cerrado.

## Estado del repo

```
EinsteinCat/
├── Sources/      main.swift, AppDelegate.swift, CPU.swift   (copiados sin cambios del original)
├── Resources/    cat_page0.png … cat_page4.png               (de Assets.xcassets/cat_pageN.imageset/catN.png)
├── Info.plist    bundle ID com.jeloercc.einsteincat, LSUIElement=true, mínimo macOS 15.0
├── build.sh      swiftc -swift-version 5 → build/EinsteinCat.app, copia PNG, firma ad-hoc
├── LICENSE       Apache-2.0 del autor original
└── .gitignore    build/, .DS_Store
```

El repo original está clonado **al lado** (`../menubar_runcat`), solo como referencia. No lo modifiques.

### Datos del código original (ya revisados)

- `main.swift` usa `NSApplicationMain` con `AppDelegate` asignado a mano.
- `AppDelegate.swift`: `NSStatusItem` con 5 cuadros. Los carga con `NSImage(named: "cat_page\(n)")` y les pone
  tamaño 28×18 pt. Mide el CPU cada 5 s. El intervalo entre cuadros es `0.2 / max(1, min(20, cpu/5))`.
  **Bug del original:** existe `setNotifications()` (detener al dormir / arrancar al despertar), pero
  **nunca se llama**, así que el gato no se detiene al dormir la Mac. Pendiente de arreglar en una fase posterior.
- `CPU.swift`: `host_statistics(HOST_CPU_LOAD_INFO)`, con la diferencia de ticks entre lecturas.
- Los PNG miden 56×36 px RGBA (@2x de 28×18). **El gato mira a la derecha**, así que corre de izquierda a derecha.
- El `Info.plist` original está casi vacío porque Xcode le agrega lo demás. Hay que escribir uno completo.
- Fue escrito para Swift 5.0 y deployment target 10.13. Compilar con `-swift-version 5`.
- Sin `.xcassets`, `NSImage(named:)` **sí** encuentra los PNG sueltos en `Contents/Resources` (verificado en la Fase 1).
- Compila con Swift 6.1.2 en modo `-swift-version 5` sin advertencias (verificado).

## Plan por fases

| Fase | Qué se hace | Terminado cuando… |
|---|---|---|
| 0 ✅ | Herramientas y recursos | El repo tiene `Sources/`, `Resources/`, `LICENSE` |
| 1 ✅ | `Info.plist` (CFBundleExecutable, CFBundleIdentifier, `LSUIElement`=true, NSPrincipalClass) + `build.sh` (`swiftc -swift-version 5` → `build/EinsteinCat.app`, copiar PNG, firma ad-hoc `codesign -s -`) | El gato original corre en la barra de menú |
| 2 | Gatito en la tira de control de la Touch Bar (API privada) | Aparece el gatito a la derecha de la Touch Bar |
| 3 | Al tocarlo, el gato cruza la Touch Bar según el CPU, con el % de CPU a un lado y botón de cerrar para volver a la barra normal | El gato corre por la Touch Bar y se puede volver a la barra normal |
| 4 | Instalar en `/Applications` y agregar a Ítems de inicio | Arranca solo al iniciar sesión |

### Decisiones pendientes (pregúntame)

- Touch Bar: ¿el gato aparece **solo al tocar el gatito** (se conserva el esc) o **ocupa la barra siempre**?
- Si hay que cambiarle el nombre a la app, o los textos del menú (al español). Hoy el menú dice "Menubar RunCat".
- Ícono de la app: no tiene, así que el panel "About" muestra el ícono genérico.
- Decidido: bundle identifier `com.jeloercc.einsteincat`.

### Notas de la API privada de Touch Bar (Fases 2 y 3, sin verificar)

Lo que usan MTMR y Pock, según lo que sé. **Confírmalo contra el código fuente de MTMR antes de usarlo**:
- `NSTouchBarItem` → `addSystemTrayItem:` / `removeSystemTrayItem:`
- `NSTouchBar` → `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`, `dismissSystemModalTouchBar:`, `minimizeSystemModalTouchBar:`
- C en `DFRFoundation`: `DFRElementSetControlStripPresenceForIdentifier(NSString*, BOOL)`, `DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL)`
- Desde Swift: los selectores con `class_getClassMethod` + `unsafeBitCast` a `@convention(c)`, y las funciones C con `dlopen`/`dlsym`.
- La animación de la Touch Bar solo debe correr mientras se ve. Es un monitor de CPU y no debe gastar CPU de más.

## Licencia

El código y las imágenes vienen de Takuto Nakamura (Apache-2.0). Mantén los encabezados de copyright de los
archivos originales y marca en los archivos modificados que fueron cambiados.
