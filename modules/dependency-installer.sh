#!/bin/bash

if ! command -v show_info &> /dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/ui-helpers.sh"
fi

detect_distro() {
    show_info "Detecting Linux distribution..." >&2

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="${ID}"
        VERSION_ID="${VERSION_ID}"

        show_success "Detected: ${NAME} ${VERSION_ID}" >&2

        case "${DISTRO}" in
            ubuntu|debian|linuxmint|pop|elementary)
                PKG_MANAGER="apt"
                show_info "Package manager: APT (Debian-based)" >&2
                ;;
            fedora)
                PKG_MANAGER="dnf"
                show_info "Package manager: DNF (Fedora)" >&2
                ;;
            centos|rhel|rocky|almalinux)
                PKG_MANAGER="yum"
                show_info "Package manager: YUM (RHEL-based)" >&2
                ;;
            arch|manjaro|endeavouros)
                PKG_MANAGER="pacman"
                show_info "Package manager: Pacman (Arch-based)" >&2
                ;;
            opensuse|opensuse-leap|opensuse-tumbleweed)
                PKG_MANAGER="zypper"
                show_info "Package manager: Zypper (openSUSE)" >&2
                ;;
            *)
                show_warning "Unsupported distribution: ${DISTRO}" >&2
                show_info "Manual package installation may be required" >&2
                PKG_MANAGER="unknown"
                ;;
        esac

        echo "${DISTRO}"
        return 0
    else
        show_error "Cannot detect Linux distribution (/etc/os-release not found)" >&2
        echo "unknown"
        return 1
    fi
}

check_dependencies_silent() {
    MISSING_DEPS=()

    local module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$module_dir/display-backend.sh"
    detect_display_backend

    local all_deps=()
    if [[ "$FLOWEAVE_BACKEND" == "gnome-wayland" ]]; then
        all_deps=(
            "grdctl:gnome-remote-desktop"
        )
    else
        all_deps=(
            "xrandr:x11-xserver-utils"
            "cvt:x11-xserver-utils"
            "x11vnc:x11vnc"
        )
    fi

    for dep_info in "${all_deps[@]}"; do
        local cmd="${dep_info%%:*}"
        local pkg="${dep_info##*:}"

        if ! command -v "${cmd}" &> /dev/null; then
            MISSING_DEPS+=("${pkg}")
        fi
    done

    if [[ ${#MISSING_DEPS[@]} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

install_dependencies() {
    if [[ -z "${PKG_MANAGER}" ]]; then
        detect_distro || return 1
    fi

    local module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$module_dir/display-backend.sh"
    detect_display_backend

    echo ""

    if [[ "$FLOWEAVE_BACKEND" == "gnome-wayland" ]]; then
        case "${PKG_MANAGER}" in
            apt)
                echo -e "${GREEN}Updating package lists...${RESET}"
                sudo apt update || return 1
                echo ""
                echo -e "${GREEN}Installing package: gnome-remote-desktop...${RESET}"
                sudo apt install -y gnome-remote-desktop || return 1
                ;;
            dnf)
                show_info "Installing package: gnome-remote-desktop"
                sudo dnf install -y gnome-remote-desktop || return 1
                ;;
            yum)
                show_info "Installing package: gnome-remote-desktop"
                sudo yum install -y gnome-remote-desktop || return 1
                ;;
            pacman)
                show_info "Installing package: gnome-remote-desktop"
                sudo pacman -S --noconfirm gnome-remote-desktop || return 1
                ;;
            zypper)
                show_info "Installing package: gnome-remote-desktop"
                sudo zypper install -y gnome-remote-desktop || return 1
                ;;
            *)
                show_error "Unsupported package manager: ${PKG_MANAGER}"
                show_info "Please install gnome-remote-desktop manually."
                return 1
                ;;
        esac
    else
        case "${PKG_MANAGER}" in
            apt)
                echo -e "${GREEN}Updating package lists...${RESET}"
                sudo apt update || return 1
                echo ""
                echo -e "${GREEN}Installing packages: x11vnc, x11-xserver-utils...${RESET}"
                sudo apt install -y x11vnc x11-xserver-utils || return 1
                ;;
            dnf)
                show_info "Installing packages: x11vnc, xorg-x11-server-utils"
                sudo dnf install -y x11vnc xorg-x11-server-utils || return 1
                ;;
            yum)
                show_info "Enabling EPEL repository..."
                sudo yum install -y epel-release || return 1
                show_info "Installing packages: x11vnc, xorg-x11-server-utils"
                sudo yum install -y x11vnc xorg-x11-server-utils || return 1
                ;;
            pacman)
                show_info "Installing packages: x11vnc, xorg-xrandr"
                sudo pacman -S --noconfirm x11vnc xorg-xrandr || return 1
                ;;
            zypper)
                show_info "Installing packages: x11vnc, xrandr"
                sudo zypper install -y x11vnc xrandr || return 1
                ;;
            *)
                show_error "Unsupported package manager: ${PKG_MANAGER}"
                show_info "Please install the following packages manually:"
                echo "  - x11vnc (VNC server)"
                echo "  - xrandr (display management)"
                return 1
                ;;
        esac
    fi

    return 0
}

