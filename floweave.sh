#!/bin/bash
################################################################################
# Floweave - Main CLI Entry Point
#
# Transform your Android device into an extended display for Linux
# using VNC over WiFi (no USB/ADB required)
#
# Functions:
#   - prompt_configuration()
#   - menu_start_floweave()
#   - menu_stop_floweave()
#   - menu_configure_settings()
#   - menu_help()
#   - cleanup()
#   - main()
################################################################################

# Script metadata
# Read version from VERSION file if it exists, otherwise default
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ -L "$SCRIPT_PATH" ]]; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    FLOWEAVE_VERSION=$(cat "$SCRIPT_DIR/VERSION")
else
    FLOWEAVE_VERSION="1.0.0"
fi

# Source all modules
MODULES=(
    "modules/ui-helpers.sh"
    "modules/system-checker.sh"
    "modules/dependency-installer.sh"
    "modules/config-manager.sh"
    "modules/display-manager.sh"
    "modules/vnc-server.sh"
)

for module in "${MODULES[@]}"; do
    module_path="${SCRIPT_DIR}/${module}"
    if [[ -f "$module_path" ]]; then
        source "$module_path"
    else
        echo "ERROR: Required module not found: $module" >&2
        exit 1
    fi
done

# Global CONFIG associative array
declare -A CONFIG

# cleanup()
cleanup() {
    # NOTE: This function ONLY exits the program - it does NOT stop the VNC server
    # VNC server runs as a background daemon and persist after program exit
    echo ""
    show_info "Exiting Floweave..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# prompt_configuration()
prompt_configuration() {
    show_box "CONFIGURATION"
    echo ""

    # Display Resolution
    echo -e "  ${BLUE}${BOLD}Display Resolution${RESET}"
    echo -ne "  ${ARROW_RIGHT} Width [default: 1280]: "
    read -r width
    width="${width:-1280}"

    echo -ne "  ${ARROW_RIGHT} Height [default: 720]: "
    read -r height
    height="${height:-720}"

    CONFIG[display_width]="$width"
    CONFIG[display_height]="$height"
    echo -e "${DIM}───────────────────────────────────────────────────${RESET}"
    echo ""

    # Display Position
    echo -e "  ${BLUE}${BOLD}Display Position${RESET}"
    echo "  Position relative to primary monitor: (r)ight, (l)eft, (t)op, (b)ottom"
    echo -ne "  ${ARROW_RIGHT} Direction [default: r]: "
    read -r position
    position="${position:-r}"

    # Convert single letter to full word
    case "$position" in
        r|R) CONFIG[display_position]="right" ;;
        l|L) CONFIG[display_position]="left" ;;
        t|T) CONFIG[display_position]="above" ;;
        b|B) CONFIG[display_position]="below" ;;
        right|left|above|below) CONFIG[display_position]="$position" ;;
        *) CONFIG[display_position]="right" ;;
    esac
    echo -e "${DIM}───────────────────────────────────────────────────${RESET}"
    echo ""

    # Security
    echo -e "  ${BLUE}${BOLD}Security${RESET}"
    echo -ne "  ${ARROW_RIGHT} VNC Port [default: 5900]: "
    read -r port
    port="${port:-5900}"
    CONFIG[vnc_port]="$port"

    echo -ne "  ${ARROW_RIGHT} VNC Password (leave empty for none): "
    read -r vnc_pass
    CONFIG[vnc_password]="$vnc_pass"

    # Monitor name (auto-detect)
    CONFIG[display_monitor]=""

    # System metadata
    CONFIG[system_version]="$FLOWEAVE_VERSION"
    CONFIG[system_last_updated]=$(date +"%Y-%m-%d %H:%M:%S")

    echo ""

    # Validate configuration
    if ! validate_config; then
        show_error "  Configuration validation failed"
        return 1
    fi

    # Save configuration
    if ! save_config; then
        show_error "  Failed to save configuration"
        return 1
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}${CHECK_MARK} Configuration saved successfully.${RESET}" 
    echo ""

    return 0
}

