#!/bin/bash

[[ -n "${FLOWEAVE_VNC_SERVER_LOADED}" ]] && return
FLOWEAVE_VNC_SERVER_LOADED=1

FLOWEAVE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FLOWEAVE_MODULE_DIR/ui-helpers.sh"
source "$FLOWEAVE_MODULE_DIR/config-manager.sh"
source "$FLOWEAVE_MODULE_DIR/display-manager.sh"

start_vnc_server_wayland() {
    if ! command -v grdctl &> /dev/null; then
        show_error "grdctl is not installed (gnome-remote-desktop required)"
        return 1
    fi

    local port="${CONFIG[vnc_port]:-5900}"
    local password="${CONFIG[vnc_password]}"

    show_info "Starting GNOME Remote Desktop VNC on port $port..."

    grdctl vnc set-port "$port" 2>/dev/null
    grdctl vnc disable-view-only 2>/dev/null

    if [[ -n "$password" ]]; then
        grdctl vnc set-auth-method password 2>/dev/null
        grdctl vnc set-password "$password" 2>/dev/null
    else
        grdctl vnc clear-password 2>/dev/null
        grdctl vnc set-auth-method prompt 2>/dev/null
    fi

    grdctl vnc enable 2>/dev/null

    if ! systemctl --user restart gnome-remote-desktop.service 2>/dev/null; then
        show_error "Failed to start gnome-remote-desktop service"
        return 1
    fi

    sleep 1

    if ! grdctl status 2>/dev/null | grep -A 3 "VNC:" | grep -q "Status: enabled"; then
        show_error "Failed to activate VNC backend in GNOME Remote Desktop"
        return 1
    fi

    local pid
    pid=$(systemctl --user show --property MainPID --value gnome-remote-desktop.service 2>/dev/null)
    if [[ -z "$pid" || "$pid" == "0" ]]; then
        pid=$(pgrep -u "$USER" -f gnome-remote-desktop-daemon | head -1)
    fi

    if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 ]]; then
        mkdir -p "$(dirname "$FLOWEAVE_PID_FILE")"
        echo "$pid" > "$FLOWEAVE_PID_FILE"
    fi

    local ip_addr
    ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$ip_addr" ]] && ip_addr="<your-ip-address>"

    show_success "VNC server started (gnome-remote-desktop)"
    show_info "Connection: ${ip_addr}:${port}"

    return 0
}

stop_vnc_server_wayland() {
    grdctl vnc disable 2>/dev/null
    if ! systemctl --user restart gnome-remote-desktop.service 2>/dev/null; then
        show_error "Failed to restart gnome-remote-desktop service"
        return 1
    fi
    rm -f "$FLOWEAVE_PID_FILE"
    show_success "VNC server stopped"
    return 0
}

start_vnc_server() {
    local port="${CONFIG[vnc_port]}"
    local password="${CONFIG[vnc_password]}"

    if is_running; then
        show_error "VNC server is already running"
        show_info "Use 'floweave stop' to stop it first"
        return 1
    fi

    detect_display_backend
    if [[ "$FLOWEAVE_BACKEND" == "gnome-wayland" ]]; then
        start_vnc_server_wayland
        return $?
    fi

    if ! calculate_display_geometry; then
        return 1
    fi

    show_info "Starting VNC server on port $port"
    show_info "Clip region: $CLIP_GEOMETRY"

    local vnc_cmd="x11vnc -display :0"
    vnc_cmd="$vnc_cmd -clip $CLIP_GEOMETRY"
    vnc_cmd="$vnc_cmd -rfbport $port"
    vnc_cmd="$vnc_cmd -forever"
    vnc_cmd="$vnc_cmd -shared"
    vnc_cmd="$vnc_cmd -cursor most"
    vnc_cmd="$vnc_cmd -cursorpos"
    vnc_cmd="$vnc_cmd -nocursorshape"
    vnc_cmd="$vnc_cmd -nocursorpos"
    vnc_cmd="$vnc_cmd -arrow 6"
    vnc_cmd="$vnc_cmd -xwarppointer"
    vnc_cmd="$vnc_cmd -buttonmap 123"
    vnc_cmd="$vnc_cmd -fixscreen V=3.0"
    vnc_cmd="$vnc_cmd -desktop Floweave-$USER"
    vnc_cmd="$vnc_cmd -wait 5"
    vnc_cmd="$vnc_cmd -defer 5"

    if [[ -n "$password" ]]; then
        vnc_cmd="$vnc_cmd -passwd $password"
    else
        vnc_cmd="$vnc_cmd -nopw"
    fi

    # Start in an isolated session so Ctrl+C does not terminate the background daemon
    (
        setsid bash -c "
            trap '' SIGINT SIGTERM
            nohup $vnc_cmd >/dev/null 2>&1 &
            mkdir -p '$(dirname "$FLOWEAVE_PID_FILE")'
            echo \$! > '$FLOWEAVE_PID_FILE'
        " >/dev/null 2>&1 &
    )

    sleep 2

    if [[ ! -f "$FLOWEAVE_PID_FILE" ]]; then
        show_error "Failed to create PID file"
        return 1
    fi

    local vnc_pid
    vnc_pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)

    if [[ -z "$vnc_pid" ]] || ! ps -p "$vnc_pid" > /dev/null 2>&1; then
        show_error "VNC server failed to start"
        rm -f "$FLOWEAVE_PID_FILE"
        return 1
    fi

    local ip_addr
    ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$ip_addr" ]] && ip_addr="<your-ip-address>"

    show_success "VNC server started (PID: $vnc_pid)"
    show_info "Connection: ${ip_addr}:${port}"

    return 0
}

stop_vnc_server() {
    detect_display_backend

    local pid=""
    [[ -f "$FLOWEAVE_PID_FILE" ]] && pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)
    local comm=""
    [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] && comm=$(ps -p "$pid" -o comm= 2>/dev/null)

    if [[ "$FLOWEAVE_BACKEND" == "gnome-wayland" || "$comm" =~ gnome-remote ]]; then
        stop_vnc_server_wayland
        return $?
    fi

    if [[ -f "$FLOWEAVE_PID_FILE" ]]; then
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid" 2>/dev/null

                local count=0
                while ps -p "$pid" > /dev/null 2>&1 && [[ $count -lt 5 ]]; do
                    sleep 1
                    count=$((count + 1))
                done

                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" 2>/dev/null
                fi

                show_success "VNC server stopped (PID: $pid)"
            fi
        fi

        rm -f "$FLOWEAVE_PID_FILE"
    fi

    pkill -f "x11vnc.*Floweave" 2>/dev/null

    return 0
}

get_vnc_status() {
    if is_running; then
        local pid
        pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)
        local port="${CONFIG[vnc_port]}"
        local ip_addr
        ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "$ip_addr" ]] && ip_addr="<your-ip-address>"

        echo -e "Status: ${GREEN}RUNNING${RESET}"
        echo "PID: $pid"
        echo "Port: $port"
        echo -e "Connection: ${CYAN}${ip_addr}:${port}${RESET}"

        return 0
    else
        echo -e "Status: ${RED}STOPPED${RESET}"
        return 1
    fi
}
