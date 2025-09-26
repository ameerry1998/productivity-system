#!/bin/bash

# Browser blocking script - Kills browsers when at home
# This prevents web browsing distractions when working from home
# Uses reliable SSID detection with Ethernet/tethering gateway-MAC fallback

# Home WiFi networks to detect
HOME_NETWORKS=(
    "GL-AXT1800-13d"
    "GL-AXT1800-13d-5G" 
    "Shawarma_signals"
)

# Optional: Home gateway MAC addresses for non-Wi‑Fi (Ethernet/tethering) detection
# Populate with values like: "c6:14:11:5a:b0:64"
HOME_GATEWAY_MACS=()

# Comprehensive browser list (80+ browsers)
BROWSERS=(
    "Safari"
    "Arc"
    "Google Chrome"
    "Firefox"
    "Microsoft Edge"
    "Opera"
    "Brave Browser"
    "Vivaldi"
    "Session"
    "Tor Browser"
    "DuckDuckGo Privacy Browser"
    "Chromium"
    "Chrome Canary"
    "Firefox Developer Edition"
    "Firefox Nightly"
    "Safari Technology Preview"
    "Opera GX"
    "Opera Neon"
    "Yandex Browser"
    "UC Browser"
    "Maxthon"
    "Pale Moon"
    "Waterfox"
    "SeaMonkey"
    "Basilisk"
    "IceCat"
    "Epiphany"
    "Midori"
    "Falkon"
    "QupZilla"
    "Konqueror"
    "Lynx"
    "Links"
    "w3m"
    "Elinks"
    "Dillo"
    "NetSurf"
    "Otter Browser"
    "Min"
    "Beaker Browser"
    "Blisk"
    "Cliqz"
    "Comodo Dragon"
    "Comodo IceDragon"
    "CoolNovo"
    "Coowon"
    "Cyberfox"
    "Flock"
    "Ghost Browser"
    "Iridium"
    "Iron"
    "K-Meleon"
    "Lunascape"
    "Maxthon Cloud Browser"
    "Naver Whale"
    "Orbitum"
    "Puffin"
    "QQ Browser"
    "Rockmelt"
    "Sleipnir"
    "Slimjet"
    "SRWare Iron"
    "Superbird"
    "TheWorld Browser"
    "Torch"
    "Uzbl"
    "Vimb"
    "Xombrero"
    "115 Browser"
    "360 Secure Browser"
    "Avant Browser"
    "Browzar"
    "Camino"
    "Classilla"
    "CM Browser"
    "Dolphin"
    "FlashPeak SlimBrowser"
    "Froggy"
    "GreenBrowser"
    "HiSuite"
    "Iceweasel"
    "Internet Explorer"
    "Kinza"
    "Liebao"
    "NeoPlanet"
    "Netscape"
    "OmniWeb"
    "PhantomJS"
    "Polarity"
    "Prism"
    "QtWeb"
    "Rekonq"
    "RockMelt"
    "Shiira"
    "Sunrise"
    "Swiftfox"
    "TenFourFox"
    "Tencent Traveler"
    "TorchBrowser"
    "Tungsten"
    "Wyzo"
    "Xvast"
)

# Network detection caching
CACHE_FILE="/tmp/.network_cache"
CACHE_DURATION=60  # Cache for 60 seconds
LOG_FILE="/var/log/screen_lock.log"

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Get current Wi‑Fi SSID (modern, reliable)
get_current_ssid() {
    # Method 1: System Profiler (most reliable)
    local ssid=$(system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/{getline; gsub(/^[[:space:]]*|:[[:space:]]*$/, "", $0); print $0; exit}')
    
    if [ -n "$ssid" ]; then
        echo "$ssid"
        return
    fi
    
    # Method 2: Dynamic Wi-Fi interface detection
    local wifi_interface=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
    if [ -n "$wifi_interface" ]; then
        networksetup -getairportnetwork "$wifi_interface" 2>/dev/null | cut -d: -f2 | xargs
    fi
}

# Get default gateway IP
get_default_gateway_ip() {
    route -n get default 2>/dev/null | awk '/gateway/ {print $2; exit}'
}

# Get default gateway MAC (works for Ethernet/tethering)
get_default_gateway_mac() {
    local gw_ip
    gw_ip=$(get_default_gateway_ip)
    [ -n "$gw_ip" ] || return 1
    arp -n "$gw_ip" 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="at"){print $(i+1); exit}}}'
}

# Function to check if cache is valid
is_cache_valid() {
    if [ -f "$CACHE_FILE" ]; then
        local cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
        local current_time=$(date +%s)
        local age=$((current_time - cache_time))
        
        if [ $age -lt $CACHE_DURATION ]; then
            return 0  # Cache is valid
        fi
    fi
    return 1  # Cache is invalid or doesn't exist
}

# Function to update network cache
update_network_cache() {
    local current_ssid
    current_ssid=$(get_current_ssid)
    echo "$current_ssid" > "$CACHE_FILE"
    log_message "Updated network cache: ${current_ssid:-<none>}"
}

# Function to get cached network
get_cached_network() {
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
    else
        echo ""
    fi
}

# Function to check if any home network is in range
is_at_home() {
    local current_ssid
    local gw_mac
    
    if is_cache_valid; then
        current_ssid=$(get_cached_network)
    else
        current_ssid=$(get_current_ssid)
        echo "$current_ssid" > "$CACHE_FILE"
    fi
    
    for network in "${HOME_NETWORKS[@]}"; do
        if [[ "$current_ssid" == "$network" ]]; then
            log_message "Connected to home network '$network'"
            return 0  # At home
        fi
    done

    # Fallback: check gateway MAC when not on Wi‑Fi
    gw_mac=$(get_default_gateway_mac)
    if [ -n "$gw_mac" ]; then
        # Normalize case for safe comparison on macOS bash 3.2
        local gw_lc
        gw_lc=$(echo "$gw_mac" | tr '[:upper:]' '[:lower:]')
        for mac in "${HOME_GATEWAY_MACS[@]}"; do
            local mac_lc
            mac_lc=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
            if [[ "$gw_lc" == "$mac_lc" ]]; then
                log_message "On home network via gateway MAC $gw_mac"
                return 0
            fi
        done
    fi
    return 1  # Not at home
}

# Function to kill browsers
block_browsers() {
    local blocked_count=0
    
    for browser in "${BROWSERS[@]}"; do
        if pkill -x "$browser" 2>/dev/null; then
            log_message "Blocked $browser (at home)"
            ((blocked_count++))
        fi
    done
    
    if [ $blocked_count -gt 0 ]; then
        log_message "Blocked $blocked_count browser(s) due to home network detection"
    fi
}

# Cleanup function
cleanup() {
    log_message "Browser blocking script shutting down"
    rm -f "$CACHE_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

log_message "Browser blocking script started - monitoring home networks: ${HOME_NETWORKS[*]}"

# Main loop
cache_update_counter=0
while true; do
    # Update cache every minute (60 iterations of 1-second sleep)
    if [ $cache_update_counter -ge 60 ]; then
        update_network_cache
        cache_update_counter=0
    fi
    
    if is_at_home; then
        block_browsers
        sleep 2
    else
        sleep 10
    fi
    
    ((cache_update_counter++))
done