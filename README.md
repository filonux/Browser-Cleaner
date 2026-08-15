[![Icono de Browser-Cleaner](assets/icon.png)](assets/icon.png)

# Browser-Cleaner

Limpiador interactivo de navegadores para Linux: detecta lo que tienes instalado, te deja elegir qué borrar, y nunca toca lo que te identifica como usuario — perfiles, marcadores, contraseñas o extensiones.

![Bash 4+](https://img.shields.io/badge/bash-%3E%3D4.0-4EAA25?logo=gnubash&logoColor=white) ![Linux Mint 22.3 Cinnamon](https://img.shields.io/badge/Linux%20Mint-22.3%20Cinnamon-87CF3E?logo=linuxmint&logoColor=white) ![Licencia GPLv3](https://img.shields.io/badge/licencia-GPLv3-blue)

---

## El problema que resuelve

Con el uso, cualquier navegador acumula caché, historial, cookies, sesiones y archivos temporales que solo ocupan espacio y no aportan nada. Limpiarlo a mano implica entrar en los ajustes de cada navegador por separado — y si usas varios, repetir el proceso en cada uno. Las herramientas genéricas de "limpieza del sistema", por su parte, no siempre dejan claro qué tocan exactamente, con el riesgo real de llevarse por delante marcadores o sesiones guardadas.

Browser-Cleaner detecta qué navegadores tienes instalados, te deja elegir cuáles y qué limpiar, y te dice cuánto espacio vas a recuperar antes de borrar nada.

<img width="655" height="435" alt="browser-cleaner-menu" src="https://github.com/user-attachments/assets/9039ec58-c20b-47d6-ba8d-99fdc039e010" />

## Qué hace exactamente

- Detecta automáticamente los navegadores instalados — como paquete `.deb` nativo, Flatpak o Snap — y cuántos perfiles tiene cada uno.
- Seis tipos de limpieza a elegir: rápida, completa, profunda, o solo caché, cookies o historial (ver [Tipos de limpieza](#tipos-de-limpieza)).
- Vista previa y confirmación explícita antes de cualquier borrado irreversible.
- Copia de seguridad automática de los archivos críticos antes de tocarlos.
- Comprueba que el navegador esté cerrado antes de limpiar sus perfiles, para no corromper nada a medio escribir.
- Si faltan `sqlite3` o `jq` — se usan para depurar historial, formularios y permisos con precisión — se ofrece instalarlos con `apt` automáticamente; si rechazas o falla, simplemente se omite esa parte sin abortar el resto.
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
| Extensiones | Almacenamiento web, formularios y sesiones |
| Temas | Favicons |
| Certificados | Logs y volcados de fallos |
| Motores de búsqueda | Telemetría y archivos temporales |
| Ajustes de sincronización | Archivos de bloqueo obsoletos y WAL/SHM huérfanos |

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
| Limpieza profunda | Completa + permisos de sitios web y estado de seguridad (HSTS/NEL) |

Historial, cookies, completa y profunda son irreversibles: antes de aplicarlas se muestra una vista previa del espacio que se liberaría, y hay que confirmar explícitamente para continuar.

## Navegadores compatibles

| Motor | Navegadores |
|---|---|
| Firefox | Firefox, LibreWolf, Tor Browser, Waterfox, Floorp, Zen Browser |
| Chromium | Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge |
| QtWebEngine | Falkon |
| WebKitGTK | GNOME Web (Epiphany) |

Cada uno se detecta ya sea como paquete `.deb` nativo, Flatpak o Snap — Mint no trae Snap de fábrica, pero si lo instalaste a mano también se detecta. Si tienes varios perfiles en el mismo navegador, Browser-Cleaner los limpia todos.

## Instalación

```bash
git clone https://github.com/filonux/Browser-Cleaner.git
cd browser-cleaner/script
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

Probado en Linux Mint 22.3 Cinnamon. El script solo usa Bash, coreutils y las rutas de configuración estándar de cada navegador (`~/.mozilla`, `~/.config/...`, `~/.var/app/...` para Flatpak), así que debería funcionar igual en cualquier distro basada en Ubuntu/Debian y, en general, en cualquier distro con Bash 4+ — aunque de momento solo está verificado en Mint/Cinnamon.

La única parte atada a Debian/Ubuntu es la instalación automática de dependencias opcionales, que usa `apt`. En distros con otro gestor de paquetes esa instalación automática no se ofrece, pero si `sqlite3` y `jq` ya están instalados —o los instalas tú a mano— el resto funciona exactamente igual. Si no están, simplemente se omiten las categorías de limpieza que los necesitan, sin errores.

| Herramienta | Para qué | Si falta |
|---|---|---|
| `sqlite3` | Depurar historial, formularios y permisos sin arriesgar marcadores ni motores de búsqueda | Se ofrece instalar vía `apt`; si no, se omite esa categoría |
| `jq` | Depurar permisos de sitios web sin tocar el resto de la configuración | Igual que `sqlite3` |

## Sobre el idioma

Browser-Cleaner está en español: menús, ayuda, mensajes y comentarios del código. No hay versión en inglés todavía.

**Mini roadmap**, sujeto a que haya interés real:

- [ ] Traducción completa de menús, ayuda y mensajes al inglés
- [ ] Forma de elegir idioma (detección del sistema o flag `--lang`)

Si te interesaría usarlo en inglés, dilo en un issue — es la señal que necesito para priorizarlo.

## Contribuir

Los issues y pull requests son bienvenidos — hay plantillas en `.github/` para reportar errores o proponer mejoras. La guía completa está en [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Licencia

GPLv3. Consulta el archivo [LICENSE](LICENSE).

---

Hecho por [Filonux](https://github.com/filonux).
