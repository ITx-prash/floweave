#!/bin/bash
################################################################################
# Floweave - Display Manager Module
#
# Functions:
#   - get_primary_display()
#   - create_virtual_display()
#   - remove_virtual_display()
#   - calculate_display_geometry()
################################################################################

# Guard against multiple sourcing
[[ -n "${FLOWEAVE_DISPLAY_MANAGER_LOADED}" ]] && return
FLOWEAVE_DISPLAY_MANAGER_LOADED=1

# Source dependencies
FLOWEAVE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FLOWEAVE_MODULE_DIR/ui-helpers.sh"
source "$FLOWEAVE_MODULE_DIR/config-manager.sh"

# get_primary_display()
get_primary_display() {
    local primary_display=""
    local primary_resolution=""
    local primary_width=""
    local primary_height=""

    # Try to get primary display
    primary_display=$(xrandr 2>/dev/null | grep " connected primary" | cut -d' ' -f1)

    # If no primary, get first connected display
    if [[ -z "$primary_display" ]]; then
        primary_display=$(xrandr 2>/dev/null | grep " connected" | head -1 | cut -d' ' -f1)
    fi

    if [[ -z "$primary_display" ]]; then
        show_error "No connected display found"
        return 1
    fi

    # Get resolution
    primary_resolution=$(xrandr 2>/dev/null | grep "$primary_display" | grep -o "[0-9]*x[0-9]*" | head -1)

    if [[ -z "$primary_resolution" ]]; then
        show_error "Could not determine resolution for $primary_display"
        return 1
    fi

    primary_width=$(echo "$primary_resolution" | cut -d'x' -f1)
    primary_height=$(echo "$primary_resolution" | cut -d'x' -f2)

    # Export for use by other functions
    export PRIMARY_DISPLAY="$primary_display"
    export PRIMARY_WIDTH="$primary_width"
    export PRIMARY_HEIGHT="$primary_height"
    export PRIMARY_RESOLUTION="$primary_resolution"

    return 0
}

# calculate_display_geometry()
calculate_display_geometry() {
    local position="${CONFIG[display_position]}"
    local width="${CONFIG[display_width]}"
    local height="${CONFIG[display_height]}"

    # Get primary display info
    if ! get_primary_display; then
        return 1
    fi

    # Calculate offset and xrandr position based on position
    case "$position" in
        "right")
            export OFFSET_X="$PRIMARY_WIDTH"
            export OFFSET_Y="0"
            export XRANDR_POS="--right-of"
            ;;
        "left")
            export OFFSET_X="0"
            export OFFSET_Y="0"
            export XRANDR_POS="--left-of"
            ;;
        "above")
            export OFFSET_X="0"
            export OFFSET_Y="0"
            export XRANDR_POS="--above"
            ;;
        "below")
            export OFFSET_X="0"
            export OFFSET_Y="$PRIMARY_HEIGHT"
            export XRANDR_POS="--below"
            ;;
        *)
            show_error "Invalid position: $position"
            return 1
            ;;
    esac

    export CLIP_GEOMETRY="${width}x${height}+${OFFSET_X}+${OFFSET_Y}"

    return 0
}

# create_virtual_display()
create_virtual_display() {
    local width="${CONFIG[display_width]}"
    local height="${CONFIG[display_height]}"
    local position="${CONFIG[display_position]}"

    show_info "Creating virtual display: ${width}x${height} (${position})"

    # Get primary display info
    if ! get_primary_display; then
        return 1
    fi

    # Calculate geometry
    if ! calculate_display_geometry; then
        return 1
    fi

    # Generate modeline using cvt
    local modeline_output=$(cvt "$width" "$height" 60 2>/dev/null | grep "Modeline")

    if [[ -z "$modeline_output" ]]; then
        show_error "Failed to generate modeline for ${width}x${height}"
        return 1
    fi

    # Extract mode name and parameters
    local mode_name=$(echo "$modeline_output" | cut -d' ' -f2 | tr -d '"')
    local mode_params=$(echo "$modeline_output" | cut -d' ' -f3-)

    # Create new mode (ignore error if already exists)
    xrandr --newmode "$mode_name" $mode_params 2>/dev/null

    # Get list of all disconnected outputs
    local disconnected_outputs=$(xrandr 2>/dev/null | grep " disconnected" | cut -d' ' -f1)

    if [[ -z "$disconnected_outputs" ]]; then
        show_error "No disconnected display output found"
        show_info "Available outputs:"
        xrandr 2>/dev/null | grep -E "(connected|disconnected)"
        return 1
    fi

    # Prioritize VIRTUAL and HDMI outputs to avoid CRTC limits on DP ports
    local prioritized_outputs=""
    local other_outputs=""
    
    for out in $disconnected_outputs; do
        if [[ "$out" == *"VIRTUAL"* ]] || [[ "$out" == *"HDMI"* ]]; then
            prioritized_outputs="$prioritized_outputs $out"
        else
            other_outputs="$other_outputs $out"
        fi
    done
    
    # Combine lists (prioritized first)
    local target_outputs="$prioritized_outputs $other_outputs"

    # Iterate through outputs until one works
    local success=false
    local target_output=""

    for output in $target_outputs; do
        # Skip empty strings
        [[ -z "$output" ]] && continue

        show_info "Trying output: $output..."
        
        # Add mode to output (ignore error if already added)
        xrandr --addmode "$output" "$mode_name" 2>/dev/null

        # Try to enable
        if xrandr --output "$output" --mode "$mode_name" $XRANDR_POS "$PRIMARY_DISPLAY" 2>/dev/null; then
            target_output="$output"
            success=true
            break
        else
            # If failed, remove mode from this output to clean up
            xrandr --delmode "$output" "$mode_name" 2>/dev/null
        fi
    done

    if [[ "$success" == "false" ]]; then
        show_error "Failed to enable virtual display on any available output"
        show_info "Tried: $(echo $target_outputs | xargs)"
        return 1
    fi

    # Save display name for cleanup
    echo "$target_output" > "$FLOWEAVE_DISPLAY_FILE"

    show_success "Virtual display enabled on $target_output"

    return 0
}

# remove_virtual_display()
remove_virtual_display() {
    local display_name=""

    # Try to get display name from file
    if [[ -f "$FLOWEAVE_DISPLAY_FILE" ]]; then
        display_name=$(cat "$FLOWEAVE_DISPLAY_FILE" 2>/dev/null)

        if [[ -n "$display_name" ]]; then
            show_info "Disabling virtual display: $display_name"
            xrandr --output "$display_name" --off 2>/dev/null
        fi

        rm -f "$FLOWEAVE_DISPLAY_FILE"
    fi

    # Fallback: try to find and disable any connected virtual displays
    local virtual_displays=$(xrandr 2>/dev/null | grep -E "(HDMI|VGA|VIRTUAL|DP-[2-9])" | grep " connected" | cut -d' ' -f1)

    if [[ -n "$virtual_displays" ]]; then
        while IFS= read -r display; do
            # Skip if it's the primary display
            if [[ "$display" != "$PRIMARY_DISPLAY" ]]; then
                show_info "Disabling display: $display"
                xrandr --output "$display" --off 2>/dev/null
            fi
        done <<< "$virtual_displays"
    fi

    show_success "Virtual display removed"

    return 0
}