# menu_start_floweave()
menu_start_floweave() {
    clear
    show_box "START FLOWEAVE"
    echo ""

 # Check if already running
    if is_running; then
        show_warning "Service is already active."
        echo ""
        echo -e "  To stop the service, select ${BOLD}'Stop Floweave'${RESET} from the main menu."
        echo ""
        return 0
    fi


    # STEP 1: Verify system requirements (combined check)
    show_loading "Verifying system requirements" 1

        # Check display server silently
     if ! check_display_server &>/dev/null; then
        echo ""
        echo -e "  ${RED}${BOLD}× CRITICAL: Xorg Display Server Required${RESET}"
        echo -e "${DIM}  ──────────────────────────────────────────────────${RESET}"
        echo -e "  Floweave requires an ${BOLD}Xorg (X11)${RESET} session."
        echo -e "  Your system is currently running Wayland."
        echo ""
        echo -e "  ${CYAN}Please switch to an Xorg session to continue.${RESET}"
        echo -e "  ${DIM}Refer to the 'Help & Usage Guide' for more information.${RESET}"
        echo ""
        return 1
    fi

    # Check dependencies silently
    check_dependencies_silent

    # Handle missing dependencies
    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        echo ""
        show_warning "Missing dependencies detected"
        echo ""
        echo "  The following packages are required:"
        for pkg in "${MISSING_DEPS[@]}"; do
            echo -e "  ${BOLD}${ARROW_RIGHT} ${MAGENTA}${BOLD}${pkg}${RESET}"
        done
        echo ""

        if prompt_yes_no "Would you like to install them now?"; then
            echo ""

            # Detect distribution if not already done
            if [[ -z "${PKG_MANAGER}" ]]; then
                detect_distro >/dev/null 2>&1 || {
                    show_error "Could not detect package manager"
                    show_info "Please install dependencies manually and try again"
                    return 1
                }
            fi

            # Install dependencies
            if ! install_dependencies; then
                show_error "Dependency installation failed"
                show_info "Please install dependencies manually and try again"
                return 1
            fi

            echo ""
           
            echo -e "  ${GREEN}${BOLD}${CHECK_MARK} Dependencies installed successfully${RESET}" 

            echo ""
        else
            show_error "Cannot start without required dependencies"
            return 1
        fi
    fi

    # STEP 3: Check configuration
    if ! is_configured; then
        # First-time setup: prompt for configuration
        echo ""
        if ! prompt_configuration; then
            show_error "Configuration failed"
            return 1
        fi
    else
        # Load existing configuration
        load_config
    fi

    # STEP 4: Initialize system
    local width="${CONFIG[display_width]}"
    local height="${CONFIG[display_height]}"
    local position="${CONFIG[display_position]}"
    local port="${CONFIG[vnc_port]}"

    show_success "System initialization complete"

    # Create virtual display
    local display_output
    if ! display_output=$(create_virtual_display 2>&1); then
        echo "$display_output"
        show_error "Failed to create virtual display"
        return 1
    fi
    show_success "Virtual display created (${width}x${height})"

    # Start VNC server
    local vnc_output
    if ! vnc_output=$(start_vnc_server 2>&1); then
        echo "$vnc_output"
        show_error "Failed to start VNC server"
        show_warning "Cleaning up virtual display..."
        remove_virtual_display &>/dev/null
        return 1
    fi
    show_success "VNC server running"
    echo ""

    # Display connection details in a box
    local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "$ip_addr" ]]; then
        ip_addr="<your-ip-address>"
    fi

    show_box "CONNECTION DETAILS"
    echo -e "  ${ARROW_RIGHT} IP Address: ${CYAN}${BOLD}${ip_addr}${RESET}"
    echo -e "  ${ARROW_RIGHT} Port: ${CYAN}${BOLD}${port}${RESET}"
    echo -e "  ${ARROW_RIGHT} Resolution: ${CYAN}${BOLD}${width}x${height}${RESET}"
    show_separator
    echo ""

    return 0
}

# menu_stop_floweave()
menu_stop_floweave() {
    clear
    show_box "STOP FLOWEAVE"
    echo ""

    # Check if running
    if ! is_running; then
        show_warning "Service is already stopped. No action taken."
        return 0
    fi

    # Load configuration
    load_config

    # Stop VNC server with loading animation
    show_loading "Stopping VNC server" 1
    stop_vnc_server &>/dev/null

    # Remove virtual display with loading animation
    show_loading "Removing virtual display" 1
    remove_virtual_display &>/dev/null

    show_success "Floweave stopped successfully"

    return 0
}

