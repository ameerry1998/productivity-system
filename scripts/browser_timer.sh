#!/bin/bash

# Browser time tracking script
# Tracks daily and hourly browser usage with sophisticated limits

# Configuration
DAILY_LIMIT=16200    # 4 hours 30 minutes in seconds (270 minutes)
HOURLY_LIMIT=2700    # 45 minutes in seconds
BREAK_DURATION=1500  # 25 minutes break in seconds

TIMER_FILE="$HOME/.browser_timer"
HOURLY_FILE="$HOME/.browser_hourly"
BREAK_FILE="$HOME/.browser_break"

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
)

# Function to get current day and hour
get_current_day() {
    date +%Y-%m-%d
}

get_current_hour() {
    date +%Y-%m-%d-%H
}

# Function to get today's total usage
get_today_usage() {
    local today=$(get_current_day)
    if [ -f "$TIMER_FILE" ]; then
        grep "^$today:" "$TIMER_FILE" | cut -d: -f2 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get current hour's usage
get_hourly_usage() {
    local current_hour=$(get_current_hour)
    if [ -f "$HOURLY_FILE" ]; then
        grep "^$current_hour:" "$HOURLY_FILE" | cut -d: -f2 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to check if we're in a break period
is_in_break() {
    if [ -f "$BREAK_FILE" ]; then
        local break_end=$(cat "$BREAK_FILE")
        local current_time=$(date +%s)
        if [ $current_time -lt $break_end ]; then
            return 0  # Still in break
        else
            rm -f "$BREAK_FILE"  # Break is over
            return 1
        fi
    fi
    return 1  # Not in break
}

# Function to start break period
start_break() {
    local break_end=$(($(date +%s) + BREAK_DURATION))
    echo $break_end > "$BREAK_FILE"
    echo "$(date): Starting 25-minute break. Break ends at $(date -r $break_end)"
}

# Function to update usage counters
update_usage() {
    local today=$(get_current_day)
    local current_hour=$(get_current_hour)
    local interval=5  # 5 seconds
    
    # Update daily counter
    local current_daily=$(get_today_usage)
    local new_daily=$((current_daily + interval))
    
    if [ -f "$TIMER_FILE" ]; then
        grep -v "^$today:" "$TIMER_FILE" > "$TIMER_FILE.tmp" 2>/dev/null || true
        echo "$today:$new_daily" >> "$TIMER_FILE.tmp"
        mv "$TIMER_FILE.tmp" "$TIMER_FILE"
    else
        echo "$today:$new_daily" > "$TIMER_FILE"
    fi
    
    # Update hourly counter
    local current_hourly=$(get_hourly_usage)
    local new_hourly=$((current_hourly + interval))
    
    if [ -f "$HOURLY_FILE" ]; then
        grep -v "^$current_hour:" "$HOURLY_FILE" > "$HOURLY_FILE.tmp" 2>/dev/null || true
        echo "$current_hour:$new_hourly" >> "$HOURLY_FILE.tmp"
        mv "$HOURLY_FILE.tmp" "$HOURLY_FILE"
    else
        echo "$current_hour:$new_hourly" > "$HOURLY_FILE"
    fi
    
    # Clean old hourly entries (keep only last 2 hours)
    if [ -f "$HOURLY_FILE" ]; then
        local cutoff_hour=$(date -v-2H +%Y-%m-%d-%H 2>/dev/null || date -d "2 hours ago" +%Y-%m-%d-%H 2>/dev/null || echo "")
        if [ -n "$cutoff_hour" ]; then
            grep "^$cutoff_hour:" "$HOURLY_FILE" > "$HOURLY_FILE.tmp" 2>/dev/null || true
            grep "^$(get_current_hour):" "$HOURLY_FILE" >> "$HOURLY_FILE.tmp" 2>/dev/null || true
            mv "$HOURLY_FILE.tmp" "$HOURLY_FILE" 2>/dev/null || true
        fi
    fi
}

# Function to check if browser is active
is_browser_active() {
    local frontmost_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
    
    for browser in "${BROWSERS[@]}"; do
        if [[ "$frontmost_app" == "$browser" ]]; then
            return 0  # Browser is active
        fi
    done
    return 1  # No browser active
}

# Function to kill browsers
kill_browsers() {
    for browser in "${BROWSERS[@]}"; do
        pkill -f "$browser" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$(date): Killed $browser (daily limit reached)"
        fi
    done
}

# Function to show comprehensive status
show_status() {
    local daily_usage=$(get_today_usage)
    local hourly_usage=$(get_hourly_usage)
    local daily_remaining=$((DAILY_LIMIT - daily_usage))
    local hourly_remaining=$((HOURLY_LIMIT - hourly_usage))
    
    local daily_hours=$((daily_usage / 3600))
    local daily_minutes=$(((daily_usage % 3600) / 60))
    local hourly_minutes=$((hourly_usage / 60))
    local hourly_seconds=$((hourly_usage % 60))
    
    echo "$(date): Daily: ${daily_hours}h ${daily_minutes}m used ($(( daily_remaining / 60 )) min left)"
    echo "$(date): Hourly: ${hourly_minutes}m ${hourly_seconds}s used ($(( hourly_remaining / 60 )) min left this hour)"
    
    if is_in_break; then
        local break_end=$(cat "$BREAK_FILE")
        local break_remaining=$((break_end - $(date +%s)))
        echo "$(date): In break period - $((break_remaining / 60)) minutes remaining"
    fi
}

# Function to get time until break ends (for display)
get_break_remaining() {
    if [ -f "$BREAK_FILE" ]; then
        local break_end=$(cat "$BREAK_FILE")
        local current_time=$(date +%s)
        local remaining=$((break_end - current_time))
        if [ $remaining -gt 0 ]; then
            echo $remaining
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Function to check if we're in blocked time period (05:00 → 10:40)
is_blocked_time() {
    # Minutes since midnight, with leading zeros handled safely
    local h=$(date +%H)
    local m=$(date +%M)
    local now=$((10#$h * 60 + 10#$m))
    local start=$((5 * 60))     # 05:00 → 300
    local end=$((10 * 60 + 40)) # 10:40 → 640
    if [ $now -ge $start ] && [ $now -lt $end ]; then
        return 0  # Blocked time
    fi
    return 1  # Not blocked time
}

# Main loop
while true; do
    daily_usage=$(get_today_usage)
    hourly_usage=$(get_hourly_usage)
    
    # Check if we're in blocked time period (5am-noon)
    if is_blocked_time; then
        kill_browsers
        echo "$(date): Browsers blocked during restricted hours (5am-noon)"
        sleep 3  # Check every 3 seconds during blocked hours to prevent relaunching
        continue
    fi
    
    # Check if in break period
    if is_in_break; then
        kill_browsers
        break_remaining=$(get_break_remaining)
        if [ $break_remaining -gt 0 ]; then
            echo "$(date): Break period active - $((break_remaining / 60)) minutes remaining"
        fi
        sleep 30  # Check less frequently during breaks
        continue
    fi
    
    # Check daily limit
    if [ $daily_usage -ge $DAILY_LIMIT ]; then
        kill_browsers
        echo "$(date): Daily browser limit (4h30m) reached - browsers blocked until tomorrow"
        sleep 60  # Check less frequently when daily limit reached
        continue
    fi
    
    # Check hourly limit
    if [ $hourly_usage -ge $HOURLY_LIMIT ]; then
        kill_browsers
        start_break
        sleep 5
        continue
    fi
    
    # Only track time if a browser is active and not blocked
    if is_browser_active; then
        update_usage
        show_status
    fi
    
    # Check every 5 seconds
    sleep 5
done
