#!/bin/bash
#
# LLM Config Manager - cURL Examples
#
# This script demonstrates all API endpoints using cURL.
# These examples can be used for testing, debugging, or as a reference
# for implementing clients in other languages.
#

# Configuration
BASE_URL="http://localhost:8080"
API_BASE="${BASE_URL}/api/v1"
TOKEN="your-auth-token"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function to print section headers
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

# Helper function to print commands
print_command() {
    echo -e "${YELLOW}$ $1${NC}"
}

# Helper function to check if server is running
check_server() {
    if ! curl -s -f "${BASE_URL}/health" > /dev/null; then
        echo -e "${RED}Error: API server is not running at ${BASE_URL}${NC}"
        echo "Start the server with: llm-config-server --host 0.0.0.0 --port 8080"
        exit 1
    fi
}

###############################################################################
# HEALTH CHECK
###############################################################################

health_check() {
    print_header "Health Check"

    print_command "curl ${BASE_URL}/health"
    curl -s "${BASE_URL}/health" | jq .
}

###############################################################################
# CONFIGURATION MANAGEMENT
###############################################################################

# Get Configuration
get_config() {
    print_header "Get Configuration"

    print_command "curl ${API_BASE}/configs/app/llm/model?env=production"
    curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm/model?env=production" \
        | jq .
}

# Get Configuration with Overrides
get_config_with_overrides() {
    print_header "Get Configuration with Overrides"

    print_command "curl ${API_BASE}/configs/app/llm/model?env=production&with_overrides=true"
    curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm/model?env=production&with_overrides=true" \
        | jq .
}

# Set String Configuration
set_string_config() {
    print_header "Set String Configuration"

    print_command 'curl -X POST ${API_BASE}/configs/app/llm/model -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": "gpt-4",
            "env": "production",
            "user": "admin",
            "secret": false
        }' \
        "${API_BASE}/configs/app/llm/model" \
        | jq .
}

# Set Number Configuration
set_number_config() {
    print_header "Set Number Configuration"

    print_command 'curl -X POST ${API_BASE}/configs/app/llm/temperature -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": 0.7,
            "env": "production",
            "user": "admin",
            "secret": false
        }' \
        "${API_BASE}/configs/app/llm/temperature" \
        | jq .
}

# Set Boolean Configuration
set_boolean_config() {
    print_header "Set Boolean Configuration"

    print_command 'curl -X POST ${API_BASE}/configs/features/new_ui -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": true,
            "env": "production",
            "user": "admin",
            "secret": false
        }' \
        "${API_BASE}/configs/features/new_ui" \
        | jq .
}

# Set Object Configuration
set_object_config() {
    print_header "Set Object Configuration"

    print_command 'curl -X POST ${API_BASE}/configs/app/llm/settings -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": {
                "temperature": 0.7,
                "max_tokens": 2000,
                "top_p": 0.9
            },
            "env": "production",
            "user": "admin",
            "secret": false
        }' \
        "${API_BASE}/configs/app/llm/settings" \
        | jq .
}

# Set Array Configuration
set_array_config() {
    print_header "Set Array Configuration"

    print_command 'curl -X POST ${API_BASE}/configs/app/llm/models -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": ["gpt-4", "gpt-3.5-turbo", "claude-2"],
            "env": "production",
            "user": "admin",
            "secret": false
        }' \
        "${API_BASE}/configs/app/llm/models" \
        | jq .
}

# Set Secret Configuration
set_secret_config() {
    print_header "Set Secret Configuration (Encrypted)"

    print_command 'curl -X POST ${API_BASE}/configs/app/llm/api_key -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": "sk-proj-abc123xyz789...",
            "env": "production",
            "user": "admin",
            "secret": true
        }' \
        "${API_BASE}/configs/app/llm/api_key" \
        | jq .
}

