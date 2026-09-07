#!/bin/bash

if ! command -v show_info &> /dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/ui-helpers.sh"
fi

check_display_server() {
    show_info "Checking display server..."

    local module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$module_dir/display-backend.sh"
    detect_display_backend

    case "$FLOWEAVE_BACKEND" in
        x11)
            show_success "Display server: Xorg (X11) - Compatible ✓"
            return 0
            ;;
        gnome-wayland)
            show_success "Display server: Wayland (GNOME) - Compatible ✓"
            return 0
            ;;
        unsupported)
            local desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
            show_error "Unsupported display configuration"
            if [[ "${XDG_SESSION_TYPE}" == "wayland" || -n "${WAYLAND_DISPLAY}" ]]; then
                show_warning "Wayland compositor '$desktop' is not supported."
                show_info "Wayland support is currently limited to GNOME (Mutter)."
                show_info "KDE Plasma, Hyprland, and other compositors are not supported."
                show_info "Switch to a GNOME Wayland session or an Xorg (X11) session to use Floweave."
            else
                show_warning "Could not detect a compatible display server."
                show_info "Floweave supports Xorg (X11) and GNOME Wayland."
            fi
            return 1
            ;;
    esac
}

get_display_info() {
    show_info "Gathering display information..."

    local module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$module_dir/display-backend.sh"
    detect_display_backend

    if [[ "$FLOWEAVE_BACKEND" == "gnome-wayland" ]]; then
        source "$module_dir/wayland-display-manager.sh"
        if get_primary_display_wayland; then
            echo ""
            show_success "Primary display: ${PRIMARY_DISPLAY}"
            show_info "Current mode: ${PRIMARY_RESOLUTION}"
            return 0
        else
            show_warning "No active display detected via Mutter"
            return 1
        fi
    fi

    if ! command -v xrandr &> /dev/null; then
        show_error "xrandr is not installed"
        return 1
    fi

    echo ""

    local primary_display
    primary_display=$(xrandr | grep " connected primary" | awk '{print $1}')

    if [[ -n "${primary_display}" ]]; then
        show_success "Primary display: ${primary_display}"

        local current_mode
        current_mode=$(xrandr | grep "${primary_display}" -A 1 | grep "\*" | awk '{print $1, $2}')
        if [[ -n "${current_mode}" ]]; then
            show_info "Current mode: ${current_mode}"
        fi
    else
        show_warning "No primary display detected"
        primary_display=$(xrandr | grep " connected" | head -1 | awk '{print $1}')
        if [[ -n "${primary_display}" ]]; then
            show_info "First connected display: ${primary_display}"
        fi
    fi

    echo ""
    show_info "Connected displays:"
    xrandr | grep " connected" | while read -r line; do
        local display_name
        display_name=$(echo "${line}" | awk '{print $1}')
        local display_info
        display_info=$(echo "${line}" | grep -o "[0-9]*x[0-9]*+[0-9]*+[0-9]*" | head -1)
        if [[ -n "${display_info}" ]]; then
            echo "  ${ARROW_RIGHT} ${display_name}: ${line#*connected }"
        else
            echo "  ${ARROW_RIGHT} ${display_name}: connected (no active mode)"
        fi
    done

    echo ""
    return 0
}

validate_network() {
    show_info "Validating network connectivity..."
    echo ""

    local active_interfaces
    active_interfaces=$(ip link show | grep "state UP" | awk -F: '{print $2}' | tr -d ' ')

    if [[ -z "${active_interfaces}" ]]; then
        show_error "No active network interfaces found"
        show_warning "Network connection is required for VNC access"
        return 1
    fi

    show_success "Active network interfaces:"

    while IFS= read -r interface; do
        local ip_addr
        ip_addr=$(ip addr show "${interface}" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        if [[ -n "${ip_addr}" ]]; then
            echo "  ${ARROW_RIGHT} ${interface}: ${ip_addr}"
        fi
    done <<< "${active_interfaces}"

    echo ""

    if ping -c 1 -W 1 127.0.0.1 &> /dev/null; then
        show_success "Local network stack: Working ✓"
    else
        show_warning "Local network stack test failed"
    fi

    echo ""
    show_info "Network validation complete"
    return 0
}

get_system_info() {
    show_info "Gathering system information..."
    echo ""

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        show_info "Operating System: ${NAME} ${VERSION_ID} (${VERSION_CODENAME:-N/A})"
    fi

    local kernel
    kernel=$(uname -r)
    show_info "Kernel: ${kernel}"

    local arch
    arch=$(uname -m)
    show_info "Architecture: ${arch}"

    if [[ -n "${XDG_CURRENT_DESKTOP}" ]]; then
        show_info "Desktop Environment: ${XDG_CURRENT_DESKTOP}"
    fi

    if [[ -n "${XDG_SESSION_TYPE}" ]]; then
        show_info "Session Type: ${XDG_SESSION_TYPE}"
    fi

    local hostname
    hostname=$(hostname)
    show_info "Hostname: ${hostname}"

    local current_user
    current_user=$(whoami)
    show_info "User: ${current_user}"

    if command -v uptime &> /dev/null; then
        local uptime_info
        uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
        show_info "Uptime: ${uptime_info}"
    fi

    echo ""
    return 0
}

check_permissions() {
    show_info "Checking user permissions..."
    echo ""

    local permission_issues=0

    local module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$module_dir/display-backend.sh"
    detect_display_backend

    if [[ "$FLOWEAVE_BACKEND" == "gnome-wayland" ]]; then
        if gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState &> /dev/null; then
            show_success "Wayland session display access: OK ✓"
        else
            show_error "Wayland session display access: DENIED ✗"
            show_warning "Cannot query Mutter DisplayConfig via D-Bus."
            permission_issues=$((permission_issues + 1))
        fi
    else
        if command -v xrandr &> /dev/null && xrandr &> /dev/null; then
            show_success "X11 display access: OK ✓"
        else
            show_error "X11 display access: DENIED ✗"
            show_warning "Cannot access X11 display. Check DISPLAY variable and xhost permissions."
            permission_issues=$((permission_issues + 1))
        fi
    fi

    if [[ -w "${HOME}" ]]; then
        show_success "Home directory write access: OK ✓"
    else
        show_error "Home directory write access: DENIED ✗"
        show_warning "Cannot write to home directory: ${HOME}"
        permission_issues=$((permission_issues + 1))
    fi

    echo ""

    if [[ ${permission_issues} -eq 0 ]]; then
        show_success "All permission checks passed ✓"
        return 0
    else
        show_error "Permission issues detected (${permission_issues} critical)"
        return 1
    fi
}

