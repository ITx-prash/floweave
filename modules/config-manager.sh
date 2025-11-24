#!/bin/bash
################################################################################
# Floweave - Configuration Manager Module
#
# Functions:
#   - read_ini_value()
#   - write_ini_value()
#   - is_configured()
#   - is_running()
#   - load_config()
#   - save_config()
#   - validate_config()
################################################################################

# Configuration paths (use environment variables if set, otherwise use defaults)
FLOWEAVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOWEAVE_CONFIG_DIR="${FLOWEAVE_CONFIG_DIR:-${HOME}/.config/floweave}"
FLOWEAVE_CONFIG_FILE="${FLOWEAVE_CONFIG_FILE:-${FLOWEAVE_CONFIG_DIR}/config.ini}"
FLOWEAVE_PID_FILE="${FLOWEAVE_PID_FILE:-${FLOWEAVE_CONFIG_DIR}/floweave.pid}"
FLOWEAVE_DISPLAY_FILE="${FLOWEAVE_DISPLAY_FILE:-${FLOWEAVE_CONFIG_DIR}/display.name}"
FLOWEAVE_DEFAULT_CONF="${FLOWEAVE_DIR}/config/default.conf"

# Global configuration variables
declare -A CONFIG

# read_ini_value()
read_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default="${4:-}"

    if [[ ! -f "$file" ]]; then
        echo "$default"
        return 1
    fi

    local in_section=0
    local value=""

    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Check for section header
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            local current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=1
            else
                in_section=0
            fi
            continue
        fi

        # If in the target section, look for the key
        if [[ $in_section -eq 1 && "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local current_key="${BASH_REMATCH[1]}"
            local current_value="${BASH_REMATCH[2]}"

            # Remove whitespace from key
            current_key=$(echo "$current_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$current_key" == "$key" ]]; then
                value="$current_value"
                break
            fi
        fi
    done < "$file"

    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    else
        echo "$default"
        return 1
    fi
}

# write_ini_value()
write_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$file")"

    # If file doesn't exist, create it with the section and key
    if [[ ! -f "$file" ]]; then
        echo "[$section]" > "$file"
        echo "$key=$value" >> "$file"
        return 0
    fi

    local temp_file="${file}.tmp"
    local in_section=0
    local key_found=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for section header
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            local current_section="${BASH_REMATCH[1]}"

            # If we were in the target section but didn't find the key, add it
            if [[ $in_section -eq 1 && $key_found -eq 0 ]]; then
                echo "$key=$value" >> "$temp_file"
                key_found=1
            fi

            if [[ "$current_section" == "$section" ]]; then
                in_section=1
            else
                in_section=0
            fi

            echo "$line" >> "$temp_file"
            continue
        fi

        # If in the target section, check if this is the key to update
        if [[ $in_section -eq 1 && "$line" =~ ^([^=]+)= ]]; then
            local current_key="${BASH_REMATCH[1]}"
            current_key=$(echo "$current_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$current_key" == "$key" ]]; then
                echo "$key=$value" >> "$temp_file"
                key_found=1
                continue
            fi
        fi

        echo "$line" >> "$temp_file"
    done < "$file"

    # If we were in the target section at EOF but didn't find the key, add it
    if [[ $in_section -eq 1 && $key_found -eq 0 ]]; then
        echo "$key=$value" >> "$temp_file"
        key_found=1
    fi

    # If section wasn't found, add it with the key
    if [[ $key_found -eq 0 ]]; then
        echo "" >> "$temp_file"
        echo "[$section]" >> "$temp_file"
        echo "$key=$value" >> "$temp_file"
    fi

    mv "$temp_file" "$file"
    return 0
}

# is_configured()
is_configured() {
    # Check if config file exists and has required values
    if [[ ! -f "$FLOWEAVE_CONFIG_FILE" ]]; then
        return 1
    fi

    # Check for required configuration values
    local width=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "width")
    local height=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "height")
    local position=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "position")

    if [[ -z "$width" || -z "$height" || -z "$position" ]]; then
        return 1
    fi

    return 0
}

