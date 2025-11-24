#!/bin/bash
################################################################################
# Floweave - UI Helpers Module
#
# Functions:
#   - show_header()
#   - show_menu()
#   - prompt_input()
#   - prompt_yes_no()
#   - prompt_with_default()
#   - show_success()
#   - show_error()
#   - show_warning()
#   - show_info()
#   - show_separator()
#   - show_box()
#   - press_any_key()
#   - show_loading()
################################################################################

# Color Codes and Formatting

# Check if terminal supports colors
if [[ -t 1 ]] && command -v tput &> /dev/null && tput setaf 1 &> /dev/null; then
    # Color codes
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;34m"
    CYAN="\033[0;36m"
    MAGENTA="\033[0;35m"
    BOLD="\033[1m"
    DIM="\033[2m"
    RESET="\033[0m"
else
    # No color support
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    BOLD=""
    DIM=""
    RESET=""
fi

# Unicode symbols (with ASCII fallbacks)
if [[ "${LANG}" =~ UTF-8 ]] || [[ "${LC_ALL}" =~ UTF-8 ]]; then
    CHECK_MARK="✓"
    CROSS_MARK="✗"
    WARNING_SIGN="⚠"
    ARROW_RIGHT="→"
else
    CHECK_MARK="[OK]"
    CROSS_MARK="[X]"
    WARNING_SIGN="[!]"
    ARROW_RIGHT="->"
fi

