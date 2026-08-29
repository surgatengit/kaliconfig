#!/usr/bin/env bash
#===============================================================================
#  kaliconfig - Post-instalación de Kali Linux (XFCE) sobre VMware
#  https://github.com/surgatengit/kaliconfig
#
#  Uso:
#      bash <(curl -fsSL https://raw.githubusercontent.com/surgatengit/kaliconfig/main/setup.sh)
#
#  Opciones:
#      --all        Ejecuta todos los módulos sin preguntar
#      --only 1,4,7 Ejecuta solo los módulos indicados
#      --list       Muestra los módulos disponibles y sale
#
#  IMPORTANTE: ejecutar como usuario normal (NO con sudo), dentro de la sesión
#  gráfica de XFCE. El script pedirá la contraseña de sudo una sola vez.
#===============================================================================

set -uo pipefail

VERSION="1.0"
LOG="$HOME/kaliconfig.log"
USUARIO="$(id -un)"

# ------------------------------------------------------------------ colores --
R='\033[1;31m'; V='\033[1;32m'; A='\033[1;33m'; Z='\033[1;34m'; C='\033[1;36m'; N='\033[0m'
info()  { printf "${Z}[*]${N} %s\n" "$*"  | tee -a "$LOG"; }
ok()    { printf "${V}[+]${N} %s\n" "$*"  | tee -a "$LOG"; }
warn()  { printf "${A}[!]${N} %s\n" "$*"  | tee -a "$LOG"; }
err()   { printf "${R}[x]${N} %s\n" "$*"  | tee -a "$LOG"; }
titulo(){ printf "\n${C}=== %s ===${N}\n" "$*" | tee -a "$LOG"; }

#===============================================================================
#  COMPROBACIONES PREVIAS
#===============================================================================
if [ "$(id -u)" -eq 0 ]; then
    err "No ejecutes este script como root ni con sudo."
    err "Muchas partes (oh-my-zsh, xfconf, ~/.zshrc) son del usuario."
    err "Ejecuta:  bash setup.sh"
    exit 1
fi

if ! command -v sudo >/dev/null; then
    err "sudo no está disponible."; exit 1
fi

banner() {
cat <<'EOF'

 ██╗  ██╗ █████╗ ██╗     ██╗ ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
 ██║ ██╔╝██╔══██╗██║     ██║██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
 █████╔╝ ███████║██║     ██║██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
 ██╔═██╗ ██╔══██║██║     ██║██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
 ██║  ██╗██║  ██║███████╗██║╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
 ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝

EOF
printf "  Post-instalación de Kali sobre VMware  ·  v%s  ·  usuario: %s\n\n" "$VERSION" "$USUARIO"
}

