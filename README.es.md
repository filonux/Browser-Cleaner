<img src="assets/icon.png" width="140" height="140">

# Browser-Cleaner

[English](README.md)

Limpiador interactivo de navegadores para Linux: detecta lo que tienes instalado, te deja elegir qué borrar, y nunca toca lo que te identifica como usuario — perfiles, marcadores, contraseñas o extensiones.

![Bash 4+](https://img.shields.io/badge/bash-%3E%3D4.0-4EAA25?logo=gnubash&logoColor=white) ![Linux Mint 22.3 Cinnamon](https://img.shields.io/badge/Linux%20Mint-22.3%20Cinnamon-87CF3E?logo=linuxmint&logoColor=white) ![Licencia GPLv3](https://img.shields.io/badge/licencia-GPLv3-blue)

---

## El problema que resuelve

Con el uso, cualquier navegador acumula caché, historial, cookies, sesiones y archivos temporales que solo ocupan espacio y no aportan nada. Limpiarlo a mano implica entrar en los ajustes de cada navegador por separado — y si usas varios, repetir el proceso en cada uno. Las herramientas genéricas de "limpieza del sistema", por su parte, no siempre dejan claro qué tocan exactamente, con el riesgo real de llevarse por delante marcadores o sesiones guardadas.

Browser-Cleaner detecta qué navegadores tienes instalados, te deja elegir cuáles y qué limpiar, y te dice cuánto espacio vas a recuperar antes de borrar nada.

<img width="652" height="439" alt="Browser-Clearner-menu-es" src="https://github.com/user-attachments/assets/955dfa65-a14c-4b9f-97fb-626170af9d36" />

## Qué hace exactamente

- Detecta automáticamente los perfiles de navegador compatibles en diseños nativos, Flatpak o Snap y cuántos perfiles tiene cada uno.
- Seis tipos de limpieza a elegir: rápida, completa, solo caché, solo cookies, solo historial o profunda (ver [Tipos de limpieza](#tipos-de-limpieza)).
- Vista previa y confirmación explícita antes de cualquier borrado irreversible.
- Copia de seguridad automática de los archivos críticos antes de tocarlos.
- Comprueba que el navegador esté cerrado antes de limpiar sus perfiles, para no corromper nada a medio escribir.
- Si faltan `sqlite3` o `jq` — se usan para limpiar historial, formularios y permisos con precisión — se ofrece instalarlos con `apt` automáticamente; si rechazas o falla, simplemente se omite esa parte sin abortar el resto.
- No está pensado para ejecutarse como root: limpia el `$HOME` de tu propio usuario, y avisa si lo lanzas con `sudo` por error.
- Registra cada sesión (fecha, qué se limpió, cuánto se liberó) en `~/.cache/browser-cleaner/browser-cleaner.log`.
- Interfaz de terminal clara, con spinner de progreso y tablas-resumen del espacio liberado por categoría y navegador.

## Ventajas

La mayoría de limpiadores tratan el navegador como una carpeta más: borran por antigüedad o por tamaño, sin distinguir qué es tuyo y qué es basura. Browser-Cleaner parte de una regla fija, no de heurísticas: se conserva todo lo que te identifica como usuario, se elimina solo lo que el navegador puede regenerar por sí solo o lo que es simple residuo de navegar.

| Se conserva siempre | Se elimina (según lo que elijas) |
|---|---|
| Perfiles y su configuración | Caché y miniaturas |
| Marcadores | Historial de navegación |
| Contraseñas guardadas | Cookies |
| Extensiones | Almacenamiento web por origen, formularios y sesiones |
| Temas | Favicons |
| Certificados | Logs y volcados de fallos |
| Motores de búsqueda | Telemetría y archivos temporales |
| Ajustes de sincronización | Archivos de bloqueo obsoletos y WAL/SHM huérfanos |

La limpieza del almacenamiento de Chromium se limita deliberadamente a almacenes asociados a orígenes, como IndexedDB y WebSQL heredado. Los almacenes compartidos basados en LevelDB, como Local Storage y Service Worker, se dejan intactos porque también pueden contener estado de extensiones.

Esa regla se refuerza con tres capas de seguridad adicionales:

- **Vista previa antes de borrar** — en las limpiezas irreversibles calcula primero cuánto espacio liberaría, sin tocar ningún archivo, y solo continúa si lo confirmas explícitamente.
- **Copia de seguridad automática** — antes de tocar `places.sqlite`, `Web Data` o `Preferences`, guarda un `.bak` por si algo sale mal.
- **Nunca como root** — limpia el `$HOME` de tu propio usuario, nunca el sistema, y avisa si lo lanzas con `sudo` por error.

## Tipos de limpieza

| Tipo | Qué incluye |
|---|---|
| Limpieza rápida | Caché, miniaturas e informes de fallos |
| Solo cachés | Caché (y caché de componentes/extensiones en navegadores Chromium) |
| Solo cookies | Cookies |
| Solo historial | Historial de navegación |
| Limpieza completa | Rápida + historial, cookies, sesiones y formularios |
| Limpieza profunda | Completa + permisos de sitios y estado de seguridad (HSTS/NEL) en Firefox/Chromium; igual que completa en Falkon/Epiphany |

Los tipos de limpieza solo historial, solo cookies, completa y profunda son irreversibles: antes de aplicarlos se muestra una vista previa del espacio que se liberaría, y hay que confirmar explícitamente para continuar.

## Navegadores compatibles

| Motor | Navegadores |
|---|---|
| Firefox | Firefox, LibreWolf, Tor Browser, Waterfox, Floorp, Zen Browser |
| Chromium | Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge |
| QtWebEngine | Falkon |
| WebKitGTK | GNOME Web (Epiphany) |

Cada uno se detecta por su diseño de perfil nativo, Flatpak o Snap — Mint no trae Snap de fábrica, pero los perfiles Snap compatibles se detectan si están presentes. Si tienes varios perfiles en el mismo navegador, Browser-Cleaner los limpia todos.

## Instalación

```bash
git clone https://github.com/filonux/Browser-Cleaner.git
cd Browser-Cleaner/script
chmod +x browser-cleaner.sh
./browser-cleaner.sh
```

## Comandos

El modo por defecto (sin argumentos) es interactivo: detecta tus navegadores, eliges cuáles limpiar y qué tipo de limpieza aplicar mediante menús numerados.

| Comando | Qué hace |
|---|---|
| `./browser-cleaner.sh` | Abre el menú interactivo |
| `./browser-cleaner.sh --help` | Muestra la ayuda y termina |
| `./browser-cleaner.sh --version` | Muestra la versión instalada y termina |

## Úsalo con Scriptya

Si prefieres no depender de la terminal para lanzarlo, [**Scriptya**](https://github.com/filonux/Scriptya) —otra herramienta de Filonux— convierte Browser-Cleaner (o cualquier otro script) en una app independiente: con su propio icono, integrada en el menú de aplicaciones de Cinnamon y/o en el Escritorio, y con un único menú desde el que lanzarlo, actualizarlo o desinstalarlo.

```bash
git clone https://github.com/filonux/Scriptya.git
cd Scriptya/script
chmod +x scriptya.sh
./scriptya.sh --icons
```

El asistente te deja elegir `browser-cleaner.sh` y asignarle un icono — puedes usar directamente el que trae este repositorio en `assets/icon.png`.

## Compatibilidad

Probado en Linux Mint 22.3 Cinnamon. El script solo usa Bash, utilidades estándar del entorno Linux y las rutas de configuración estándar de cada navegador (`~/.mozilla`, `~/.config/...`, `~/.var/app/...` para Flatpak), así que debería funcionar igual en cualquier distro basada en Ubuntu/Debian y, en general, en cualquier distro con Bash 4+ — aunque de momento solo está verificado en Mint/Cinnamon.

La única parte atada a Debian/Ubuntu es la instalación automática de dependencias opcionales, que usa `apt`. En distros con otro gestor de paquetes esa instalación automática no se ofrece, pero si `sqlite3` y `jq` ya están instalados —o los instalas tú a mano— el resto funciona exactamente igual. Si no están, simplemente se omiten las categorías de limpieza que los necesitan, sin errores.

| Herramienta | Para qué | Si falta |
|---|---|---|
| `sqlite3` | Limpiar historial, formularios y permisos sin arriesgar marcadores ni motores de búsqueda | Se ofrece instalar vía `apt`; si no, se omite esa categoría |
| `jq` | Limpiar permisos de sitios web sin tocar el resto de la configuración | Igual que `sqlite3` |

## Sobre el idioma

Browser-Cleaner incluye ahora inglés y español.

La interfaz detecta al iniciar el locale de los mensajes del sistema. Si el locale detectado es español (empieza por `es`, incluidas variantes como `es_ES.UTF-8`), la interfaz empieza en español; en cualquier otro caso se pone en inglés por defecto. La prioridad es `LC_ALL`, después `LC_MESSAGES`, después la primera preferencia de `LANGUAGE` y, por último, `LANG`.

El idioma se puede cambiar en cualquier momento desde el menú principal con una sola tecla `L`: `es → en` o `en → es`.

Para probar o forzar un idioma sin cambiar el locale del sistema, también se puede usar `BROWSER_CLEANER_LANG`:

```bash
BROWSER_CLEANER_LANG=en ./script/browser-cleaner.sh
BROWSER_CLEANER_LANG=es ./script/browser-cleaner.sh
```

Las anotaciones del código se mantienen concisas y están en inglés; la interfaz visible para el usuario sigue disponible en inglés y español.

## Pruebas

Se incluye una batería de regresión que cubre la detección del locale, la interfaz en inglés/español, el cambio de idioma con `L`, los valores internos de los menús, la ayuda, la vista previa/cancelación de operaciones irreversibles, la disposición de la salida y una limpieza representativa de Firefox en `tests/test_browser_cleaner.sh`.

```bash
./tests/test_browser_cleaner.sh
```

## Contribuir

Los issues y pull requests son bienvenidos — hay plantillas en `.github/` para reportar errores o proponer mejoras. La guía completa está en [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Licencia

GPLv3. Consulta el archivo [LICENSE.txt](LICENSE.txt).

---

Hecho por [Filonux](https://github.com/filonux).