# show_header()
show_header() {
    clear

    echo -e "${DIM}┌──────────────────────────────────────────────────────────────────────────────┐${RESET}"

    # Empty line inside box
    echo -e "${DIM}│${RESET}                                                                              ${DIM}│${RESET}"

    # ASCII art in GREEN - each line must be exactly 78 chars between borders
    # Vertically straight alignment: all lines have consistent 3-space left padding
    echo -e "${DIM}│${RESET}   ${GREEN}███████╗██╗      ██████╗ ██╗    ██╗███████╗ █████╗ ██╗   ██╗███████╗${RESET}       ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}██╔════╝██║     ██╔═══██╗██║    ██║██╔════╝██╔══██╗██║   ██║██╔════╝${RESET}       ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}█████╗  ██║     ██║   ██║██║ █╗ ██║█████╗  ███████║██║   ██║█████╗${RESET}         ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}██╔══╝  ██║     ██║   ██║██║███╗██║██╔══╝  ██╔══██║╚██╗ ██╔╝██╔══╝${RESET}         ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}██║     ███████╗╚██████╔╝╚███╔███╔╝███████╗██║  ██║ ╚████╔╝ ███████╗${RESET}       ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝${RESET}       ${DIM}│${RESET}"

  # Center-aligned description in BOLD (78 chars between borders)
    local desc="Extend Your Linux Desktop to Any Device via VNC"
    local ver="v${FLOWEAVE_VERSION:-1.0.0}"
    local full_line="${desc} ${ver}"
    local full_len=${#full_line}
    local box_width=78
    local left_pad=$(( (box_width - full_len) / 2 ))
    local right_pad=$(( box_width - full_len - left_pad ))
    
    # Print description in BOLD and version in DIM
    printf "${DIM}│${RESET}%*s${BOLD}%s${RESET} ${DIM}%s${RESET}%*s${DIM}│${RESET}\n" $left_pad "" "$desc" "$ver" $right_pad ""

    # Empty line
    echo -e "${DIM}│${RESET}                                                                              ${DIM}│${RESET}"

    # Center-aligned combined info in GREEN (Inside box)
    local info_line="Maintainer: Prash | https://github.com/ITx-prash/floweave"
    local info_len=${#info_line}
    local info_left=$(( (box_width - info_len) / 2 ))
    local info_right=$(( box_width - info_len - info_left ))
    printf "${DIM}│${RESET}%*s${GREEN}${BOLD}%s${RESET}%*s${DIM}│${RESET}\n" $info_left "" "$info_line" $info_right ""

    # Center-aligned Xorg warning in YELLOW (Inside box)
    local warning="${WARNING_SIGN} Requires Xorg (X11) - Not compatible with Wayland"
    local warning_len=${#warning}
    local warn_left=$(( (box_width - warning_len) / 2 ))
    local warn_right=$(( box_width - warning_len - warn_left ))
    printf "${DIM}│${RESET}%*s${YELLOW}%s${RESET}%*s${DIM}│${RESET}\n" $warn_left "" "$warning" $warn_right ""

    # Empty line
    echo -e "${DIM}│${RESET}                                                                              ${DIM}│${RESET}"


    # Dynamic status indicator in lower right corner
    local status_text=""
    local status_formatted=""

    if is_running 2>/dev/null; then
        # Load config to get port
        load_config 2>/dev/null
        local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -z "$ip_addr" ]]; then
            status_text="🟢 Online"
            status_formatted="🟢 ${BOLD}Online${RESET}"
        else
            local port="${CONFIG[vnc_port]:-5900}"
            # Minimalist: Dot + State + Address
            status_text="🟢 Online: ${ip_addr}:${port}"
            status_formatted="🟢 ${BOLD}Online: ${ip_addr}:${port}${RESET}"
        fi
    else
        # Minimalist: Dot + State
        status_text="🔴 Offline"
        status_formatted="🔴 ${BOLD}Offline${RESET}"
    fi

    # Right-align status with padding
    # Emojis (🔴/🟢) take 2 visual spaces but count as 1 char.
    # We want 2 spaces of padding on the right.
    local right_margin=1
    local status_len=${#status_text}
    local status_left_pad=$(( box_width - status_len - 1 - right_margin ))
    
    # Use %b to interpret the escape codes in status_formatted
    printf "${DIM}│${RESET}%*s%b%*s${DIM}│${RESET}\n" $status_left_pad "" "$status_formatted" $right_margin ""

    # Bottom border of box (80 chars total: 1 corner + 78 dashes + 1 corner)
    echo -e "${DIM}└──────────────────────────────────────────────────────────────────────────────┘${RESET}"
   
}

# show_menu()
show_menu() {
    # Display header
    show_box "Available Options:"
    
    local options=(
        "Start Floweave"
        "Stop Floweave"
        "Edit Configuration"
        "Help & Usage Guide"
        "Exit"
    )

    # Display menu options
    local i=1
    for option in "${options[@]}"; do
        echo -e "  ${CYAN}${BOLD}${i}.${RESET} ${option}"
        ((i++))
    done

    echo ""
}

# prompt_input()
prompt_input() {
    local prompt_msg="$1"
    local validation_regex="$2"
    local user_input

    while true; do
        echo -ne "${BLUE}${ARROW_RIGHT}${RESET} ${prompt_msg}: "
        read -r user_input

        # If no validation regex provided, accept any non-empty input
        if [[ -z "$validation_regex" ]]; then
            if [[ -n "$user_input" ]]; then
                echo "$user_input"
                return 0
            else
                show_error "Input cannot be empty. Please try again."
            fi
        else
            # Validate against regex
            if [[ "$user_input" =~ $validation_regex ]]; then
                echo "$user_input"
                return 0
            else
                show_error "Invalid input. Please try again."
            fi
        fi
    done
}

# prompt_yes_no()
prompt_yes_no() {
    local prompt_msg="$1"
    local default="${2:-}"
    local user_input

    # Build prompt with default indicator
    local prompt_suffix
    if [[ "$default" == "y" ]]; then
        prompt_suffix="[Y/n]"
    elif [[ "$default" == "n" ]]; then
        prompt_suffix="[y/N]"
    else
        prompt_suffix="[y/n]"
    fi

    while true; do
        echo -ne "  ${CYAN}${BOLD}${ARROW_RIGHT}${RESET} ${prompt_msg} ${prompt_suffix}: "
        read -r user_input

        # Use default if input is empty
        if [[ -z "$user_input" ]] && [[ -n "$default" ]]; then
            user_input="$default"
        fi

        case "${user_input,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                show_error "Please answer 'y' or 'n'."
                echo ""
                ;;
        esac
    done
}

# prompt_with_default()
prompt_with_default() {
    local prompt_msg="$1"
    local default_value="$2"
    local user_input

    echo -ne "${BLUE}${ARROW_RIGHT}${RESET} ${prompt_msg} ${DIM}[default: ${default_value}]${RESET}: "
    read -r user_input

    # Return default if input is empty
    if [[ -z "$user_input" ]]; then
        echo "$default_value"
    else
        echo "$user_input"
    fi
}

# show_success()
show_success() {
    local message="$1"
    echo -e "  ${GREEN}${CHECK_MARK} ${message}${RESET}"
}

# show_error()
show_error() {
    local message="$1"
    echo -e "  ${RED}${CROSS_MARK} ${message}${RESET}" >&2
}

# show_warning()
show_warning() {
    local message="$1"
    echo -e "  ${YELLOW}${WARNING_SIGN} ${message}${RESET}"
}

# show_info()
show_info() {
    local message="$1"
    echo -e "  ${BLUE}${BOLD}${message}${RESET}"
}

# show_separator()
show_separator() {
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}"
}

# show_box()
show_box() {
    local message="$1"

    # Top border (80 characters wide)
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}"

    # Message
    echo -e "  ${CYAN}${BOLD}${message}${RESET}"

    # Bottom border (80 characters wide)
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}"
}

# press_any_key()
press_any_key() {
    echo ""
    echo -ne " ${DIM}Press any key to continue...${RESET}"
    read -n 1 -s -r
    echo ""
}

# show_loading()
show_loading() {
    local message="$1"
    local duration="${2:-3}"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local end_time=$((SECONDS + duration))

    echo -ne "${GREEN}"
    while [ $SECONDS -lt $end_time ]; do
        for i in "${spinner[@]}"; do
            echo -ne "\r  ${i} ${message}..."
            sleep 0.1
        done
    done
    echo -ne "\r  ${CHECK_MARK} ${message}... Done!${RESET}\n"
}

