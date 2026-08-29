# kaliconfig

Script de post-instalación para **Kali Linux (XFCE) sobre VMware**. Deja la máquina
lista tras una instalación limpia: actualizada, con teclado español, en castellano,
sin bloqueo de pantalla, con oh-my-zsh + powerlevel10k y el arsenal de herramientas
habitual.

---

## Instalación en un solo comando

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/surgatengit/kaliconfig/main/setup.sh)
```

> No uses `curl ... | bash`. Al canalizar por tubería, `stdin` queda ocupado y el
> menú interactivo y las preguntas de `sudo` dejan de funcionar. La sintaxis
> `bash <(curl ...)` mantiene el terminal disponible.

Si prefieres revisarlo antes de ejecutarlo (recomendable, siempre):

```bash
git clone https://github.com/surgatengit/kaliconfig
cd kaliconfig
less setup.sh
bash setup.sh
```

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
| 2 | Paquetes | Base + tus herramientas + arsenal de pentesting + `rockyou.txt` + `updatedb` |
| 3 | Idioma | `es_ES.UTF-8`, carpetas personales en inglés y sin volver a preguntar |
| 4 | Teclado | `es` / `winkeys` / `pc105` en sistema, LightDM y sesión XFCE |
| 5 | Pantalla | Desactiva DPMS, salvapantallas de XFCE y bloqueo del gestor de energía |
| 6 | Autologin | Inicio de sesión automático en LightDM |
| 7 | zsh | oh-my-zsh, `zsh-autosuggestions`, `zsh-syntax-highlighting`, powerlevel10k y alias |
| 8 | Python | `~/virtualization` y entorno `vir_ctf` |
| 9 | Docker | Instala Docker y añade el usuario al grupo |

Todos los módulos son **idempotentes**: puedes reejecutar el script las veces que
quieras sin duplicar configuración.

---

## Detalles de implementación

- **Teclado.** La casilla *«Usar los valores predeterminados del sistema»* del
  diálogo de XFCE es la propiedad `keyboard-layout → /Default/XkbDisable`.
  Ponerla a `false` equivale a desmarcarla. *Spanish (Windows)* es la variante
  `winkeys`.
- **Autologin.** Se usa un *drop-in* en `/etc/lightdm/lightdm.conf.d/` en lugar de
  editar `lightdm.conf`, para no romper el fichero original y poder revertirlo
  borrando un solo archivo.
- **Carpetas personales.** El aviso de renombrar `Escritorio`/`Descargas` lo lanza
  `xdg-user-dirs`; se silencia con `enabled=False` en `~/.config/user-dirs.conf`.
- **oh-my-zsh.** Se instala con `--unattended` para que no lance una shell nueva
  (que abortaría el script) y sin `chsh` interactivo. El `.zshrc` previo se guarda
  en `~/.zshrc.kaliconfig.bak`.
- **Alias.** Van dentro de un bloque delimitado por
  `# >>> kaliconfig >>>` … `# <<< kaliconfig <<<`, que se borra y regenera en cada
  ejecución. Puedes escribir tus propios alias fuera del bloque sin miedo.
- **Paquetes.** Se instalan uno a uno comprobando antes que existan en los repos,
  de modo que un nombre erróneo no aborte toda la instalación. Lo que no está en
  Kali (`evil-winrm-py`) se instala vía `pipx`.

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

En la primera terminal, powerlevel10k lanzará su asistente de configuración.
Para relanzarlo más tarde: `p10k configure`.

Comprobaciones rápidas:

```bash
setxkbmap -query
locale
xset q | grep -A2 'Screen Saver'
docker run --rm hello-world
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

# .zshrc anterior a oh-my-zsh
cp ~/.zshrc.kaliconfig.bak ~/.zshrc
```
