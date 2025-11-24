#!/bin/bash
################################################################################
# Floweave - VNC Server Module
#
# Functions:
#   - start_vnc_server()
#   - stop_vnc_server()
#   - get_vnc_status()
################################################################################

# Guard against multiple sourcing
[[ -n "${FLOWEAVE_VNC_SERVER_LOADED}" ]] && return
FLOWEAVE_VNC_SERVER_LOADED=1

# Source dependencies
FLOWEAVE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FLOWEAVE_MODULE_DIR/ui-helpers.sh"
source "$FLOWEAVE_MODULE_DIR/config-manager.sh"
source "$FLOWEAVE_MODULE_DIR/display-manager.sh"

# start_vnc_server()
start_vnc_server() {
    local port="${CONFIG[vnc_port]}"
    local password="${CONFIG[vnc_password]}"

    # Check if already running
    if is_running; then
        show_error "VNC server is already running"
        show_info "Use 'floweave stop' to stop it first"
        return 1
    fi

    # Calculate display geometry
    if ! calculate_display_geometry; then
        return 1
    fi

    show_info "Starting VNC server on port $port"
    show_info "Clip region: $CLIP_GEOMETRY"

    # Build x11vnc command (cursor flags match original linux-display-extend project)
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

    # Add password if configured
    if [[ -n "$password" ]]; then
        vnc_cmd="$vnc_cmd -passwd $password"
    else
        vnc_cmd="$vnc_cmd -nopw"
    fi

    # CRITICAL FIX: Start VNC server in a subshell with signal isolation
    # This prevents SIGINT (Ctrl+C) from propagating to the VNC process
    (
        # Create a new process group and session
        setsid bash -c "
            # Ignore SIGINT and SIGTERM in this subshell
            trap '' SIGINT SIGTERM
            
            # Start VNC server with nohup (ignores SIGHUP)
            nohup $vnc_cmd >/dev/null 2>&1 &
            
            # Get the PID and save it
            echo \$! > '$FLOWEAVE_PID_FILE'
        " >/dev/null 2>&1 &
    )

    # Wait for VNC process to fully detach and start
    sleep 2

    # Read the saved PID
    if [[ ! -f "$FLOWEAVE_PID_FILE" ]]; then
        show_error "Failed to create PID file"
        return 1
    fi

    local vnc_pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)

    # Verify VNC server started
    if [[ -z "$vnc_pid" ]] || ! ps -p "$vnc_pid" > /dev/null 2>&1; then
        show_error "VNC server failed to start"
        rm -f "$FLOWEAVE_PID_FILE"
        return 1
    fi

    # Get IP address for connection info
    local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')

    if [[ -z "$ip_addr" ]]; then
        ip_addr="<your-ip-address>"
    fi

    show_success "VNC server started (PID: $vnc_pid)"
    show_info "Connection: ${ip_addr}:${port}"

    return 0
}

# stop_vnc_server()
stop_vnc_server() {
    # show_info "Stopping VNC server"

    # Check if PID file exists
    if [[ -f "$FLOWEAVE_PID_FILE" ]]; then
        local pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)

        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
            # Check if process is running
            if ps -p "$pid" > /dev/null 2>&1; then
                # Kill the process
                kill "$pid" 2>/dev/null

                # Wait for process to terminate
                local count=0
                while ps -p "$pid" > /dev/null 2>&1 && [[ $count -lt 5 ]]; do
                    sleep 1
                    count=$((count + 1))
                done

                # Force kill if still running
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" 2>/dev/null
                fi

                show_success "VNC server stopped (PID: $pid)"
            fi
        fi

        # Remove PID file
        rm -f "$FLOWEAVE_PID_FILE"
    fi

    # Fallback: kill any x11vnc processes with "Floweave" in desktop name
    pkill -f "x11vnc.*Floweave" 2>/dev/null

    return 0
}

# get_vnc_status()
get_vnc_status() {
    if is_running; then
        local pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)
        local port="${CONFIG[vnc_port]}"
        local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')

        if [[ -z "$ip_addr" ]]; then
            ip_addr="<your-ip-address>"
        fi

        echo "Status: ${COLOR_GREEN}RUNNING${COLOR_RESET}"
        echo "PID: $pid"
        echo "Port: $port"
        echo "Connection: ${COLOR_CYAN}${ip_addr}:${port}${COLOR_RESET}"

        return 0
    else
        echo "Status: ${COLOR_RED}STOPPED${COLOR_RESET}"
        return 1
    fi
}
