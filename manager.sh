#!/bin/bash

# Configuration
IMAGE_NAME="hummingbot/hummingbot:latest"
BASE_CONF_DIR="./conf"
BASE_DATA_DIR="./data"

# Global array to store container names for selection by number
declare -a SELECTABLE_CONTAINERS=()

# Function to list all hummingbot containers (for menu option 1 - detailed view)
list_containers() {
    echo "Available Hummingbot containers:"
    docker ps -a --filter "ancestor=$IMAGE_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Helper function to list containers with numbers for selection
list_containers_for_selection() {
    echo "Available Hummingbot containers:"
    mapfile -t SELECTABLE_CONTAINERS < <(docker ps -a --filter "ancestor=$IMAGE_NAME" --format "{{.Names}}")

    if [ ${#SELECTABLE_CONTAINERS[@]} -eq 0 ]; then
        echo "No Hummingbot containers found."
        return 1 # Indicate no containers
    fi

    local idx=0
    for name in "${SELECTABLE_CONTAINERS[@]}"; do
        # You could add status here if desired, e.g., by querying docker ps again for each name
        # local status=$(docker ps -a --filter "name=^${name}$" --format "{{.Status}}")
        # echo "$((idx + 1)). $name ($status)"
        echo "$((idx + 1)). $name"
        ((idx++))
    done
    echo "" # Newline after list
    return 0 # Success
}

# Helper function to prompt for a container by number and return its name.
# On success, echoes name to stdout and returns 0.
# On failure, echoes error to stderr and returns 1.
prompt_and_get_selected_container_name() {
    local prompt_message="$1"
    local choice

    # Ensure SELECTABLE_CONTAINERS is not empty before prompting
    if [ ${#SELECTABLE_CONTAINERS[@]} -eq 0 ]; then
        echo "No containers available for selection." >&2
        return 1
    fi

    read -p "$prompt_message (enter number): " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a number." >&2
        return 1
    fi

    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#SELECTABLE_CONTAINERS[@]}" ]; then
        echo "Invalid number. Please choose from the list (1-${#SELECTABLE_CONTAINERS[@]})." >&2
        return 1
    fi
    
    echo "${SELECTABLE_CONTAINERS[$((choice - 1))]}"
    return 0
}


# Proper attach function for Hummingbot interface
attach_container() {
    if ! list_containers_for_selection; then
        return
    fi
    
    local container_name
    if ! container_name=$(prompt_and_get_selected_container_name "Enter container number to attach"); then
        return
    fi
    
    # Check if the container is running, as 'docker exec' requires a running container.
    # 'docker ps' (without -a) lists only running containers.
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Attempting to start Hummingbot interface in $container_name using 'docker exec -it'..."
        echo "This will run the command: /bin/bash -lc \"conda activate hummingbot && ./bin/hummingbot_quickstart.py 2>> ./logs/errors.log\""
        echo ""
        echo "Understanding how to exit/detach:"
        echo "1. TO STOP HUMMINGBOT AND THE CONTAINER:"
        echo "   Use Hummingbot's built-in 'exit' or 'quit' command from within its interface."
        echo "   This should allow Hummingbot to shut down cleanly and will stop the container if its main process ends."
        echo ""
        echo "2. TO LEAVE THIS INTERACTIVE SESSION BUT KEEP HUMMINGBOT RUNNING IN THE CONTAINER:"
        echo "   Use the Docker detach sequence: Press Ctrl+P, then Ctrl+Q."
        echo "   IMPORTANT: After detaching with Ctrl+P Ctrl+Q, your terminal might display characters"
        echo "   incorrectly or behave strangely. If this happens, type 'reset' in your"
        echo "   host terminal and press Enter to restore normal terminal behavior."
        echo ""
        
        # Explicitly provide the command and its arguments to docker exec
        docker exec -it "$container_name" /bin/bash -lc "conda activate hummingbot && ./bin/hummingbot_quickstart.py 2>> ./logs/errors.log"
        
        echo "Exited 'docker exec' session for $container_name."
        echo "If the interface did not start as expected, or for other issues, check container logs (option 8)."
    else
        echo "Error: Container $container_name not found or not running. 'docker exec' requires a running container."
        # Removed exit 1 to allow returning to the menu
    fi
}

# Shell access for maintenance
exec_container() {
    if ! list_containers_for_selection; then
        return
    fi

    local container_name
    if ! container_name=$(prompt_and_get_selected_container_name "Enter container number for shell access"); then
        return
    fi
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Opening shell in $container_name (type 'exit' to return)"
        docker exec -it "$container_name" /bin/bash
    else
        echo "Error: Container $container_name not found or not running."
        exit 1
    fi
}

# Function to create a new instance
create_instance() {
    list_containers
    echo ""
    read -p "Enter new container name (e.g., hummingbot-kraken): " new_name
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${new_name}\$"; then
        echo "Error: Container $new_name already exists."
        exit 1
    fi
    
    # Create unique directories for this instance
    mkdir -p "${BASE_CONF_DIR}_${new_name}"
    mkdir -p "${BASE_DATA_DIR}_${new_name}"
    
    echo "Creating new Hummingbot instance: $new_name..."
    docker run -d \
        --name "$new_name" \
        --network host \
        -v "${BASE_CONF_DIR}_${new_name}:/home/hummingbot/conf" \
        -v "${BASE_CONF_DIR}_${new_name}/connectors:/home/hummingbot/conf/connectors" \
        -v "${BASE_CONF_DIR}_${new_name}/strategies:/home/hummingbot/conf/strategies" \
        -v "${BASE_CONF_DIR}_${new_name}/controllers:/home/hummingbot/conf/controllers" \
        -v "${BASE_CONF_DIR}_${new_name}/scripts:/home/hummingbot/conf/scripts" \
        -v "${BASE_DATA_DIR}_${new_name}/logs:/home/hummingbot/logs" \
        -v "${BASE_DATA_DIR}_${new_name}:/home/hummingbot/data" \
        -v "${BASE_DATA_DIR}_${new_name}/certs:/home/hummingbot/certs" \
        -v "${BASE_DATA_DIR}_${new_name}/scripts:/home/hummingbot/scripts" \
        -v "${BASE_DATA_DIR}_${new_name}/controllers:/home/hummingbot/controllers" \
        --log-driver json-file \
        --log-opt max-size=10m \
        --log-opt max-file=5 \
        --tty \
        --interactive \
        "$IMAGE_NAME"
    
    echo "Created container $new_name"
    echo "You can now attach to it using this script"
}

# Function to stop a container
stop_instance() {
    if ! list_containers_for_selection; then
        return
    fi

    local container_name
    if ! container_name=$(prompt_and_get_selected_container_name "Enter container number to stop"); then
        return
    fi
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Stopping $container_name..."
        docker stop "$container_name"
        echo "Container $container_name stopped"
    else
        echo "Error: Container $container_name not found or not running."
        exit 1
    fi
}

# Function to start a container
start_instance() {
    if ! list_containers_for_selection; then
        return
    fi

    local container_name
    if ! container_name=$(prompt_and_get_selected_container_name "Enter container number to start"); then
        return
    fi
    
    # For starting, we check among all containers (running or stopped)
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Starting $container_name..."
        docker start "$container_name"
        echo "Container $container_name started"
    else
        echo "Error: Container $container_name not found."
        exit 1
    fi
}

# Function to remove a container
remove_instance() {
    if ! list_containers_for_selection; then
        return
    fi

    local container_name
    if ! container_name=$(prompt_and_get_selected_container_name "Enter container number to remove"); then
        return
    fi
    
    read -p "This will delete the container '$container_name' and its data. Continue? (y/n) " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # For removing, we check among all containers (running or stopped)
        if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}\$"; then
            echo "Stopping and removing $container_name..."
            docker stop "$container_name" >/dev/null 2>&1
            docker rm "$container_name"
            echo "Removing data directories..."
            rm -rf "${BASE_CONF_DIR}_${container_name}"
            rm -rf "${BASE_DATA_DIR}_${container_name}"
            echo "Container $container_name and its data have been removed"
        else
            echo "Error: Container $container_name not found."
            exit 1
        fi
    else
        echo "Operation cancelled."
    fi
}

# Function to view container logs
view_logs() {
    if ! list_containers_for_selection; then
        return
    fi

    local container_name
    if ! container_name=$(prompt_and_get_selected_container_name "Enter container number to view logs"); then
        return
    fi
        
    # Check if container exists (running or stopped)
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Log options for $container_name:"
        echo "1. View all logs"
        echo "2. Follow logs (Ctrl+C to stop)"
        echo "3. View last 100 lines"
        read -p "Choose log option (1-3, or any other key to cancel): " log_option
        
        echo "" # Newline for better readability before log output
        case $log_option in
            1) 
                echo "Displaying all logs for $container_name..."
                docker logs "$container_name" ;;
            2) 
                echo "Following logs for $container_name (Ctrl+C to stop)..."
                docker logs -f "$container_name" ;;
            3) 
                echo "Displaying last 100 lines of logs for $container_name..."
                docker logs --tail 100 "$container_name" ;;
            *) 
                echo "Log view cancelled or invalid option." ;;
        esac
    else
        echo "Error: Container $container_name not found."
    fi
}

# Main menu
while true; do
    echo ""
    echo "Hummingbot Container Manager"
    echo "1. List all containers"
    echo "2. Attach to container (Hummingbot interface)"
    echo "3. Create new instance"
    echo "4. Start container"
    echo "5. Stop container"
    echo "6. Remove container"
    echo "7. Open shell (maintenance)"
    echo "8. View container logs" # New option
    echo "9. Exit" # Adjusted option number
    read -p "Choose an option (1-9): " option # Adjusted range
    
    case $option in
        1) list_containers ;;
        2) attach_container ;;
        3) create_instance ;;
        4) start_instance ;;
        5) stop_instance ;;
        6) remove_instance ;;
        7) exec_container ;;
        8) view_logs ;; # Call new function
        9) exit 0 ;;    # Adjusted exit option
        *) echo "Invalid option";;
    esac
done