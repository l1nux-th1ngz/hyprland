#!/usr/bin/env sh
#
# WOFI POWER-MENU #
###################

# Exit on error, unset variable as error, and propagate failure in pipelines
set -euo pipefail

# Trap & cleanup previous executions
cleanup() {
    # Kill all remaining processes still running
    killall -9Ieqg $$ >/dev/null 2>&1
    exit 0
}
trap cleanup EXIT

# Function to check if the required tools are installed
requirements() {
    local required_tools=("wofi" "notify-send")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        notify-send -u critical -a "$0" "Missing tools: ${missing_tools[@]}" ||
        echo "Missing tools: ${missing_tools[@]}" 2>&1
        return 1
    else
        return 0
    fi
}

# Function to handle power menu options
powermenu() {
    local selected="$1"

    case "$selected" in
        "Reload")
            if [[ $XDG_SESSION_DESKTOP =~ ^sway* ]]; then
                swaymsg reload
            elif [ $XDG_SESSION_DESKTOP == "hyprland" ]; then
                hyprctl reload
            else
                systemctl --user daemon-reload
                systemctl --user daemon-reexec
            fi
            ;;
        "Lock")
            "$lock"
            ;;
        "Suspend")
            systemctl suspend && "$lock"
            ;;
        "Logout")
            if [[ $XDG_SESSION_DESKTOP =~ ^sway* ]]; then
                swaymsg exit
            elif [ $XDG_SESSION_DESKTOP == "hyprland" ]; then
                hyprctl dispatch exit 1
            else
                loginctl terminate-session "$XDG_SESSION_ID"
                loginctl kill-user $(whoami)
            fi
            ;;
        "Reboot")
            systemctl reboot
            ;;
        "Reboot to BIOS/UEFI")
            systemctl reboot --firmware-setup
            ;;
        "Shutdown")
            systemctl poweroff
            ;;
        *)
            cleanup
            ;;
    esac
}

# Main function to display the power menu
main() {
    if requirements; then
        local lock="$HOME/.config/wofi/scripts/lock.sh"
        local menu=( "Reload" "Lock" "Suspend" "Logout" "Reboot" "Reboot to BIOS/UEFI" "Shutdown")
        local selected=$(printf "%s\n" "${menu[@]}" | wofi --dmenu --prompt "<Power-Menu>" | tr -d '\n')

        powermenu "$selected"
    fi

    cleanup
}

# Start of the script
main
