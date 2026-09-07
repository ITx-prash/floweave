#!/bin/bash

[[ -n "${_FLOWEAVE_DISPLAY_BACKEND_LOADED}" ]] && return 0
_FLOWEAVE_DISPLAY_BACKEND_LOADED=1

if ! command -v show_info &> /dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/ui-helpers.sh"
fi

export FLOWEAVE_BACKEND=""

detect_display_backend() {
    local session_type="${XDG_SESSION_TYPE}"

    if [[ -z "${session_type}" ]] && command -v loginctl &> /dev/null; then
        local session_id
        session_id=$(loginctl --no-legend 2>/dev/null | awk -v u="$(whoami)" '$3 == u {print $1; exit}')
        if [[ -n "${session_id}" ]]; then
            session_type=$(loginctl show-session "${session_id}" -p Type --value 2>/dev/null)
        fi
    fi

    if [[ -z "${session_type}" ]]; then
        if [[ -n "${WAYLAND_DISPLAY}" ]]; then
            session_type="wayland"
        elif [[ -n "${DISPLAY}" ]]; then
            session_type="x11"
        fi
    fi

    case "${session_type}" in
        x11)
            FLOWEAVE_BACKEND="x11"
            ;;
        wayland)
            local desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
            if [[ "${desktop,,}" =~ gnome ]]; then
                FLOWEAVE_BACKEND="gnome-wayland"
            else
                FLOWEAVE_BACKEND="unsupported"
            fi
            ;;
        *)
            FLOWEAVE_BACKEND="unsupported"
            ;;
    esac

    export FLOWEAVE_BACKEND
    return 0
}

get_backend_name() {
    case "${FLOWEAVE_BACKEND}" in
        x11)
            echo "Xorg (X11)"
            ;;
        gnome-wayland)
            echo "GNOME on Wayland"
            ;;
        unsupported)
            echo "Unsupported"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}
