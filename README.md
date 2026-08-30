# kaliconfig

Script de post-instalación para **Kali Linux (XFCE) sobre VMware**. Deja la máquina
lista tras una instalación limpia: actualizada, con teclado español, en castellano,
sin bloqueo de pantalla, con oh-my-zsh + powerlevel10k, Docker CE y el arsenal de
herramientas habitual.

---

## Instalación en un solo comando

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/surgatengit/kaliconfig/master/setup.sh)
```

Dos detalles que hacen que funcione:

- La URL es la de **`raw.githubusercontent.com`**, no la de `github.com/.../blob/...`.
  Esta última devuelve la página web de GitHub, no el fichero.
- La rama de este repositorio es **`master`**, no `main`.
- No uses `curl ... | bash`. Al canalizar por tubería, `stdin` queda ocupado y el
  menú interactivo y la contraseña de `sudo` dejan de funcionar. La sintaxis
  `bash <(curl ...)` mantiene el terminal libre.

Si prefieres revisarlo antes de ejecutarlo (recomendable, siempre):

```bash
git clone https://github.com/surgatengit/kaliconfig
cd kaliconfig
less setup.sh
bash setup.sh
```

Ejecutado desde el clon, el script usa el `.p10k.zsh` local en vez de descargarlo.

---

## Antes de empezar

### Bug de VMware con el ratón y los gráficos (2026-08-29)

Con las versiones actuales de VMware el puntero puede no representarse
correctamente o el escritorio ir a tirones. **No es un problema de Kali.**
Con la máquina apagada:

1. `VM > Settings > Display` → marcar **Accelerate 3D graphics**.
2. `VM > Manage > Change Hardware Compatibility` → actualizar a la última versión.
3. Actualizar VMware Workstation/Player a la última versión disponible.

### Antivirus del anfitrión

Un antivirus activo en el equipo host puede interceptar el tráfico HTTPS y hacer
que `apt update` falle con errores de hash o de conexión. Si el módulo 1 falla,
desactívalo temporalmente.

### Snapshot

Haz un snapshot de la VM antes de ejecutar el script.

---

## Uso

| Comando | Efecto |
|---|---|
| `bash setup.sh` | Menú interactivo |
| `bash setup.sh --all` | Ejecuta todos los módulos sin preguntar |
| `bash setup.sh --only 4,5` | Ejecuta solo los módulos indicados |
| `bash setup.sh --list` | Lista los módulos y sale |

El registro completo queda en `~/kaliconfig.log`.

**Ejecutar como usuario normal, no con `sudo`, y dentro de la sesión gráfica de
XFCE.** El script aborta si detecta root, porque `xfconf`, `oh-my-zsh` y `~/.zshrc`
son configuración de usuario. Pedirá la contraseña de sudo una única vez.

---

## Módulos

| # | Módulo | Qué hace |
|---|---|---|
| 1 | Actualizar | `apt update`, `full-upgrade`, `autoremove`, zona horaria Europe/Madrid |
| 2 | Paquetes | Base + herramientas + arsenal de pentesting + `rockyou.txt` + `updatedb` |
| 3 | Idioma | `es_ES.UTF-8`, carpetas personales en inglés y sin volver a preguntar |
| 4 | Teclado | `es` / `winkeys` / `pc105` en sistema, LightDM y sesión XFCE |
| 5 | Pantalla | Desactiva DPMS, salvapantallas de XFCE y bloqueo del gestor de energía |
| 6 | Autologin | Inicio de sesión automático en LightDM |
| 7 | zsh | oh-my-zsh, plugins, powerlevel10k con el `.p10k.zsh` del repo, fuentes y alias |
| 8 | Python | `~/virtualization` y entorno `vir_ctf` |
| 9 | Docker | Docker CE desde el repositorio oficial de Docker |
| 10 | Thunar | Mostrar archivos ocultos y ruta completa en el título |

Todos los módulos son **idempotentes**: puedes reejecutar el script las veces que
quieras sin duplicar configuración.

---

## Detalles de implementación

### Teclado
La casilla *«Usar los valores predeterminados del sistema»* del diálogo de XFCE es
la propiedad `keyboard-layout → /Default/XkbDisable`. Ponerla a `false` equivale a
desmarcarla. *Spanish (Windows)* es la variante `winkeys`.

### Autologin
Se usa un *drop-in* en `/etc/lightdm/lightdm.conf.d/` en lugar de editar
`lightdm.conf`, para no romper el fichero original y poder revertirlo borrando un
solo archivo.

### Carpetas personales
El aviso de renombrar `Escritorio`/`Descargas` lo lanza `xdg-user-dirs`; se
silencia con `enabled=False` en `~/.config/user-dirs.conf`.

### Docker
Se instala **Docker CE del repositorio oficial**, no el `docker.io` de Debian.
Antes se desinstalan los paquetes que entran en conflicto (`docker.io`,
`docker-compose`, `containerd`, `runc`, `podman-docker`).

Kali es una distribución *rolling*: su `VERSION_CODENAME` es `kali-rolling`, un
nombre que Docker no publica en su repositorio. Por eso el script **comprueba por
HTTP qué suite de Debian existe realmente** (`trixie`, luego `bookworm`, luego
`bullseye`) y escribe la primera que responda, en formato `deb822`
(`/etc/apt/sources.list.d/docker.sources`).

El script **no ejecuta `newgrp docker`**, porque abre una shell hija y dejaría el
script colgado. Para usar Docker sin `sudo` en la terminal actual, ejecútalo tú
después; o cierra sesión, que es lo definitivo.

### powerlevel10k
El `.p10k.zsh` del repositorio se copia a `~/.p10k.zsh`, con lo que el asistente
de configuración no llega a aparecer. También se añade el bloque de *instant
prompt* al principio de `~/.zshrc` y se instalan las fuentes **MesloLGS NF**, que
son las que necesita el tema para dibujar los iconos. El script intenta además
configurar la fuente en `qterminal` y en `xfce4-terminal`.

> Si `qterminal` está abierto mientras se ejecuta el módulo 7, al cerrarlo puede
> sobrescribir el fichero de configuración. En ese caso pon la fuente a mano en
> sus preferencias.

### oh-my-zsh
Se instala con `--unattended` para que no lance una shell nueva (que abortaría el
script) y sin `chsh` interactivo. El `.zshrc` previo se guarda en
`~/.zshrc.kaliconfig.bak`.

### Alias
Van dentro de un bloque delimitado por `# >>> kaliconfig >>>` …
`# <<< kaliconfig <<<`, que se borra y regenera en cada ejecución. Escribe tus
propios alias **fuera** del bloque.

