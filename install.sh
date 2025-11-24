#!/bin/bash
################################################################################
# Floweave Installer
# Installs Floweave to ~/.local/share/floweave/ and creates CLI command
################################################################################

set -e

# Get script directory first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source UI helpers
if [[ -f "$SCRIPT_DIR/modules/ui-helpers.sh" ]]; then
    source "$SCRIPT_DIR/modules/ui-helpers.sh"
else
    echo "Error: modules/ui-helpers.sh not found."
    exit 1
fi

# Installation paths
INSTALL_DIR="$HOME/.local/share/floweave"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/floweave"

# Custom Installer Header
show_installer_header() {
    clear
    echo -e "${DIM}┌──────────────────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${DIM}│${RESET}                                                                              ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}███████╗██╗      ██████╗ ██╗    ██╗███████╗ █████╗ ██╗   ██╗███████╗${RESET}       ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}██╔════╝██║     ██╔═══██╗██║    ██║██╔════╝██╔══██╗██║   ██║██╔════╝${RESET}       ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}█████╗  ██║     ██║   ██║██║ █╗ ██║█████╗  ███████║██║   ██║█████╗${RESET}         ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}██╔══╝  ██║     ██║   ██║██║███╗██║██╔══╝  ██╔══██║╚██╗ ██╔╝██╔══╝${RESET}         ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}██║     ███████╗╚██████╔╝╚███╔███╔╝███████╗██║  ██║ ╚████╔╝ ███████╗${RESET}       ${DIM}│${RESET}"
    echo -e "${DIM}│${RESET}   ${GREEN}╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝${RESET}       ${DIM}│${RESET}"
    
    local title="INSTALLER"
    local width=78
    local title_len=${#title}
    local pad=$(( (width - title_len) / 2 ))
    local right_pad=$(( width - title_len - pad ))
    
    echo -e "${DIM}│${RESET}                                                                              ${DIM}│${RESET}"
    printf "${DIM}│${RESET}%*s${CYAN}${BOLD}%s${RESET}%*s${DIM}│${RESET}\n" $pad "" "$title" $right_pad ""
    echo -e "${DIM}└──────────────────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
}

# Show Header
show_installer_header

# Check if running from floweave directory
if [[ ! -f "$SCRIPT_DIR/floweave.sh" ]] || [[ ! -d "$SCRIPT_DIR/modules" ]]; then
    show_error "This script must be run from the floweave directory"
    echo ""
    echo -e "  ${DIM}Expected structure:${RESET}"
    echo "    floweave/"
    echo "    ├── floweave.sh"
    echo "    ├── modules/"
    echo "    └── install.sh (this script)"
    echo ""
    exit 1
fi

# Show installation target
show_box "Installation Target"
echo -e "  ${DIM}Path:${RESET} ${BOLD}$INSTALL_DIR${RESET}"
echo ""

# Create installation directory
mkdir -p "$INSTALL_DIR" 2>/dev/null
mkdir -p "$BIN_DIR" 2>/dev/null

# Step 1: Copy files
show_loading "Copying Floweave files" 1

cp "$SCRIPT_DIR/floweave.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/floweave.sh"
cp -r "$SCRIPT_DIR/modules" "$INSTALL_DIR/"

# Copy VERSION file if it exists
if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    cp "$SCRIPT_DIR/VERSION" "$INSTALL_DIR/"
fi

if [[ -d "$SCRIPT_DIR/config" ]]; then
    cp -r "$SCRIPT_DIR/config" "$INSTALL_DIR/"
fi

# Step 2: Create CLI command
show_loading "Creating CLI command" 1

cat > "$BIN_PATH" << 'EOF'
#!/bin/bash
# Floweave CLI wrapper
exec "$HOME/.local/share/floweave/floweave.sh" "$@"
EOF

chmod +x "$BIN_PATH"

# Step 3: Configure PATH
SHELL_PROFILE=""
PATH_UPDATED=false

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    show_loading "Configuring shell PATH" 1

    # Detect shell and add to appropriate profile
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "export PATH=.*\.local/bin" "$HOME/.bashrc"; then
            echo '' >> "$HOME/.bashrc"
            echo '# Floweave CLI' >> "$HOME/.bashrc"
            echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.bashrc"
            PATH_UPDATED=true
        fi
        SHELL_PROFILE="~/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "export PATH=.*\.local/bin" "$HOME/.zshrc"; then
            echo '' >> "$HOME/.zshrc"
            echo '# Floweave CLI' >> "$HOME/.zshrc"
            echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.zshrc"
            PATH_UPDATED=true
        fi
        SHELL_PROFILE="~/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        if ! grep -q "export PATH=.*\.local/bin" "$HOME/.profile"; then
            echo '' >> "$HOME/.profile"
            echo '# Floweave CLI' >> "$HOME/.profile"
            echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.profile"
            PATH_UPDATED=true
        fi
        SHELL_PROFILE="~/.profile"
    fi

    # Fish shell support
    if [[ "$SHELL" == *"fish"* ]]; then
        if ! fish -c "contains $HOME/.local/bin \$fish_user_paths" 2>/dev/null; then
            fish -c "set -U fish_user_paths $HOME/.local/bin \$fish_user_paths" 2>/dev/null
            SHELL_PROFILE="config.fish"
            PATH_UPDATED=true
        fi
    fi
else
    # PATH already contains ~/.local/bin
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_PROFILE="~/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_PROFILE="~/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        SHELL_PROFILE="~/.profile"
    fi
fi

echo ""
show_success "Floweave successfully installed!"
echo ""
show_separator
echo ""

# Show next steps based on PATH status
if [[ "$PATH_UPDATED" == true ]] && [[ -n "$SHELL_PROFILE" ]]; then
    show_warning "Action Required:"
    echo -e "  Restart your terminal or run: ${CYAN}${BOLD}source $SHELL_PROFILE${RESET}"
    echo ""
fi

show_box "Quick Start"
echo -e "  • Run ${CYAN}${BOLD}floweave${RESET} to start the menu"
echo -e "  • Run ${CYAN}${BOLD}floweave --help${RESET} for CLI usage"
echo ""
echo -e "  ${DIM}(You can now safely delete this installer folder)${RESET}"
echo ""