# List Configurations
list_configs() {
    print_header "List Configurations"

    print_command "curl ${API_BASE}/configs/app/llm?env=production"
    curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm?env=production" \
        | jq .
}

# Delete Configuration
delete_config() {
    print_header "Delete Configuration"

    print_command "curl -X DELETE ${API_BASE}/configs/app/llm/old_config?env=development"
    curl -s -X DELETE \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm/old_config?env=development" \
        -w "\nHTTP Status: %{http_code}\n"
}

###############################################################################
# VERSION HISTORY
###############################################################################

# Get Version History
get_history() {
    print_header "Get Version History"

    print_command "curl ${API_BASE}/configs/app/llm/model/history?env=production"
    curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm/model/history?env=production" \
        | jq .
}

# Rollback Configuration
rollback_config() {
    print_header "Rollback Configuration"

    print_command "curl -X POST ${API_BASE}/configs/app/llm/model/rollback/2?env=production"
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm/model/rollback/2?env=production" \
        | jq .
}

###############################################################################
# ERROR HANDLING EXAMPLES
###############################################################################

# 404 Not Found
test_not_found() {
    print_header "Error Handling: 404 Not Found"

    print_command "curl ${API_BASE}/configs/nonexistent/key?env=production"
    curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/nonexistent/key?env=production" \
        -w "\nHTTP Status: %{http_code}\n" \
        | jq .
}

# 400 Bad Request
test_bad_request() {
    print_header "Error Handling: 400 Bad Request"

    print_command 'curl -X POST ${API_BASE}/configs/app/llm/test -d {...}'
    curl -s -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "value": "test",
            "env": "invalid_environment",
            "user": "admin"
        }' \
        "${API_BASE}/configs/app/llm/test" \
        -w "\nHTTP Status: %{http_code}\n" \
        | jq .
}

# 401 Unauthorized
test_unauthorized() {
    print_header "Error Handling: 401 Unauthorized"

    print_command "curl ${API_BASE}/configs/app/llm/model?env=production (no token)"
    curl -s \
        "${API_BASE}/configs/app/llm/model?env=production" \
        -w "\nHTTP Status: %{http_code}\n" \
        | jq .
}

###############################################################################
# RATE LIMITING EXAMPLES
###############################################################################

# Check Rate Limit Headers
check_rate_limits() {
    print_header "Check Rate Limit Headers"

    print_command "curl -I ${API_BASE}/configs/app/llm/model?env=production"
    curl -sI \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/app/llm/model?env=production" \
        | grep -i "x-ratelimit"
}

# Simulate Rate Limiting
test_rate_limiting() {
    print_header "Test Rate Limiting (send multiple requests)"

    echo "Sending 15 requests in quick succession..."
    for i in {1..15}; do
        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: Bearer ${TOKEN}" \
            "${API_BASE}/configs/app/llm/model?env=production")

        status_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n-1)

        if [ "$status_code" = "429" ]; then
            echo -e "${RED}Request $i: Rate limited (429)${NC}"
            echo "$body" | jq .
            break
        else
            echo -e "${GREEN}Request $i: Success (200)${NC}"
        fi

        sleep 0.1
    done
}

###############################################################################
# ADVANCED EXAMPLES
###############################################################################

# Bulk Configuration Import
bulk_import() {
    print_header "Bulk Configuration Import"

    echo "Setting multiple configurations..."

    configs=(
        "app/llm/model:gpt-4"
        "app/llm/temperature:0.7"
        "app/llm/max_tokens:2000"
        "database/host:localhost"
        "database/port:5432"
    )

    for config in "${configs[@]}"; do
        IFS=':' read -r path value <<< "$config"
        namespace=$(dirname "$path")
        key=$(basename "$path")

        echo "Setting $namespace/$key = $value"

        curl -s -X POST \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"value\": \"$value\",
                \"env\": \"production\",
                \"user\": \"admin\",
                \"secret\": false
            }" \
            "${API_BASE}/configs/$namespace/$key" \
            > /dev/null

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Success${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    done
}