### Paquetes
Se instalan uno a uno comprobando antes que existan en los repos, de modo que un
nombre erróneo no aborte toda la instalación. Lo que no está en Kali
(`evil-winrm-py`) se instala vía `pipx`.

---

## Alias y funciones que añade

```bash
l                    # ls -lahptr con fecha larga
ll                   # listado detallado
ip4                  # interfaces y direcciones IPv4, formato breve
serve                # servidor HTTP en el puerto 8000

lvir                 # lista los entornos virtuales y recuerda la sintaxis
entra <entorno>      # activa ~/virtualization/<entorno>  (con autocompletado)
crear_vir <nombre>   # crea un entorno nuevo
```

---

## Después de ejecutarlo

Cierra la sesión o reinicia la VM. Hasta entonces no se aplican el idioma, el
teclado en la pantalla de login, el autologin, el grupo `docker` ni el cambio de
shell.

Comprobaciones rápidas:

```bash
setxkbmap -query
locale
xset q | grep -A2 'Screen Saver'
docker run --rm hello-world
xfconf-query -c thunar -p /last-show-hidden
```

---

## Cómo revertir

```bash
# Autologin
sudo rm /etc/lightdm/lightdm.conf.d/12-autologin.conf

# Bloqueo de pantalla
xfconf-query -c xfce4-screensaver -p /saver/enabled -s true
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled -s true
rm ~/.config/autostart/kaliconfig-no-blank.desktop

# Docker CE
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc

# .zshrc anterior a oh-my-zsh
cp ~/.zshrc.kaliconfig.bak ~/.zshrc
```

---

## Contribuir desde Windows

Si editas el script en Windows, asegúrate de que se guarda con finales de línea
**LF**. Con CRLF, Kali devuelve `bad interpreter: /bin/bash^M` y el script no
arranca. El `.gitattributes` del repositorio ya fuerza `eol=lf` para `*.sh`.