# is_running()
is_running() {
    # Check if PID file exists
    if [[ ! -f "$FLOWEAVE_PID_FILE" ]]; then
        return 1
    fi

    # Read PID from file
    local pid=$(cat "$FLOWEAVE_PID_FILE" 2>/dev/null)

    # Check if PID is valid
    if [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Check if process is running
    if ps -p "$pid" > /dev/null 2>&1; then
        # Verify it's actually x11vnc
        if ps -p "$pid" -o comm= | grep -q "x11vnc"; then
            return 0
        fi
    fi

    # PID file exists but process is not running - clean up stale PID file
    rm -f "$FLOWEAVE_PID_FILE"
    return 1
}

# load_config()
load_config() {
    # Create config directory if it doesn't exist
    mkdir -p "$FLOWEAVE_CONFIG_DIR"

    # If config file doesn't exist, create it from default template
    if [[ ! -f "$FLOWEAVE_CONFIG_FILE" ]]; then
        if [[ -f "$FLOWEAVE_DEFAULT_CONF" ]]; then
            cp "$FLOWEAVE_DEFAULT_CONF" "$FLOWEAVE_CONFIG_FILE"
        else
            # Fallback: create minimal config if template is missing
            cat > "$FLOWEAVE_CONFIG_FILE" << 'EOF'
[display]
width=1280
height=720
position=right
monitor=

[vnc]
port=5900
password=

[system]
version=${FLOWEAVE_VERSION:-1.0.0}
last_updated=
EOF
        fi
    fi

    # Load configuration values into CONFIG associative array
    CONFIG[display_width]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "width" "1280")
    CONFIG[display_height]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "height" "720")
    CONFIG[display_position]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "position" "right")
    CONFIG[display_monitor]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "monitor" "")
    CONFIG[vnc_port]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "vnc" "port" "5900")
    CONFIG[vnc_password]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "vnc" "password" "")
    CONFIG[system_version]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "system" "version" "${FLOWEAVE_VERSION:-1.0.0}")
    CONFIG[system_last_updated]=$(read_ini_value "$FLOWEAVE_CONFIG_FILE" "system" "last_updated" "")

    return 0
}

# save_config()
save_config() {
    # Create config directory if it doesn't exist
    mkdir -p "$FLOWEAVE_CONFIG_DIR"

    # Update last_updated timestamp
    CONFIG[system_last_updated]=$(date '+%Y-%m-%d %H:%M:%S')

    # Write all configuration values to file
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "width" "${CONFIG[display_width]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "height" "${CONFIG[display_height]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "position" "${CONFIG[display_position]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "display" "monitor" "${CONFIG[display_monitor]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "vnc" "port" "${CONFIG[vnc_port]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "vnc" "password" "${CONFIG[vnc_password]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "system" "version" "${CONFIG[system_version]}"
    write_ini_value "$FLOWEAVE_CONFIG_FILE" "system" "last_updated" "${CONFIG[system_last_updated]}"

    return 0
}

# validate_config()
validate_config() {
    local errors=0

    # Validate display width
    if [[ ! "${CONFIG[display_width]}" =~ ^[0-9]+$ ]] || [[ ${CONFIG[display_width]} -lt 640 ]] || [[ ${CONFIG[display_width]} -gt 3840 ]]; then
        show_error "Invalid display width: ${CONFIG[display_width]} (must be 640-3840)"
        errors=$((errors + 1))
    fi

    # Validate display height
    if [[ ! "${CONFIG[display_height]}" =~ ^[0-9]+$ ]] || [[ ${CONFIG[display_height]} -lt 480 ]] || [[ ${CONFIG[display_height]} -gt 2160 ]]; then
        show_error "Invalid display height: ${CONFIG[display_height]} (must be 480-2160)"
        errors=$((errors + 1))
    fi

    # Validate display position
    if [[ ! "${CONFIG[display_position]}" =~ ^(left|right|above|below)$ ]]; then
        show_error "Invalid display position: ${CONFIG[display_position]} (must be: left, right, above, below)"
        errors=$((errors + 1))
    fi

    # Validate VNC port
    if [[ ! "${CONFIG[vnc_port]}" =~ ^[0-9]+$ ]] || [[ ${CONFIG[vnc_port]} -lt 5900 ]] || [[ ${CONFIG[vnc_port]} -gt 5999 ]]; then
        show_error "Invalid VNC port: ${CONFIG[vnc_port]} (must be 5900-5999)"
        errors=$((errors + 1))
    fi

    # Validate VNC password (optional - can be empty for passwordless VNC)
    if [[ -n "${CONFIG[vnc_password]}" ]] && [[ ${#CONFIG[vnc_password]} -gt 8 ]]; then
        # Validate VNC password length (x11vnc supports max 8 characters)
        show_warning "VNC password truncated to 8 characters (x11vnc limitation)"
        CONFIG[vnc_password]="${CONFIG[vnc_password]:0:8}"
    fi

    if [[ $errors -gt 0 ]]; then
        return 1
    fi

    return 0
}