avisos_previos() {
cat <<EOF
$(printf "${A}")┌──────────────────────────────────────────────────────────────────────────┐
│  ANTES DE EMPEZAR — LÉEME                                                │
└──────────────────────────────────────────────────────────────────────────┘$(printf "${N}")

  $(printf "${C}1. Ratón / gráficos en VMware (bug detectado el 2026-08-29)${N})
     Si el puntero se comporta de forma errática o el escritorio va a tirones,
     NO es problema de Kali sino del host. Solución comprobada:
       · VM > Settings > Display  ->  marcar "Accelerate 3D graphics"
       · VM > Manage > Change Hardware Compatibility -> última versión
       · Actualizar VMware Workstation/Player a la última versión
     Apaga la máquina antes de tocar esos ajustes.

  $(printf "${C}2. Antivirus del anfitrión${N})
     Un antivirus activo en el equipo host puede cortar la descarga de paquetes
     y hacer que 'apt update' falle con errores de hash o de conexión.
     Si el módulo 1 falla, desactívalo temporalmente y reintenta.

  $(printf "${C}3. Snapshot${N})
     Recomendable hacer un snapshot de la VM antes de ejecutar esto.

EOF
}

# --------------------------------------------------- diagnóstico de la VM ----
diagnostico_vm() {
    local producto
    producto="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo desconocido)"
    info "Plataforma detectada: $producto"
    if echo "$producto" | grep -qi vmware; then
        if ! dpkg -s open-vm-tools >/dev/null 2>&1; then
            warn "open-vm-tools NO está instalado: sin portapapeles ni autoajuste de resolución."
            warn "Se instalará en el módulo 2."
        else
            ok "open-vm-tools presente."
        fi
        if ! lsmod | grep -q vmwgfx; then
            warn "El driver vmwgfx no está cargado -> revisa la aceleración 3D (aviso 1)."
        fi
    fi
}

#===============================================================================
#  MÓDULO 1 — Actualización del sistema
#===============================================================================
mod_actualizar() {
    titulo "1. Actualización del sistema"
    export DEBIAN_FRONTEND=noninteractive
    local OPTS=(-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)

    info "apt update ..."
    if ! sudo apt-get update 2>&1 | tee -a "$LOG" | tail -3; then
        err "Falló apt update. ¿Antivirus en el anfitrión? ¿Sin red?"
        return 1
    fi
    info "apt full-upgrade (esto puede tardar bastante) ..."
    sudo apt-get "${OPTS[@]}" full-upgrade 2>&1 | tee -a "$LOG" | tail -5
    info "apt autoremove ..."
    sudo apt-get "${OPTS[@]}" autoremove 2>&1 | tee -a "$LOG" | tail -3

    info "Ajustando zona horaria a Europe/Madrid ..."
    sudo timedatectl set-timezone Europe/Madrid 2>/dev/null || warn "No se pudo fijar la zona horaria."
    ok "Sistema actualizado."
}

#===============================================================================
#  MÓDULO 2 — Paquetes y herramientas
#===============================================================================
PKGS_BASE=(
    git curl wget zsh xclip jq faketime ntpsec-ntpdate
    python3-pip python3-venv python3-virtualenv pipx
    open-vm-tools open-vm-tools-desktop
)
PKGS_USUARIO=(
    feroxbuster nuclei enum4linux-ng ghidra wordlists
)
PKGS_ARSENAL=(
    seclists netexec responder impacket-scripts mitm6
    evil-winrm ligolo-ng chisel ffuf gobuster
    tmux fzf bat ripgrep
)

instalar_paquete() {
    local p="$1"
    if dpkg -s "$p" >/dev/null 2>&1; then
        printf "    · %-22s ya instalado\n" "$p"; return 0
    fi
    if ! apt-cache show "$p" >/dev/null 2>&1; then
        printf "    ${A}· %-22s NO existe en los repos (omitido)${N}\n" "$p"; return 1
    fi
    if sudo apt-get install -y -o Dpkg::Options::=--force-confold "$p" >>"$LOG" 2>&1; then
        printf "    ${V}· %-22s instalado${N}\n" "$p"
    else
        printf "    ${R}· %-22s ERROR (ver $LOG)${N}\n" "$p"; return 1
    fi
}

mod_paquetes() {
    titulo "2. Instalación de paquetes"
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update >>"$LOG" 2>&1

    info "Base del sistema:"
    for p in "${PKGS_BASE[@]}";    do instalar_paquete "$p"; done
    info "Tu lista de herramientas:"
    for p in "${PKGS_USUARIO[@]}"; do instalar_paquete "$p"; done
    info "Arsenal de pentesting:"
    for p in "${PKGS_ARSENAL[@]}"; do instalar_paquete "$p"; done

    # --- Herramientas vía pipx (no están en los repos de Kali) --------------
    if command -v pipx >/dev/null; then
        info "Herramientas vía pipx:"
        pipx ensurepath >>"$LOG" 2>&1
        for t in evil-winrm-py; do
            if pipx list 2>/dev/null | grep -q "$t"; then
                printf "    · %-22s ya instalado\n" "$t"
            elif pipx install "$t" >>"$LOG" 2>&1; then
                printf "    ${V}· %-22s instalado (pipx)${N}\n" "$t"
            else
                printf "    ${A}· %-22s no se pudo instalar${N}\n" "$t"
            fi
        done
    fi

    # --- rockyou ------------------------------------------------------------
    if [ -f /usr/share/wordlists/rockyou.txt.gz ] && [ ! -f /usr/share/wordlists/rockyou.txt ]; then
        info "Descomprimiendo rockyou.txt ..."
        sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz
        ok "rockyou.txt disponible."
    elif [ -f /usr/share/wordlists/rockyou.txt ]; then
        ok "rockyou.txt ya estaba descomprimido."
    fi

    info "Actualizando la base de datos de locate ..."
    sudo updatedb 2>/dev/null || true
    ok "Paquetes listos."
}

#===============================================================================
#  MÓDULO 3 — Idioma (es_ES.UTF-8, carpetas personales en inglés)
#===============================================================================
mod_idioma() {
    titulo "3. Idioma del sistema: es_ES.UTF-8"

    info "Generando el locale es_ES.UTF-8 ..."
    sudo sed -i 's/^# *\(es_ES\.UTF-8 UTF-8\)/\1/'   /etc/locale.gen
    sudo sed -i 's/^\(en_US\.UTF-8 UTF-8\)/# \1/'    /etc/locale.gen
    grep -q '^es_ES.UTF-8' /etc/locale.gen || echo 'es_ES.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
    sudo locale-gen >>"$LOG" 2>&1
    sudo update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es
    ok "LANG=es_ES.UTF-8"

    # --- Carpetas personales: mantener los nombres antiguos (en inglés) -----
    info "Fijando las carpetas personales en inglés y silenciando el aviso ..."
    mkdir -p "$HOME/.config"
    printf 'enabled=False\n' > "$HOME/.config/user-dirs.conf"
    printf 'en_US\n'          > "$HOME/.config/user-dirs.locale"
    ok "Desktop/Downloads/Documents no se renombrarán y no volverá a preguntar."
    warn "El cambio de idioma se ve del todo tras cerrar sesión."
}

#===============================================================================
#  MÓDULO 4 — Teclado español (Spanish - Windows)
#===============================================================================
MODEL="pc105"; LAYOUT="es"; VARIANT="winkeys"

xset_prop() {  # canal propiedad tipo valor
    xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" 2>/dev/null \
        || xfconf-query -c "$1" -p "$2" -s "$4" 2>/dev/null \
        || warn "No se pudo fijar $1$2"
}

mod_teclado() {
    titulo "4. Teclado español (Spanish - Windows)"

    info "Escribiendo /etc/default/keyboard (consola y LightDM) ..."
    sudo tee /etc/default/keyboard >/dev/null <<EOF
# Generado por kaliconfig
XKBMODEL="$MODEL"
XKBLAYOUT="$LAYOUT"
XKBVARIANT="$VARIANT"
XKBOPTIONS=""
BACKSPACE="guess"
EOF
    sudo dpkg-reconfigure -f noninteractive keyboard-configuration >>"$LOG" 2>&1
    sudo setupcon --force >>"$LOG" 2>&1 || true
    command -v localectl >/dev/null && \
        sudo localectl set-x11-keymap "$LAYOUT" "$MODEL" "$VARIANT" 2>/dev/null || true

    if [ -n "${DISPLAY:-}" ]; then
        info "Aplicando la distribución en XFCE ..."
        # XkbDisable=false  ==  casilla "Usar valores predeterminados del sistema" DESACTIVADA
        xset_prop keyboard-layout /Default/XkbDisable bool   false
        xset_prop keyboard-layout /Default/XkbModel   string "$MODEL"
        xset_prop keyboard-layout /Default/XkbLayout  string "$LAYOUT"
        xset_prop keyboard-layout /Default/XkbVariant string "$VARIANT"
        setxkbmap -model "$MODEL" -layout "$LAYOUT" -variant "$VARIANT" 2>/dev/null
        ok "Activo: $(setxkbmap -query | tr '\n' ' ')"
    else
        warn "Sin \$DISPLAY: solo se aplicó la parte de sistema."
    fi
}

#===============================================================================
#  MÓDULO 5 — Sin bloqueo de pantalla ni salvapantallas
#===============================================================================
mod_pantalla() {
    titulo "5. Desactivar bloqueo de pantalla y salvapantallas"
    if [ -z "${DISPLAY:-}" ]; then
        warn "Sin \$DISPLAY: módulo omitido (ejecútalo dentro de XFCE)."; return 1
    fi

    local P=/xfce4-power-manager
    info "Gestor de energía ..."
    xset_prop xfce4-power-manager $P/dpms-enabled                  bool false
    xset_prop xfce4-power-manager $P/lock-screen-suspend-hibernate bool false
    xset_prop xfce4-power-manager $P/blank-on-ac                   int  0
    xset_prop xfce4-power-manager $P/blank-on-battery              int  0
    xset_prop xfce4-power-manager $P/dpms-on-ac-sleep              int  0
    xset_prop xfce4-power-manager $P/dpms-on-ac-off                int  0
    xset_prop xfce4-power-manager $P/dpms-on-battery-sleep         int  0
    xset_prop xfce4-power-manager $P/dpms-on-battery-off           int  0
    xset_prop xfce4-power-manager $P/inactivity-on-ac              int  14
    xset_prop xfce4-power-manager $P/inactivity-on-battery         int  14

    info "Salvapantallas de XFCE ..."
    xset_prop xfce4-screensaver /saver/enabled                 bool false
    xset_prop xfce4-screensaver /saver/idle-activation/enabled bool false
    xset_prop xfce4-screensaver /lock/enabled                  bool false
    xset_prop xfce4-screensaver /lock/saver-activation/enabled bool false
    xset_prop xfce4-screensaver /lock/sleep-activation         bool false
    pkill -x xfce4-screensaver 2>/dev/null || true

    if command -v light-locker >/dev/null; then
        info "Neutralizando light-locker ..."
        pkill -x light-locker 2>/dev/null || true
        mkdir -p "$HOME/.config/autostart"
        printf '[Desktop Entry]\nType=Application\nName=light-locker\nHidden=true\n' \
            > "$HOME/.config/autostart/light-locker.desktop"
    fi

    xset s off; xset s noblank; xset -dpms
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/kaliconfig-no-blank.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=kaliconfig - sin apagado de pantalla
Exec=sh -c "xset s off; xset s noblank; xset -dpms"
X-XFCE-Autostart-Enabled=true
EOF
    ok "La pantalla ya no se apaga ni se bloquea."
}

#===============================================================================
#  MÓDULO 6 — Inicio de sesión automático (LightDM)
#===============================================================================
mod_autologin() {
    titulo "6. Inicio de sesión automático"
    warn "Esto elimina la contraseña de arranque. Úsalo solo en VMs de laboratorio."

    # Se usa un drop-in en conf.d: es idempotente y no toca lightdm.conf original
    sudo mkdir -p /etc/lightdm/lightdm.conf.d
    sudo tee /etc/lightdm/lightdm.conf.d/12-autologin.conf >/dev/null <<EOF
# Generado por kaliconfig
[Seat:*]
autologin-user=$USUARIO
autologin-user-timeout=0
EOF
    sudo groupadd -f autologin
    sudo usermod -aG autologin "$USUARIO"
    ok "Autologin configurado para '$USUARIO'."
    warn "Si al entrar te pide la contraseña del llavero, bórralo en Contraseñas y claves."
}

#===============================================================================
#  MÓDULO 7 — zsh: oh-my-zsh, plugins, powerlevel10k y alias
#===============================================================================
mod_zsh() {
    titulo "7. zsh + oh-my-zsh + powerlevel10k"
    local ZSH_DIR="$HOME/.oh-my-zsh"
    local CUSTOM="$ZSH_DIR/custom"

    # --- oh-my-zsh ----------------------------------------------------------
    if [ -d "$ZSH_DIR" ]; then
        ok "oh-my-zsh ya instalado."
    else
        info "Instalando oh-my-zsh (modo desatendido) ..."
        [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.kaliconfig.bak"
        RUNZSH=no CHSH=no sh -c \
          "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
          "" --unattended >>"$LOG" 2>&1
        [ -d "$ZSH_DIR" ] && ok "oh-my-zsh instalado (copia previa en ~/.zshrc.kaliconfig.bak)" \
                          || { err "Falló la instalación de oh-my-zsh."; return 1; }
    fi

    # --- plugins ------------------------------------------------------------
    clonar() {  # url destino
        if [ -d "$2" ]; then printf "    · %-26s ya presente\n" "$(basename "$2")"
        else git clone --depth=1 "$1" "$2" >>"$LOG" 2>&1 \
             && printf "    ${V}· %-26s clonado${N}\n" "$(basename "$2")" \
             || printf "    ${R}· %-26s ERROR${N}\n" "$(basename "$2")"
        fi
    }
    info "Plugins y tema:"
    clonar https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM/plugins/zsh-syntax-highlighting"
    clonar https://github.com/zsh-users/zsh-autosuggestions        "$CUSTOM/plugins/zsh-autosuggestions"
    clonar https://github.com/romkatv/powerlevel10k.git            "$CUSTOM/themes/powerlevel10k"

    # --- .zshrc: tema y plugins --------------------------------------------
    info "Configurando ~/.zshrc ..."
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$HOME/.zshrc"
    grep -q '^ZSH_THEME=' "$HOME/.zshrc" || \
        sed -i '1i ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"

    # zsh-syntax-highlighting debe ir SIEMPRE el último de la lista
    perl -0pi -e 's/^plugins=\([^)]*\)/plugins=(\n  git\n  sudo\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n)/ms' \
        "$HOME/.zshrc"

    # --- bloque propio de alias (idempotente) -------------------------------
    sed -i '/# >>> kaliconfig >>>/,/# <<< kaliconfig <<</d' "$HOME/.zshrc"
    cat >> "$HOME/.zshrc" <<'EOF'
# >>> kaliconfig >>>
# Bloque gestionado por kaliconfig. Se regenera al reejecutar el script.

export PATH="$PATH:$HOME/.local/bin"

# Listado más visual
alias l='ls -lahptr --time-style long-iso --color=auto'
alias ll='ls -lahF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# --- Entornos virtuales de Python -------------------------------------------
alias lvir='ls ~/virtualization && echo "\n# Para activar un entorno: entra <Nombre_delEntorno>\n# Crear un entorno vir_ctf Ejecuta:\nvirtualenv ~/virtualization/vir_ctf/ \n# Desactivar: deactivate Activar:\nsource ~/virtualization/vir_ctf/bin/activate"'

entra() {
  if [ -z "$1" ]; then
    echo "Uso: entra <nombre_entorno>"; ls ~/virtualization 2>/dev/null; return 1
  fi
  if [ ! -f "$HOME/virtualization/$1/bin/activate" ]; then
    echo "No existe el entorno '$1' en ~/virtualization"; return 1
  fi
  source "$HOME/virtualization/$1/bin/activate"
}

# Autocompletado para 'entra'
_entra() { compadd $(ls ~/virtualization 2>/dev/null); }
compdef _entra entra 2>/dev/null

# Crear un entorno nuevo rápido
crear_vir() {
  [ -z "$1" ] && { echo "Uso: crear_vir <nombre>"; return 1; }
  virtualenv "$HOME/virtualization/$1" && echo "Actívalo con: entra $1"
}

# --- Utilidades de pentesting -----------------------------------------------
alias ip4='ip -4 -br a'
alias serve='python3 -m http.server 8000'
# <<< kaliconfig <<<
EOF
    ok "~/.zshrc configurado."
    warn "Al abrir la primera terminal, powerlevel10k lanzará su asistente de configuración."
    warn "Si quieres relanzarlo después:  p10k configure"

    # --- shell por defecto --------------------------------------------------
    if [ "$SHELL" != "$(command -v zsh)" ]; then
        info "Estableciendo zsh como shell por defecto ..."
        sudo chsh -s "$(command -v zsh)" "$USUARIO" && ok "Shell cambiada a zsh."
    fi
}

#===============================================================================
#  MÓDULO 8 — Entornos virtuales de Python
#===============================================================================
mod_python() {
    titulo "8. Carpeta de entornos virtuales"
    mkdir -p "$HOME/virtualization"
    if [ -d "$HOME/virtualization/vir_ctf" ]; then
        ok "El entorno vir_ctf ya existe."
    else
        info "Creando ~/virtualization/vir_ctf ..."
        if command -v virtualenv >/dev/null; then
            virtualenv "$HOME/virtualization/vir_ctf" >>"$LOG" 2>&1
        else
            python3 -m venv "$HOME/virtualization/vir_ctf" >>"$LOG" 2>&1
        fi
        [ -f "$HOME/virtualization/vir_ctf/bin/activate" ] \
            && ok "Entorno vir_ctf creado. Actívalo con: entra vir_ctf" \
            || err "No se pudo crear el entorno."
    fi
}

#===============================================================================
#  MÓDULO 9 — Docker
#===============================================================================
mod_docker() {
    titulo "9. Docker"
    if ! command -v docker >/dev/null; then
        info "Docker no está instalado. Instalando docker.io ..."
        sudo apt-get install -y docker.io >>"$LOG" 2>&1 || { err "No se pudo instalar docker.io"; return 1; }
    fi
    sudo systemctl enable --now docker >>"$LOG" 2>&1 || true
    if getent group docker >/dev/null; then
        sudo usermod -aG docker "$USUARIO"
        ok "Usuario '$USUARIO' añadido al grupo docker."
        warn "Necesitas cerrar sesión para poder usar docker sin sudo."
    else
        warn "El grupo 'docker' no existe; se omite."
    fi
}

#===============================================================================
#  MENÚ
#===============================================================================
declare -A MODULOS=(
    [1]="mod_actualizar|Actualizar el sistema (update/full-upgrade/autoremove + zona horaria)"
    [2]="mod_paquetes|Instalar paquetes y herramientas (base + tuyas + arsenal)"
    [3]="mod_idioma|Idioma es_ES.UTF-8 con carpetas personales en inglés"
    [4]="mod_teclado|Teclado español (Spanish - Windows)"
    [5]="mod_pantalla|Quitar bloqueo de pantalla y salvapantallas"
    [6]="mod_autologin|Inicio de sesión automático en LightDM"
    [7]="mod_zsh|oh-my-zsh + plugins + powerlevel10k + alias"
    [8]="mod_python|Carpeta ~/virtualization y entorno vir_ctf"
    [9]="mod_docker|Docker y grupo docker"
)
ORDEN=(1 2 3 4 5 6 7 8 9)

listar() {
    printf "\n${C}Módulos disponibles${N}\n"
    for i in "${ORDEN[@]}"; do
        printf "  ${V}%s${N}) %s\n" "$i" "${MODULOS[$i]#*|}"
    done
    printf "  ${V}a${N}) Todos\n  ${V}q${N}) Salir\n\n"
}

ejecutar() {
    local fn="${MODULOS[$1]%%|*}"
    "$fn"
}

resumen() {
    titulo "Resumen"
    ok "Registro completo en: $LOG"
    cat <<EOF

  Comprobaciones rápidas:
      setxkbmap -query
      locale
      xset q | grep -A2 'Screen Saver'
      docker run --rm hello-world

  ${A}Cierra la sesión (o reinicia la VM) para aplicar:${N}
      · idioma del sistema
      · teclado en la pantalla de login
      · autologin
      · grupo docker
      · zsh como shell por defecto

EOF
}

#===============================================================================
#  MAIN
#===============================================================================
: > "$LOG"
SELECCION=""
MODO="menu"

while [ $# -gt 0 ]; do
    case "$1" in
        --all)  MODO="todos" ;;
        --only) MODO="lista"; SELECCION="${2:-}"; shift ;;
        --list) banner; listar; exit 0 ;;
        -h|--help) banner; listar; exit 0 ;;
        *) err "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

