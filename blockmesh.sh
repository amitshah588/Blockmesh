#!/bin/bash -e

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Update and upgrade system packages
apt update && apt upgrade -y

# Clean up old files
rm -rf blockmesh-cli.tar.gz target

# Install Docker if not installed
if ! dpkg -l | grep -q docker-ce; then
    echo "Installing Docker..."
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# Install latest Docker Compose
echo "Installing Docker Compose..."
latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create a target directory for extraction
mkdir -p target/release

# Download and extract the latest BlockMesh CLI
echo "Downloading and extracting BlockMesh CLI..."
curl -L https://github.com/block-mesh/block-mesh-monorepo/releases/download/v0.0.415/blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz -o blockmesh-cli.tar.gz
tar -xzf blockmesh-cli.tar.gz -C target/release --strip-components=1

# Verify extraction results
if [[ ! -f target/release/blockmesh-cli ]]; then
    echo "Error: blockmesh-cli executable not found in target/release. Exiting..."
    exit 1
fi

# Prompt for email and password
read -p "Enter your BlockMesh email: " email
read -s -p "Enter your BlockMesh password: " password
echo

# Use BlockMesh CLI to create a Docker container
echo "Creating Docker container for BlockMesh CLI..."
docker run -it --rm \
    --name blockmesh-cli-container \
    -v "$PWD"/target/release:/app \
    -e EMAIL="$email" \
    -e PASSWORD="$password" \
    --workdir /app \
    ubuntu:22.04 ./blockmesh-cli --email "$email" --password "$password"
