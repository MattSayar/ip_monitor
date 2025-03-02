#!/bin/bash
# Minimal IP Monitoring Script
# Configuration
LOG_DIR="/home/pi/ip_logs"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).csv"
MAX_RETRIES=3
RETRY_DELAY=5
IP_SERVICE="https://ipinfo.io?token=YOUR_IPINFO_TOKEN"  # Your ipinfo.io token
NTFY_TOPIC="YOUR_NTFY_TOPIC"  # Your ntfy.sh topic

# Create log directory if missing
mkdir -p "$LOG_DIR"

# Initialize log file with headers if it doesn't exist
[ ! -f "$LOG_FILE" ] && echo "timestamp,ip,hostname,city,region,country,loc,org,postal,timezone" > "$LOG_FILE"

# Function to fetch IP info with retries
fetch_ip_info() {
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        response=$(curl -s --max-time 10 "$IP_SERVICE")
        if [ $? -eq 0 ]; then
            echo "$response"
            return 0
        fi
        retries=$((retries + 1))
        sleep $RETRY_DELAY
    done
    return 1
}

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"

    curl -s -H "Title: $title" \
         -H "Priority: $priority" \
         -H "Tags: network,ip" \
         -d "$message" \
     -H "email:YOUR_EMAIL"\
         ntfy.sh/$NTFY_TOPIC
}

# Main execution
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
response=$(fetch_ip_info)
if [ $? -eq 0 ]; then
    # Parse JSON response
    ip=$(echo "$response" | jq -r '.ip')
    hostname=$(echo "$response" | jq -r '.hostname')
    city=$(echo "$response" | jq -r '.city')
    region=$(echo "$response" | jq -r '.region')
    country=$(echo "$response" | jq -r '.country')
    loc=$(echo "$response" | jq -r '.loc')
    org=$(echo "$response" | jq -r '.org')
    postal=$(echo "$response" | jq -r '.postal')
    timezone=$(echo "$response" | jq -r '.timezone')

    # Get last entry
    LAST_ENTRY=$(tail -1 "$LOG_FILE")
    LAST_IP=$(echo "$LAST_ENTRY" | cut -d, -f2)

    if [ "$ip" != "$LAST_IP" ]; then
        # Log new entry
        echo "$NOW,$ip,$hostname,$city,$region,$country,$loc,$org,$postal,$timezone" >> "$LOG_FILE"

        # Update NextDNS
        nextdns_response=$(curl -s -o /dev/null -w "%{http_code}" "https://link-ip.nextdns.io/YOUR_NEXTDNS_PROFILE/YOUR_NEXTDNS_IP_LINK_URL")
        if [ "$nextdns_response" != "200" ]; then
            send_notification "NextDNS Update Failed" "IP changed but NextDNS update failed. Status: $nextdns_response" "5"
        fi

        # Send notification about IP change
        send_notification "IP Address Changed" "New IP: $ip\nLocation: $city, $region, $country\nISP: $org" "4"
    fi
else
    # Log error
    echo "$NOW,error,,,,,,,,," >> "$LOG_FILE"

    # Send error notification
    send_notification "IP Monitoring Error" "Failed to fetch IP information after $MAX_RETRIES attempts" "5"
fi

# Cleanup old logs (keep 6 months)
find "$LOG_DIR" -name "*.csv" -mtime +180 -delete