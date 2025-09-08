#!/bin/bash

# Velocity Pool - Unified Daemon Sync Monitor
# Live monitoring of all deployed daemons

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Clear screen function
clear_screen() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              VELOCITY POOL - DAEMON SYNC STATUS            ║${NC}"
    echo -e "${BLUE}║                  $(date +'%Y-%m-%d %H:%M:%S')                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to get daemon status
get_daemon_status() {
    local daemon_name="$1"
    local cli_command="$2"
    local rpc_method="$3"
    local port="$4"
    
    local status="❌ NOT RUNNING"
    local blocks="N/A"
    local headers="N/A"
    local peers="N/A"
    local sync_progress=""
    local color="$RED"
    
    # Check if daemon process is running
    if pgrep -f "$daemon_name" > /dev/null 2>&1; then
        status="🔄 STARTING"
        color="$YELLOW"
        
        # Try to get blockchain info
        if [ "$daemon_name" = "derod" ]; then
            # Dero uses JSON-RPC
            local response=$(curl -s -X POST http://127.0.0.1:${port}/json_rpc \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","id":"1","method":"get_info"}' 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$response" ]; then
                blocks=$(echo "$response" | jq -r '.result.height // "N/A"' 2>/dev/null)
                peers=$(echo "$response" | jq -r '.result.outgoing_connections_count // "N/A"' 2>/dev/null)
                headers="$blocks"
                
                if [ "$blocks" != "N/A" ] && [ "$blocks" != "null" ]; then
                    status="✅ SYNCED"
                    color="$GREEN"
                fi
            fi
        else
            # Bitcoin-style RPC
            local info=$($cli_command getblockchaininfo 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$info" ]; then
                blocks=$(echo "$info" | jq -r '.blocks // "N/A"' 2>/dev/null)
                headers=$(echo "$info" | jq -r '.headers // "N/A"' 2>/dev/null)
                local progress=$(echo "$info" | jq -r '.verificationprogress // "N/A"' 2>/dev/null)
                
                # Get network info for peer count
                local netinfo=$($cli_command getnetworkinfo 2>/dev/null)
                if [ $? -eq 0 ]; then
                    peers=$(echo "$netinfo" | jq -r '.connections // "N/A"' 2>/dev/null)
                fi
                
                # Determine sync status
                if [ "$progress" != "N/A" ] && [ "$progress" != "null" ]; then
                    if (( $(echo "$progress < 0.99" | bc -l 2>/dev/null || echo 0) )); then
                        local percent=$(echo "$progress * 100" | bc -l 2>/dev/null | cut -d. -f1)
                        sync_progress=" (${percent}%)"
                        status="🔄 SYNCING${sync_progress}"
                        color="$YELLOW"
                    else
                        status="✅ SYNCED"
                        color="$GREEN"
                    fi
                else
                    if [ "$blocks" = "$headers" ] && [ "$blocks" != "N/A" ] && [ "$blocks" != "0" ]; then
                        status="✅ SYNCED"
                        color="$GREEN"
                    else
                        status="🔄 SYNCING"
                        color="$YELLOW"
                    fi
                fi
            fi
        fi
    fi
    
    printf "${color}%-12s${NC} %s\n" "$daemon_name" "$status"
    printf "               Blocks: %-8s Headers: %-8s Peers: %-3s\n" "$blocks" "$headers" "$peers"
    echo
}

# Function to check if daemon is deployed
check_if_deployed() {
    local daemon_name="$1"
    if command -v "$daemon_name" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Main monitoring loop
main() {
    while true; do
        clear_screen
        
        echo -e "${CYAN}Daemon Status:${NC}"
        echo "────────────────────────────────────────────────────────────"
        
        # Check each daemon
        if check_if_deployed "verusd"; then
            get_daemon_status "verusd" "/usr/local/bin/verus" "getblockchaininfo" "27486"
        else
            printf "${RED}%-12s${NC} ⏳ NOT DEPLOYED\n\n" "VERUS"
        fi
        
        if check_if_deployed "meowcoind"; then
            get_daemon_status "meowcoind" "/usr/local/bin/meowcoin-cli" "getblockchaininfo" "9766"
        else
            printf "${RED}%-12s${NC} ⏳ NOT DEPLOYED\n\n" "MEOWCOIN"
        fi
        
        if check_if_deployed "raptoreumd"; then
            get_daemon_status "raptoreumd" "/usr/local/bin/raptoreum-cli" "getblockchaininfo" "10226"
        else
            printf "${RED}%-12s${NC} ⏳ NOT DEPLOYED\n\n" "RAPTOREUM"
        fi
        
        if check_if_deployed "derod"; then
            get_daemon_status "derod" "" "get_info" "10102"
        else
            printf "${RED}%-12s${NC} ⏳ NOT DEPLOYED\n\n" "DERO"
        fi
        
        if check_if_deployed "neoxad"; then
            get_daemon_status "neoxad" "/usr/local/bin/neoxa-cli" "getblockchaininfo" "8766"
        else
            printf "${RED}%-12s${NC} ⏳ NOT DEPLOYED\n\n" "NEOXA"
        fi
        
        echo "────────────────────────────────────────────────────────────"
        echo -e "${PURPLE}Algorithm Coverage:${NC}"
        echo "  🖥️  CPU: VerusHash (Verus) | GhostRider (Raptoreum) | AstroBWT (Dero)"
        echo "  🎮 GPU: KawPoW (MeowCoin, Neoxa)"
        echo ""
        echo -e "${CYAN}Commands: ${NC}Ctrl+C to exit | Deploy more daemons in another terminal"
        
        # Wait 3 seconds before next update
        sleep 3
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${GREEN}Monitoring stopped.${NC}"; exit 0' INT

# Run the monitor
main