# Configuration Backup
backup_namespace() {
    print_header "Backup Namespace Configuration"

    namespace="app/llm"
    env="production"
    backup_file="backup_${namespace//\//_}_${env}_$(date +%Y%m%d_%H%M%S).json"

    print_command "curl ${API_BASE}/configs/${namespace}?env=${env} > ${backup_file}"

    curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/${namespace}?env=${env}" \
        | jq . > "$backup_file"

    echo "Backup saved to: $backup_file"
}

# Configuration Diff Between Environments
diff_environments() {
    print_header "Diff Configurations Between Environments"

    namespace="app/llm"

    echo "Fetching configurations..."

    dev_configs=$(curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/${namespace}?env=development" \
        | jq -S 'sort_by(.key)')

    prod_configs=$(curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API_BASE}/configs/${namespace}?env=production" \
        | jq -S 'sort_by(.key)')

    echo "Development configs:"
    echo "$dev_configs" | jq -c '.[] | {key: .key, value: .value}'

    echo -e "\nProduction configs:"
    echo "$prod_configs" | jq -c '.[] | {key: .key, value: .value}'
}

###############################################################################
# MAIN MENU
###############################################################################

show_menu() {
    echo -e "\n${GREEN}LLM Config Manager - cURL Examples${NC}"
    echo "=================================="
    echo
    echo "Basic Operations:"
    echo "  1) Health Check"
    echo "  2) Get Configuration"
    echo "  3) Set Configuration (String)"
    echo "  4) Set Configuration (Number)"
    echo "  5) Set Configuration (Boolean)"
    echo "  6) Set Configuration (Object)"
    echo "  7) Set Configuration (Array)"
    echo "  8) Set Secret Configuration"
    echo "  9) List Configurations"
    echo " 10) Delete Configuration"
    echo
    echo "Version History:"
    echo " 11) Get Version History"
    echo " 12) Rollback Configuration"
    echo
    echo "Error Handling:"
    echo " 13) Test 404 Not Found"
    echo " 14) Test 400 Bad Request"
    echo " 15) Test 401 Unauthorized"
    echo
    echo "Rate Limiting:"
    echo " 16) Check Rate Limit Headers"
    echo " 17) Test Rate Limiting"
    echo
    echo "Advanced:"
    echo " 18) Bulk Import"
    echo " 19) Backup Namespace"
    echo " 20) Diff Environments"
    echo
    echo "  0) Run All Examples"
    echo "  q) Quit"
    echo
}

run_all() {
    health_check
    set_string_config
    set_number_config
    set_boolean_config
    set_object_config
    set_array_config
    get_config
    list_configs
    get_history
    check_rate_limits
}

# Main loop
main() {
    # Check if server is running
    check_server

    # If arguments provided, run specific example
    if [ $# -gt 0 ]; then
        case $1 in
            health) health_check ;;
            get) get_config ;;
            set) set_string_config ;;
            list) list_configs ;;
            history) get_history ;;
            all) run_all ;;
            *) echo "Unknown command: $1" ;;
        esac
        exit 0
    fi

    # Interactive mode
    while true; do
        show_menu
        read -p "Select option: " choice

        case $choice in
            1) health_check ;;
            2) get_config ;;
            3) set_string_config ;;
            4) set_number_config ;;
            5) set_boolean_config ;;
            6) set_object_config ;;
            7) set_array_config ;;
            8) set_secret_config ;;
            9) list_configs ;;
            10) delete_config ;;
            11) get_history ;;
            12) rollback_config ;;
            13) test_not_found ;;
            14) test_bad_request ;;
            15) test_unauthorized ;;
            16) check_rate_limits ;;
            17) test_rate_limiting ;;
            18) bulk_import ;;
            19) backup_namespace ;;
            20) diff_environments ;;
            0) run_all ;;
            q|Q) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
