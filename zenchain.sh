#!/bin/bash

curl -s https://raw.githubusercontent.com/CryptoBureau01/logo/main/logo.sh | bash
sleep 5

# Function to print info messages
print_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

# Function to print error messages
print_error() {
    echo -e "\e[31m[ERROR] $1\e[0m"
}



# File path
priv_data_file="/root/chain-data/chains/priv-data.txt"



# Function to install dependencies (Rust in this case)
install_dependency() {
    print_info "<=========== Install Dependency ==============>"
    print_info "Updating and upgrading system packages, and installing curl..."
    sudo apt update && sudo apt upgrade -y && sudo apt install curl wget jq -y && sudo apt install -y clang libssl-dev llvm libudev-dev pkg-config protobuf-compiler make

    # Check if Docker is already installed
    if ! command -v docker &> /dev/null; then
        print_info "Docker is not installed. Installing Docker..."
        sudo apt install docker.io -y

        # Check for installation errors
        if [ $? -ne 0 ]; then
            print_error "Failed to install Docker. Please check your system for issues."
            exit 1
        fi
    else
        print_info "Docker is already installed."
    fi

    # Check if Rust is already installed
    if command -v rustc &> /dev/null; then
        print_info "Rust is already installed. Skipping installation."
    else
        print_info "Rust is not installed. Installing Rust..."
        
        # Install Rust
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        if [ $? -eq 0 ]; then
            print_info "Rust installed successfully."
            # Add Rust to the current shell session
            source "$HOME/.cargo/env"
        else
            print_error "Failed to install Rust."
            exit 1
        fi
    fi


    # Check Python version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    version_check=$(python3 -c "import sys; print(sys.version_info >= (3, 12))")

    # Check if python3-apt is installed
    if ! python3 -c "import apt_pkg" &>/dev/null; then
        if [ "$version_check" = "False" ]; then
            print_info "Python version $python_version is below 3.12. Attempting to update Python..."
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip
        fi

        # Now try installing python3-apt
        print_info "Attempting to install python3-apt..."
        if sudo apt-get install -y python3-apt; then
            print_info "python3-apt installed successfully."
        else
            print_error "Failed to install python3-apt. Please check your system and try again."
            print_error "You may need to install it manually if the automated process fails."
            exit 1
        fi
    else
        print_info "python3-apt is already installed."
    fi

    # Required Go version
    required_version="1.22.0"

    # Python3 Version
    python3 --version

    # Pip3 Version
    pip3 --version

    # pip Install web3 
    pip3 install web3

    # Update system
    sudo apt update 

    # Print Docker and Docker Compose versions to confirm installation
    print_info "Checking Docker version..."
    docker --version

    print_info "Checking Rust version..."
    rustc --version

    # Call the uni_menu function to display the menu
    node_menu

}





# Function to setup ZenChain Node
setup_node() {
    print_info "<=========== Setting Up ZenChain Node ==============>"
    
    # Pull the latest ZenChain Docker image
    print_info "Pulling the latest ZenChain Docker image..."
    docker pull ghcr.io/zenchain-protocol/zenchain-testnet:latest
    if [ $? -eq 0 ]; then
        print_info "ZenChain Docker image pulled successfully."
    else
        print_error "Failed to pull the ZenChain Docker image."
        exit 1
    fi

    # Return to the menu after the node setup
    node_menu
}




# Function to run ZenChain Node
run_node() {
    print_info "<=========== Running ZenChain Node ==============>"

    # Check if the node name is already set
    if [ -z "$NODE_NAME" ]; then
        # Prompt for the node name
        read -p "Enter your node name: " NODE_NAME
        print_info "Node name set to: $NODE_NAME"
    else
        print_info "Node name is already set to: $NODE_NAME"
        print_info "You cannot change the node name once it is set."
        # Prompt for new node name
        read -p "Enter a new node name: " NODE_NAME
        print_info "Node name updated to: $NODE_NAME"
    fi


    print_info "Saving data to /root/chain-data/chains/priv-data.txt..."
    sed -i "/^NODE_NAME=/d" $priv_data_file  # Remove existing NODE_NAME entry
    echo "NODE_NAME=$NODE_NAME" >> $priv_data_file  # Save NODE_NAME

    # Ensure chain data directory has appropriate permissions
    if [ ! -d "$HOME/chain-data" ]; then
        mkdir -p "$HOME/chain-data"
        print_info "Created chain data directory: $HOME/chain-data"
    fi

    # Set permissions for the chain data directory
    chmod -R 777 "$HOME/chain-data"
    print_info "Set permissions for $HOME/chain-data to allow Docker access."

    # Run the ZenChain Node in Docker (production mode)
    docker run \
    -d \
    --name zenchain \
    -p 9944:9944 \
    -v "$HOME/chain-data:/chain-data" \
    ghcr.io/zenchain-protocol/zenchain-testnet:latest \
    ./usr/bin/zenchain-node \
    --base-path=/chain-data \
    --rpc-cors=all \
    --rpc-methods=unsafe \
    --unsafe-rpc-external \
    --validator \
    --name="$NODE_NAME" \
    --bootnodes=/dns4/node-7242611732906999808-0.p2p.onfinality.io/tcp/26266/p2p/12D3KooWLAH3GejHmmchsvJpwDYkvacrBeAQbJrip5oZSymx5yrE \
    --chain=zenchain_testnet

    # Check if Docker started successfully
    if [ $? -eq 0 ]; then
        print_info "ZenChain node is running successfully in Docker."
    else
        print_error "Failed to start ZenChain node in Docker."
        exit 1
    fi

    # Return to the menu after the node setup
    node_menu
}





