#!/bin/bash

# Configuration
IMAGE_NAME="hummingbot/hummingbot:latest"
BASE_CONF_DIR="./conf"
BASE_DATA_DIR="./data"

# Function to list all hummingbot containers
list_containers() {
    echo "Available Hummingbot containers:"
    docker ps --filter "ancestor=$IMAGE_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Function to attach to a container
attach_container() {
    list_containers
    echo ""
    read -p "Enter container name to attach: " container_name
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Attaching to $container_name..."
        docker attach "$container_name"
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
        "$IMAGE_NAME"
    
    echo "Created container $new_name"
    echo "You can now attach to it using this script"
}

# Function to stop a container
stop_instance() {
    list_containers
    echo ""
    read -p "Enter container name to stop: " container_name
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}\$"; then
        echo "Stopping $container_name..."
        docker stop "$container_name"
        echo "Container $container_name stopped"
    else
        echo "Error: Container $container_name not found or not running."
        exit 1
    fi
}

# Main menu
while true; do
    echo ""
    echo "Hummingbot Container Manager"
    echo "1. List containers"
    echo "2. Attach to container"
    echo "3. Create new instance"
    echo "4. Stop container"
    echo "5. Exit"
    read -p "Choose an option (1-5): " option
    
    case $option in
        1) list_containers ;;
        2) attach_container ;;
        3) create_instance ;;
        4) stop_instance ;;
        5) exit 0 ;;
        *) echo "Invalid option";;
    esac
done