#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Prompt for container name
read -p "Enter container name (default: jupyter_container): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-jupyter_container}

# Prompt for notebook directory
read -p "Enter notebook directory (default: $SCRIPT_DIR/notebooks): " NOTEBOOK_DIR
NOTEBOOK_DIR=${NOTEBOOK_DIR:-$SCRIPT_DIR/notebooks}

# Prompt for GPU ID configuration
echo "Configure GPU usage:"
echo "1. Allow all GPUs"
echo "2. Specify GPU IDs"
read -p "Select option (1 or 2): " GPU_OPTION
if [ "$GPU_OPTION" -eq 2 ]; then
    read -p "Enter GPU IDs to use (comma-separated, e.g., 0,1): " GPU_IDS
    GPU_FLAG="--gpus \"device=$GPU_IDS\""
else
    GPU_FLAG="--gpus all"
fi

# Prompt for IP address
read -p "Enter container IP address (default: 172.18.0.2): " CONTAINER_IP
CONTAINER_IP=${CONTAINER_IP:-172.18.0.2}

# Password configuration
JUPYTER_PASSWORD=$(openssl rand -base64 16)

# Create directories if they don't exist and set permissions
echo "Creating notebook directories..."
mkdir -p "$NOTEBOOK_DIR"
sudo chown -R 1000:1000 "$NOTEBOOK_DIR"
sudo chmod 777 "$NOTEBOOK_DIR"

# Stop and remove existing containers and network
echo "Cleaning up existing containers and network..."
docker stop "$CONTAINER_NAME" 2>/dev/null
docker rm "$CONTAINER_NAME" 2>/dev/null
docker network rm jupyter_net 2>/dev/null

# Create docker network
if ! docker network inspect jupyter_net >/dev/null 2>&1; then
    echo "Creating docker network..."
    docker network create \
        --driver bridge \
        --subnet 172.18.0.0/16 \
        --gateway 172.18.0.1 \
        jupyter_net
else
    echo "Network jupyter_net already exists."
fi

# Build single image
echo "Building Jupyter image..."
docker build -t jupyter-gpu .

# Function to set Jupyter password
set_jupyter_password() {
    local container_name=$1
    local password=$2
    
    echo "Setting password for $container_name..."
    docker exec $container_name python3 -c "
from jupyter_server.auth import passwd
with open('/home/user/.jupyter/jupyter_server_config.py', 'a') as f:
    f.write('\nc.ServerApp.password = \"' + passwd('$password') + '\"')
"
    
    # Restart Jupyter process
    docker exec $container_name pkill -f jupyter
    docker exec -d $container_name jupyter lab --ip=0.0.0.0 --port=8888 --no-browser
}

# Run container
echo "Starting container: $CONTAINER_NAME"
docker run -d $GPU_FLAG \
    --name "$CONTAINER_NAME" \
    --network jupyter_net \
    --ip "$CONTAINER_IP" \
    --user user \
    -v "$NOTEBOOK_DIR":/home/user/work \
    jupyter-gpu

# Wait for containers to start
echo "Waiting for containers to start..."
sleep 5

# Set passwords
echo "Setting up passwords..."
set_jupyter_password "$CONTAINER_NAME" "$JUPYTER_PASSWORD"

# Save passwords to file
echo -e "\nSaving passwords to passwords.txt..."
echo "Jupyter Password: $JUPYTER_PASSWORD" > "$SCRIPT_DIR/passwords.txt"
chmod 600 "$SCRIPT_DIR/passwords.txt"

echo "
Setup completed!
- Notebooks location: $NOTEBOOK_DIR
- Jupyter Lab URL: http://$CONTAINER_IP:8888/lab
- Passwords have been saved to: $SCRIPT_DIR/passwords.txt
"

# Final check
echo "Checking Jupyter processes..."
docker exec "$CONTAINER_NAME" ps aux | grep jupyter || echo "No Jupyter process found"