# Function to check logs and syncing status of the ZenChain Node
sync_status() {
    print_info "<=========== Checking Node Syncing Status ==============>"

    # Use curl to call the system_health RPC method
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
        http://localhost:9944)

    # Extract the isSyncing field from the response
    is_syncing=$(echo $response | jq -r '.result.isSyncing')

    if [ "$is_syncing" == "true" ]; then
        print_info "isSyncing: true"
        print_info "Your node is still syncing."
    elif [ "$is_syncing" == "false" ]; then
        print_info "isSyncing: false"
        print_info "Your node is fully synced."
    else
        print_error "Failed to retrieve syncing status. Response: $response"
    fi

    # Call the node_menu function
    node_menu
}



# Function to create Session Keys for ZenChain Node
create_key() {
    print_info "<=========== Generating Session Keys for ZenChain Node ==============>"

    # Prompt for the ZenChain account address
    read -p "Enter your ZenChain account (address): " ZEN_ACCOUNT
    read -p "Enter your private key (without '0x', enter PRIVATE_KEY): " PRIVATE_KEY

    # Ensure the node is running before making the RPC call
    NODE_RPC_URL="http://localhost:9944"

    # Use curl to call the author_rotateKeys RPC method
    session_keys=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"author_rotateKeys","params":[],"id":1}' \
        "$NODE_RPC_URL" | jq -r '.result')

    if [ -z "$session_keys" ] || [ "$session_keys" = "null" ]; then
        print_error "Failed to generate session keys."
        exit 1
    else
        print_info "Session keys generated successfully!"
    fi

    # Update or add entries in priv-data.txt
    print_info "Saving data to $priv_data_file..."

    # Check and replace or add MY_ADDRESS
    if grep -q '^MY_ADDRESS=' "$priv_data_file"; then
        sed -i "s/^MY_ADDRESS=.*/MY_ADDRESS=$ZEN_ACCOUNT/" "$priv_data_file"
    else
        echo "MY_ADDRESS=$ZEN_ACCOUNT" >> "$priv_data_file"
    fi

    # Check and replace or add PRIVATE_KEY
    if grep -q '^PRIVATE_KEY=' "$priv_data_file"; then
        sed -i "s/^PRIVATE_KEY=.*/PRIVATE_KEY=$PRIVATE_KEY/" "$priv_data_file"
    else
        echo "PRIVATE_KEY=$PRIVATE_KEY" >> "$priv_data_file"
    fi

    # Check and replace or add SESSION_KEYS
    if grep -q '^SESSION_KEYS=' "$priv_data_file"; then
        sed -i "s/^SESSION_KEYS=.*/SESSION_KEYS=$session_keys/" "$priv_data_file"
    else
        echo "SESSION_KEYS=$session_keys" >> "$priv_data_file"
    fi

    print_info ""
    print_info "Data saved successfully."

    # Call the node_menu function
    node_menu
}






