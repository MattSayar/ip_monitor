#!/bin/bash
# Configuration
LOG_DIR="/home/pi/ip_logs"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).csv"
MAX_RETRIES=3
RETRY_DELAY=5
IP_SERVICE="https://ipinfo.io?token=YOUR_IPINFO_TOKEN"
NTFY_TOPIC="YOUR_NTFY_TOPIC"

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
         -H "email:YOUR_EMAIL" \
         ntfy.sh/$NTFY_TOPIC
}

# Function to get the last valid IP from log file
get_last_valid_ip() {
    local log_file="$1"
    local last_ip=""
    
    # Read the file line by line, ignoring the header and empty entries
    while IFS= read -r line; do
        # Extract IP (second column)
        ip_field=$(echo "$line" | cut -d, -f2)
        
        # If it's not empty, not "ip" (header), and not "error"
        if [ -n "$ip_field" ] && [ "$ip_field" != "ip" ] && [ "$ip_field" != "error" ]; then
            # Found a valid IP, save it
            last_ip="$ip_field"
        fi
    done < "$log_file"
    
    echo "$last_ip"
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
    
    # Get last valid IP from log file
    LAST_IP=$(get_last_valid_ip "$LOG_FILE")
    
    if [ -z "$LAST_IP" ] || [ "$ip" != "$LAST_IP" ]; then
        # Log new entry
        echo "$NOW,$ip,$hostname,$city,$region,$country,$loc,$org,$postal,$timezone" >> "$LOG_FILE"
        
        # Update NextDNS
        nextdns_response=$(curl -s -o /dev/null -w "%{http_code}" "https://link-ip.nextdns.io/YOUR_NEXTDNS_PROFILE/YOUR_NEXTDNS_IP_LINK_TOKEN")
        if [ "$nextdns_response" != "200" ]; then
            send_notification "NextDNS Update Failed" "IP changed but NextDNS update failed. Status: $nextdns_response" "5"
        fi
        
        # Send notification about IP change
        if [ -z "$LAST_IP" ]; then
            send_notification "IP Address Logged" "Initial IP: $ip Location: $city, $region, $country ISP: $org" "4"
        else
            send_notification "IP Address Changed" "New IP: $ip Previous IP: $LAST_IP Location: $city, $region, $country ISP: $org" "4"
        fi
    fi
else
    # Log error
    echo "$NOW,,,,,,,,,," >> "$LOG_FILE"
    
    # Send error notification
    send_notification "IP Monitoring Error" "Failed to fetch IP information after $MAX_RETRIES attempts" "5"
fi

# Cleanup old logs (keep 6 months)
find "$LOG_DIR" -name "*.csv" -mtime +180 -delete