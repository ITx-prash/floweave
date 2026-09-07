#!/bin/bash

[[ -n "${FLOWEAVE_WAYLAND_DISPLAY_MANAGER_LOADED}" ]] && return
FLOWEAVE_WAYLAND_DISPLAY_MANAGER_LOADED=1

FLOWEAVE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FLOWEAVE_MODULE_DIR/ui-helpers.sh"
source "$FLOWEAVE_MODULE_DIR/config-manager.sh"

get_primary_display_wayland() {
    local primary_display=""
    local primary_resolution=""
    local primary_width=""
    local primary_height=""

    local dbus_output
    dbus_output=$(gdbus call --session \
        --dest org.gnome.Mutter.DisplayConfig \
        --object-path /org/gnome/Mutter/DisplayConfig \
        --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null)

    if [[ -z "$dbus_output" ]]; then
        show_error "No connected display found (gdbus call failed)"
        return 1
    fi

    primary_display=$(echo "$dbus_output" | grep -oP '\(\(\x27\K[^\x27]+' | head -1)

    if [[ -z "$primary_display" ]]; then
        show_error "No connected display found"
        return 1
    fi

    primary_resolution=$(echo "$dbus_output" \
        | grep -oP '\d+, \d+,.*?is-current' \
        | head -1 \
        | grep -oP '^\d+, \d+' \
        | head -1)

    if [[ -z "$primary_resolution" ]]; then
        primary_resolution=$(echo "$dbus_output" | grep -oP "\x27[0-9]+x[0-9]+(?=@[^\x27]*\x27[^\)]*is-current)" | tr -d "'" | head -1)
        if [[ -n "$primary_resolution" ]]; then
            primary_width=$(echo "$primary_resolution" | cut -d'x' -f1)
            primary_height=$(echo "$primary_resolution" | cut -d'x' -f2)
        fi
    else
        primary_width=$(echo "$primary_resolution" | cut -d',' -f1 | tr -d ' ')
        primary_height=$(echo "$primary_resolution" | cut -d',' -f2 | tr -d ' ')
    fi

    if [[ -z "$primary_width" || -z "$primary_height" ]]; then
        show_error "Could not determine resolution for $primary_display"
        return 1
    fi

    export PRIMARY_DISPLAY="$primary_display"
    export PRIMARY_WIDTH="$primary_width"
    export PRIMARY_HEIGHT="$primary_height"
    export PRIMARY_RESOLUTION="${primary_width}x${primary_height}"

    return 0
}

create_virtual_display_wayland() {
    local width="${CONFIG[display_width]}"
    local height="${CONFIG[display_height]}"
    local position="${CONFIG[display_position]}"

    show_info "Creating virtual display: ${width}x${height} (${position})"

    if ! get_primary_display_wayland; then
        return 1
    fi

    # Extend mode prompts Mutter to create a virtual monitor when a client connects
    if ! gsettings set org.gnome.desktop.remote-desktop.vnc screen-share-mode 'extend' 2>/dev/null; then
        show_error "Failed to set VNC screen-share-mode to extend"
        return 1
    fi

    mkdir -p "$(dirname "$FLOWEAVE_DISPLAY_FILE")"
    echo "wayland-extend" > "$FLOWEAVE_DISPLAY_FILE"

    show_success "Virtual display enabled (Wayland extend mode)"
    return 0
}

remove_virtual_display_wayland() {
    show_info "Removing virtual display (Wayland)"

    gsettings set org.gnome.desktop.remote-desktop.vnc screen-share-mode 'mirror-primary' 2>/dev/null
    rm -f "$FLOWEAVE_DISPLAY_FILE"

    show_success "Virtual display removed"
    return 0
}