# Function to Set Keys for your ZenChain Account
zen_key() {
    # Set the RPC URL for ZenChain
    rpc_url="https://zenchain-testnet.api.onfinality.io/public"
    print_info "RPC URL set to: $rpc_url"

    # Load data from priv-data.txt
    if [ ! -f /root/chain-data/chains/priv-data.txt ]; then
        print_error "Private data file not found!"
        exit 1
    fi
    print_info "Private data file found. Loading data..."

    # Read values from the file
    source /root/chain-data/chains/priv-data.txt

    # Check if the necessary variables are set
    if [ -z "$MY_ADDRESS" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$SESSION_KEYS" ]; then
        print_error "Failed to load MY_ADDRESS, PRIVATE_KEY, or SESSION_KEYS from priv-data.txt."
        exit 1
    fi
    print_info "Loaded MY_ADDRESS, PRIVATE_KEY, and SESSION_KEYS successfully."

    # Download the zen.py file from the GitHub repository
    zen_py_url="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/zen.py"
    print_info "Downloading zen.py from: $zen_py_url"
    
    # Download zen.py using curl and save it to a local file
    curl -o zen.py "$zen_py_url"
    
    if [ ! -f "zen.py" ]; then
        print_error "Failed to download zen.py."
        exit 1
    fi
    print_info "zen.py downloaded successfully."

    # Execute zen.py with Python, passing the required variables as arguments
    print_info "Executing zen.py with the provided keys..."
    python3 zen.py "$MY_ADDRESS" "$PRIVATE_KEY" "$SESSION_KEYS" "$rpc_url"
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing zen.py"
        exit 1
    else
        print_info "zen.py executed successfully."
    fi

    # Remove zen.py after execution
    rm -f zen.py
    print_info "zen.py removed after execution."

    # Now Docker stop
    print_info "Stopping the zenchain Docker container..."
    docker stop zenchain

    # Remove docker 
    print_info "Removing the zenchain Docker container..."
    docker rm zenchain

    # Load NODE_NAME from priv-data.txt
    if grep -q '^NODE_NAME=' "$priv_data_file"; then
        NODE_NAME=$(grep '^NODE_NAME=' "$priv_data_file" | cut -d'=' -f2)
    else
        read -p "Enter your node name: " NODE_NAME
        echo "NODE_NAME=$NODE_NAME" >> "$priv_data_file"  # Save NODE_NAME
    fi

    # Restart docker 
    print_info "Restarting the zenchain Docker container..."
    docker run \
    -d \
    --name zenchain \
    -p 30333:30333 \
    -p 9944:9944 \
    -v "$HOME/chain-data:/chain-data" \
    ghcr.io/zenchain-protocol/zenchain-testnet:latest \
    ./usr/bin/zenchain-node \
    --base-path=/chain-data \
    --validator \
    --name="$NODE_NAME" \
    --bootnodes=/dns4/node-7242611732906999808-0.p2p.onfinality.io/tcp/26266/p2p/12D3KooWLAH3GejHmmchsvJpwDYkvacrBeAQbJrip5oZSymx5yrE \
    --chain=zenchain_testnet

   # Check if Docker command was successful
   if [ $? -eq 0 ]; then
      print_info "ZenChain Docker container restarted successfully."
   else
      print_error "Failed to restart ZenChain Docker container."
   fi

   
    # Call the node_menu function
    node_menu
}



# Function to check logs of the ZenChain Node running in Docker
logs_checker() {
    print_info "<=========== Checking Docker Logs for ZenChain Node ==============>"

    # Docker container name for ZenChain
    CONTAINER_NAME="zenchain"

    # Use docker logs command to retrieve logs from the specified container
    logs=$(docker logs $CONTAINER_NAME 2>&1)

    if [ $? -eq 0 ]; then
        # Display the logs
        echo "$logs"
        print_info "<=========== End of Logs ==============>"
    else
        print_error "Failed to retrieve logs for container: $CONTAINER_NAME"
        print_error "Error: $logs"
    fi

    # Call the node_menu function
    node_menu
}



# Function to stake ZCX and request validator status
staking() {
    print_info "<=========== Staking ZCX and Requesting Validator Status ==============>"

    # Prompt the user for the staking amount
    read -p "Enter the amount of ZCX to stake: " STAKE_AMOUNT

    # Validate that the user provided a stake amount
    if ! [[ "$STAKE_AMOUNT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        print_error "Invalid staking amount. Please enter a valid number."
        exit 1
    fi

    CONTRACT_ADDRESS="0x0000000000000000000000000000000000000802"  # NativeStaking contract

    # Staking transaction data (this is just an illustration, you'll need to adjust based on the actual staking method)
    print_info "Staking $STAKE_AMOUNT ZCX from account $ZEN_ACCOUNT..."

    staking_tx_hash=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{
            "to": "'$CONTRACT_ADDRESS'",
            "data": "validate()",
            "value": "'$STAKE_AMOUNT'"
        }' $ETH_RPC_URL)  # Replace with the actual endpoint for Ethereum RPC

    if [ -n "$staking_tx_hash" ]; then
        print_info "Staking transaction successful. Transaction hash: $staking_tx_hash"
    else
        print_error "Failed to stake ZCX."
        exit 1
    fi

    # Call the node_menu function
    node_menu
}




# Function to display menu and handle user input
node_menu() {
    print_info "====================================="
    print_info "  ZenChain Node Tool Menu    "
    print_info "====================================="
    print_info "Sync-Status"
    print_info "1. Install-Dependencies"
    print_info "2. Setup-Node"
    print_info "3. Run-Node"
    print_info "4. Sync-Status"
    print_info "5. Create-Key"
    print_info "6. ZenChain-Key"
    print_info "7. logs-Checker"
    print_info "8. Staking"
    print_info "9. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : CryptoBureauMaster "
    print_info "==============================="
    print_info ""  

    # Prompt the user for input
    read -p "Enter your choice (1 to 9): " user_choice
    
    # Handle user input
    case $user_choice in
        1)
            install_dependency
            ;;
        2)
            setup_node
            ;;
        3)  
            run_node
            ;;
        4)  
            sync_status
            ;;
        5)
            create_key
            ;;
        6)  
            zen_key
            ;;
        7)
            logs_checker
            ;;
        8)   
            staking
            ;;
        9)    
            print_info "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1-9"
            node_menu # Re-prompt if invalid input
            ;;
    esac
}

# Call the node_menu function
node_menu
