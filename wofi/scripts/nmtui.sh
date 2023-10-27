#!/usr/bin/env bash
#
# WOFI~NMTUI #
##############

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
    local required_tools=("iwconfig" "ifconfig" "nmcli" "wofi" "speedtest" "notify-send")
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

# Function to validate user's input and break out of a loop
traverse() {
    local input="$1"

    if [ -z "$input" ]; then
        # If user's input is empty, return 0 to continue the loop
        return 0
    else
        # If user's input is not empty, break out of the loop
        return 1
    fi
}

check_connection() {
    local check=$(nmcli networking connectivity check)

    case "$check" in
        "")
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

login() {
    local input="$1"

    case "$input" in
        "password")
            local password=$(wofi --dmenu --prompt "<Password>" --password | tr -d '\n')
            ;;
        "$input")
            local value=$(wofi --dmenu --prompt "<$input>" | tr -d '\n')
            ;;
        *)
            notify-send -u normal -a "CREDZ" "WTF!??"
            return 1
            ;;
    esac

    if ! check_connection; then
        notify-send -u normal -a "Login" "Failed!"
        login "$input"
    else
        notify-send -u normal -a "Login" "Successful!"
        return 0
    fi
}

menu() {
    # handle network options
    local selected1="$1"
    
    case "$selected1" in
        "EDIT DNS")
            local resolv="/etc/resolv.conf"

            while ! sudo -n true 2>/dev/null; do
                local password=$(login "password")
            done

            if [[ -z $EDITOR ]]; then
                # Prompt for editor if EDITOR is not set
                local editor=$(wofi --dmenu --prompt "<Specify Editor...HINT: .BASHRC>" | tr -d '\n')
                export EDITOR="$editor"
            elif [[ ! -f $resolv ]]; then
                # Prompt for resolv file if file doesn't exist
                local resolving="$(find /etc/ -type f -name "*resolv*.conf")"
                resolv=$(echo -e "$resolving" | wofi --dmenu --prompt "<Specify: resolv.conf>" | tr -d '\n')
            else
                sudo -SE $EDITOR "$resolv" <<<"$password"
            fi
        ;;
        "EDIT CONNECTION") # WIP
            # Get a list of known network connections
            local connections=$(nmcli connection show | awk '{if (NR>1) print $1}')

            while true; do
                local selected2=$(echo -e "Add\nEdit\nDelete" | wofi --dmenu --prompt "Select an option:")

                case "$selected2" in
                    "Add")
                        # Function to handle adding a connection
                        list=("DSL" "ETHERNET" "INFINITIBAND" "WI-FI" "BOND" "BRIDGE" "IP-TUNNEL" "MACSEC" "TEAM" "VETH" "VLAN" "PROXY" "WIREGUARD")

                        local type=$(wofi --dmenu --prompt "<NEW-CONNECTION>" <<<"${list[@]/%/$'\n'}" | tr -d '\n')
                        nmcli connection add type "$type"
                        notify-send -u normal -a "$type" "Connection added successfully"
                    ;;
                    "Edit")
                        # Function to handle editing a connection
                        selected3=$(echo -e "$connections" | wofi --dmenu --prompt "Select a connection to edit:")

                        if [ -n "$selected3" ]; then
                            nmcli connection edit "$selected3"
                        fi
                    ;;
                    "Delete")
                        # Function to handle deleting a connection
                        selected4=$(echo -e "$connections" | wofi --dmenu --prompt "Select a connection to delete:")

                        if [ -n "$selected4" ]; then
                            nmcli connection delete "$selected4"
                            notify-send -u normal -a "$selected4" "Connection deleted successfully"
                        fi
                    ;;
                    *)
                        break
                    ;;
                esac
            done
        ;;
        "ACTIVATE CONNECTION") # WIP
            # Get a list of known network connections
            local connections=$(nmcli connection show | awk '{if (NR>1) print $1}')

            # Ensure that $selected2 is defined before use
            local selected2=""
            selected2=$(echo -e "$connections" | wofi --dmenu --prompt "Select a connection to activate:")

            if [ -n "$selected2" ]; then
                nmcli connection up id "$selected2"
                notify-send -u normal -a "Network Connection" "Activated"
            fi
        ;;
        "SPEED TEST")
            ## REQUIRES REAL-TIME REPORTING FIX
            if check_connection; then
                local test=$(wofi --dmenu --prompt "<Gathering Potatoes..." -IiMm -W 600 -L 10 <<<"$(speedtest)" | tr -d '\n')
            else 
                notify-send -u critical -a "Speedtest" "No Potatoes!"
            fi
        ;;
        "SYSTEM HOSTNAME")
            local hostname=$(hostnamectl hostname)
            local newname=$(wofi --dmenu --prompt "<New Hostname>" <<<"$hostname" | tr -d '\n')
            
            if [ -n "$newname" ]; then
                sudo hostnamectl set-hostname "$newname"
                notify-send -u normal -a "Hostname" "$newname"
            else
                notify-send -u normal -a "Hostname" "$hostname"
            fi
        ;;
        *)
            return
        ;;
    esac
}

# Main function to display the network options and handle user's input
main() {
    while requirements; do
        local list=("EDIT DNS" "EDIT CONNECTION" "ACTIVATE CONNECTION" "SPEED TEST" "SYSTEM HOSTNAME" "~DONE~")
        local selected1=$(wofi --dmenu --prompt "<NMTUI-MENU>" <<<"${list[@]/%/$'\n'}" | tr -d '\n')

        if [ "$selected1" == "~DONE~" ]; then
            break
        fi

        menu "$selected1"
    done

    cleanup
}

# Start of the script
main