# menu_configure_settings()
menu_configure_settings() {
    clear
    show_box "CONFIGURE SETTINGS"
    echo ""

    # Load current configuration
    load_config

    # 1. Display Current Settings
    echo -e "  ${GREEN}${BOLD}CURRENT CONFIGURATION${RESET}"
    echo -e "${DIM}  ──────────────────────────────────────────────────${RESET}"
    printf "  %-18s ${BOLD}%s${RESET}\n" "Resolution:" "${CONFIG[display_width]}x${CONFIG[display_height]}"
    printf "  %-18s ${BOLD}%s${RESET}\n" "Position:" "${CONFIG[display_position]}"
    printf "  %-18s ${BOLD}%s${RESET}\n" "VNC Port:" "${CONFIG[vnc_port]}"
    
    local pass_status="[not set]"
    [[ -n "${CONFIG[vnc_password]}" ]] && pass_status="[configured]"
    printf "  %-18s ${BOLD}%s${RESET}\n" "VNC Password:" "$pass_status"
    echo -e "${DIM}  ──────────────────────────────────────────────────${RESET}"
    echo ""

    echo -e "  ${GREEN}${BOLD}Enter new values below (press Enter to keep current)${RESET}"
    echo ""

    # 2. Edit Form
    # Display Resolution
    echo -e "  ${BLUE}${BOLD}Display Resolution${RESET}"
    echo -ne "  ${ARROW_RIGHT} Width  [${CONFIG[display_width]}]: "
    read -r width
    width="${width:-${CONFIG[display_width]}}"

    echo -ne "  ${ARROW_RIGHT} Height [${CONFIG[display_height]}]: "
    read -r height
    height="${height:-${CONFIG[display_height]}}"

    CONFIG[display_width]="$width"
    CONFIG[display_height]="$height"
    echo ""

    # Display Position
    echo -e "  ${BLUE}${BOLD}Display Position${RESET}"
    echo -e "  ${DIM}(Options: right(r), left(l), top(t), bottom(b))${RESET}"
    echo -ne "  ${ARROW_RIGHT} Direction [r]: "
    read -r position
    position="${position:-${CONFIG[display_position]}}"

    # Convert single letter to full word
    case "$position" in
        r|R) CONFIG[display_position]="right" ;;
        l|L) CONFIG[display_position]="left" ;;
        t|T) CONFIG[display_position]="above" ;;
        b|B) CONFIG[display_position]="below" ;;
        right|left|above|below) CONFIG[display_position]="$position" ;;
        *) ;; # Keep current if invalid
    esac
    echo ""

    # Security
    echo -e "  ${BLUE}${BOLD}Security${RESET}"
    echo -ne "  ${ARROW_RIGHT} VNC Port [${CONFIG[vnc_port]}]: "
    read -r port
    port="${port:-${CONFIG[vnc_port]}}"
    CONFIG[vnc_port]="$port"

    echo -ne "  ${ARROW_RIGHT} VNC Password (type 'none' to remove): "
    read -r new_password
    if [[ "$new_password" == "none" ]]; then
        CONFIG[vnc_password]=""
    elif [[ -n "$new_password" ]]; then
        CONFIG[vnc_password]="$new_password"
    fi

    # Update timestamp
    CONFIG[system_last_updated]=$(date +"%Y-%m-%d %H:%M:%S")

    echo ""

    # Validate configuration
    if ! validate_config; then
        echo ""
        show_warning "Configuration not saved - please try again with valid values"
        return 1
    fi

    # Save configuration
    if ! save_config; then
        show_error "Failed to save configuration"
        return 1
    fi

    echo -e "  ${GREEN}${BOLD}${CHECK_MARK} Configuration updated successfully${RESET}"

    # Warn if running
    if is_running; then
        echo ""
        echo -e "  ${YELLOW}⚠ Note: Restart Floweave for changes to take effect${RESET}"
    fi

    return 0
}
# menu_help()
menu_help() {
    clear
    show_box "FLOWEAVE HELP & USAGE GUIDE"
    echo ""

    # What is Floweave
    echo -e "${GREEN}${BOLD}${ARROW_RIGHT} WHAT IS FLOWEAVE?${RESET}"
    echo "  Floweave is a Linux CLI tool that creates a virtual Xorg display and streams"
    echo "  it over VNC, allowing any device with a VNC viewer—Android, iOS, Windows,"
    echo "  macOS, or another computer—to act as an extended monitor. It uses xrandr and"
    echo "  x11vnc, requires an Xorg session (not Wayland), and enables wireless screen"
    echo "  extension without USB or ADB."
    echo ""

    # Requirements
    echo -e "${GREEN}${BOLD}${ARROW_RIGHT} REQUIREMENTS:${RESET}"
    echo "  • Xorg display server (not Wayland)"
    echo "  • xrandr, x11vnc installed"
    echo "  • Any device with a VNC viewer app (Android, iOS, Windows, macOS, Linux, etc.)"
    echo "  • Both devices on same WiFi network"
    echo ""

    # Installation
    echo -e "${GREEN}${BOLD}${ARROW_RIGHT} INSTALLATION:${RESET}"
    echo "  To install Floweave permanently and enable the 'floweave' command:"
    echo -e "  Run: ${BOLD}./install.sh${RESET} from the source directory."
    echo ""

    # Quick Start
    echo -e "${GREEN}${BOLD}${ARROW_RIGHT} QUICK START:${RESET}"
    echo "  1. Run 'Start Floweave' to configure and start the VNC server"
    echo "  2. Connect using your device's VNC viewer to the IP address and port displayed"
    echo "  3. Use 'Stop Floweave' when done to clean up the virtual display"
    echo ""

    # CLI Usage
    echo -e "${GREEN}${BOLD}${ARROW_RIGHT} CLI USAGE:${RESET}"
    echo "  After installation, Floweave is available as a CLI command:"
    echo ""
    echo -e "  ${BOLD}floweave${RESET}           Launch interactive menu (default)"
    echo -e "  ${BOLD}floweave --start${RESET}   Start Floweave directly"
    echo -e "  ${BOLD}floweave --stop${RESET}    Stop Floweave directly"
    echo -e "  ${BOLD}floweave --config${RESET}  Open configuration editor"
    echo -e "  ${BOLD}floweave --help${RESET}    Show this help message"
    echo -e "  ${BOLD}floweave --version${RESET} Show version information"
    echo ""

     # Troubleshooting
    echo -e "${GREEN}${BOLD}${ARROW_RIGHT} TROUBLESHOOTING:${RESET}"
    echo "  • Connection refused: Check firewall, verify same WiFi network"
    echo "  • Display not appearing: Verify Xorg (not Wayland), check xrandr output"
    echo "  • Performance issues: Reduce resolution, check network bandwidth"
    echo "  • Wayland detected: Log out and select 'Xorg' or 'X11' session at login,"
    echo "    or consult online documentation for your specific Linux distribution."

    return 0
}

# main()
main() {
    # Parse command-line arguments
    case "${1:-}" in
        --start|start)
            menu_start_floweave
            exit $?
            ;;
        --stop|stop)
            menu_stop_floweave
            exit $?
            ;;
        --config|config)
            menu_configure_settings
            press_any_key
            exit 0
            ;;
        --help|-h|help)
            show_header
            menu_help
            exit 0
            ;;
        --version|-v)
            echo "Floweave version $FLOWEAVE_VERSION"
            exit 0
            ;;
        "")
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac

    # Main menu loop
    while true; do
        clear
        show_header
        show_menu

        # Get user selection
        echo -ne "  ${CYAN}${BOLD}${ARROW_RIGHT}${RESET} Select an option (1-5): "
        read -r choice
        
        case "$choice" in
            1)
                menu_start_floweave
                press_any_key
                ;;
            2)
                menu_stop_floweave
                press_any_key
                ;;
            3)
                menu_configure_settings
                press_any_key
                ;;
            4)
                menu_help
                press_any_key
                ;;
            5)
                cleanup
                ;;
            *)
                show_error "Invalid option: $choice"
                show_warning "Please select a number between 1 and 5"
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"