banner
avisos_previos
diagnostico_vm

info "Solicitando privilegios de sudo (se pedirán una sola vez) ..."
sudo -v || { err "Sin sudo no se puede continuar."; exit 1; }
# Mantener vivo el sudo mientras dure el script
( while true; do sleep 60; sudo -n true 2>/dev/null || exit; done ) &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null' EXIT

if [ "$MODO" = "menu" ]; then
    listar
    read -rp "Elige módulos (ej: 1,4,7  |  a = todos  |  q = salir): " SELECCION
    [ "$SELECCION" = "q" ] && { info "Cancelado."; exit 0; }
    [ "$SELECCION" = "a" ] && MODO="todos"
fi

if [ "$MODO" = "todos" ]; then
    A_EJECUTAR=("${ORDEN[@]}")
else
    IFS=', ' read -r -a A_EJECUTAR <<< "$SELECCION"
fi

FALLOS=()
for m in "${A_EJECUTAR[@]}"; do
    if [ -n "${MODULOS[$m]:-}" ]; then
        ejecutar "$m" || FALLOS+=("$m")
    else
        warn "Módulo '$m' no válido, se omite."
    fi
done

resumen
if [ ${#FALLOS[@]} -gt 0 ]; then
    warn "Módulos con incidencias: ${FALLOS[*]} — revisa $LOG"
fi

read -rp "$(printf "${A}¿Cerrar sesión ahora para aplicar los cambios? [s/N]: ${N}")" cerrar
case "$cerrar" in
    s|S|y|Y) xfce4-session-logout --logout 2>/dev/null || sudo systemctl reboot ;;
    *) info "Recuerda cerrar sesión más tarde." ;;
esac
