#!/bin/bash
################################################################################
# Floweave - System Checker Module
#
# Functions:
#   - check_display_server()
#   - get_display_info()
#   - validate_network()
#   - get_system_info()
#   - check_permissions()
################################################################################

# Source UI helpers for message functions (if not already loaded)
if ! command -v show_info &> /dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/ui-helpers.sh"
fi

# check_display_server()
check_display_server() {
    show_info "Checking display server..."

    # Method 1: Check XDG_SESSION_TYPE environment variable
    if [[ -n "${XDG_SESSION_TYPE}" ]]; then
        if [[ "${XDG_SESSION_TYPE}" == "x11" ]]; then
            show_success "Display server: Xorg (X11) - Compatible ✓"
            return 0
        elif [[ "${XDG_SESSION_TYPE}" == "wayland" ]]; then
            show_error "Display server: Wayland - NOT COMPATIBLE ✗"
            show_warning "Floweave requires Xorg (X11). Please switch to an X11 session."
            show_info "To switch: Log out, click the gear icon at login, and select 'X11' or 'Xorg' session"
            return 1
        fi
    fi

    # Method 2: Check WAYLAND_DISPLAY environment variable
    if [[ -n "${WAYLAND_DISPLAY}" ]]; then
        show_error "Display server: Wayland - NOT COMPATIBLE ✗"
        show_warning "Floweave requires Xorg (X11). Please switch to an X11 session."
        return 1
    fi

    # Method 3: Check if DISPLAY is set and xrandr works (indicates X11)
    if [[ -n "${DISPLAY}" ]]; then
        if command -v xrandr &> /dev/null && xrandr &> /dev/null; then
            show_success "Display server: Xorg (X11) - Compatible ✓"
            return 0
        fi
    fi

    # Method 4: Check loginctl session type
    if command -v loginctl &> /dev/null; then
        local session_type=$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type --value 2>/dev/null)
        if [[ "${session_type}" == "x11" ]]; then
            show_success "Display server: Xorg (X11) - Compatible ✓"
            return 0
        elif [[ "${session_type}" == "wayland" ]]; then
            show_error "Display server: Wayland - NOT COMPATIBLE ✗"
            show_warning "Floweave requires Xorg (X11). Please switch to an X11 session."
            return 1
        fi
    fi

    # Fallback: Unable to determine display server
    show_warning "Unable to determine display server type"
    show_info "Attempting to verify X11 compatibility..."

    if command -v xrandr &> /dev/null && xrandr &> /dev/null; then
        show_success "xrandr is working - Assuming Xorg (X11) ✓"
        return 0
    else
        show_error "Cannot verify X11 compatibility"
        show_warning "Floweave requires Xorg (X11) to function properly"
        return 1
    fi
}

# get_display_info()
get_display_info() {
    show_info "Gathering display information..."

    if ! command -v xrandr &> /dev/null; then
        show_error "xrandr is not installed"
        return 1
    fi

    echo ""

    # Get primary display
    local primary_display=$(xrandr | grep " connected primary" | awk '{print $1}')

    if [[ -n "${primary_display}" ]]; then
        show_success "Primary display: ${primary_display}"

        # Get current resolution and refresh rate
        local current_mode=$(xrandr | grep "${primary_display}" -A 1 | grep "\*" | awk '{print $1, $2}')
        if [[ -n "${current_mode}" ]]; then
            show_info "Current mode: ${current_mode}"
        fi
    else
        show_warning "No primary display detected"
        # Try to get first connected display
        primary_display=$(xrandr | grep " connected" | head -1 | awk '{print $1}')
        if [[ -n "${primary_display}" ]]; then
            show_info "First connected display: ${primary_display}"
        fi
    fi

    echo ""
    show_info "Connected displays:"
    xrandr | grep " connected" | while read -r line; do
        local display_name=$(echo "${line}" | awk '{print $1}')
        local display_info=$(echo "${line}" | grep -o "[0-9]*x[0-9]*+[0-9]*+[0-9]*" | head -1)
        if [[ -n "${display_info}" ]]; then
            echo "  ${ARROW_RIGHT} ${display_name}: ${line#*connected }"
        else
            echo "  ${ARROW_RIGHT} ${display_name}: connected (no active mode)"
        fi
    done

    echo ""

    return 0
}

# validate_network()
validate_network() {
    show_info "Validating network connectivity..."

    echo ""

    # Check if any network interface is up
    local active_interfaces=$(ip link show | grep "state UP" | awk -F: '{print $2}' | tr -d ' ')

    if [[ -z "${active_interfaces}" ]]; then
        show_error "No active network interfaces found"
        show_warning "Network connection is required for VNC access"
        return 1
    fi

    show_success "Active network interfaces:"

    # Get IP addresses for each active interface
    while IFS= read -r interface; do
        local ip_addr=$(ip addr show "${interface}" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        if [[ -n "${ip_addr}" ]]; then
            echo "  ${ARROW_RIGHT} ${interface}: ${ip_addr}"
        fi
    done <<< "${active_interfaces}"

    echo ""

    # Test local network stack
    if ping -c 1 -W 1 127.0.0.1 &> /dev/null; then
        show_success "Local network stack: Working ✓"
    else
        show_warning "Local network stack test failed"
    fi

    echo ""
    show_info "Network validation complete"

    return 0
}

# get_system_info()
get_system_info() {
    show_info "Gathering system information..."

    echo ""

    # OS Information
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        show_info "Operating System: ${NAME} ${VERSION_ID} (${VERSION_CODENAME:-N/A})"
    fi

    # Kernel version
    local kernel=$(uname -r)
    show_info "Kernel: ${kernel}"

    # Architecture
    local arch=$(uname -m)
    show_info "Architecture: ${arch}"

    # Desktop Environment
    if [[ -n "${XDG_CURRENT_DESKTOP}" ]]; then
        show_info "Desktop Environment: ${XDG_CURRENT_DESKTOP}"
    fi

    # Display Server
    if [[ -n "${XDG_SESSION_TYPE}" ]]; then
        show_info "Session Type: ${XDG_SESSION_TYPE}"
    fi

    # Hostname
    local hostname=$(hostname)
    show_info "Hostname: ${hostname}"

    # Current user
    local current_user=$(whoami)
    show_info "User: ${current_user}"

    # System uptime
    if command -v uptime &> /dev/null; then
        local uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
        show_info "Uptime: ${uptime_info}"
    fi

    echo ""

    return 0
}

# check_permissions()
check_permissions() {
    show_info "Checking user permissions..."

    echo ""

    local permission_issues=0

    # Check X11 display access
    if command -v xrandr &> /dev/null && xrandr &> /dev/null; then
        show_success "X11 display access: OK ✓"
    else
        show_error "X11 display access: DENIED ✗"
        show_warning "Cannot access X11 display. Check DISPLAY variable and xhost permissions."
        permission_issues=$((permission_issues + 1))
    fi

    # Check home directory write access
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

