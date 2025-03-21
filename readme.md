# Public IP Address Monitor

A bash script that monitors your public IP address for changes, logs the information, and updates your IP with NextDNS. When changes are detected, it sends notifications via ntfy.sh. In my case, runs from a Raspberry Pi.

- Monitors public IP address changes
- Sends notifications when IP changes occur
- Update your NextDNS profile with your updated IP

## Prerequisites

- jq (for JSON parsing)
- Access to [ipinfo.io API](https://ipinfo.io/signup)
- [ntfy.sh account](https://ntfy.sh/signup)/topic

## Configuration

Edit the following variables in `ip_monitor.sh`:

```bash
IP_SERVICE="https://ipinfo.io?token=YOUR_IPINFO_TOKEN"  # Add your ipinfo.io token
NTFY_TOPIC="YOUR_NTFY_TOPIC"                              # Add your ntfy.sh topic
"YOUR_NEXTDNS_PROFILE"                               # Add your NextDNS profile id
"YOUR_NEXTDNS_IP_LINK_TOKEN"               # Add your unique NextDNS IP link token
"YOUR_EMAIL"                                        # email for ntfy.sh to send to
```