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


# Global variable to store the node name
NODE_NAME=""



# Function to install dependencies (Rust in this case)
install_dependency() {
    print_info "<=========== Install Dependency ==============>"
    print_info "Updating and upgrading system packages, and installing curl..."
    sudo apt update && sudo apt upgrade -y && sudo apt install curl wget -y && sudo apt install -y clang libssl-dev llvm libudev-dev pkg-config protobuf-compiler make

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
    fi

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





# Function to create Session Keys for ZenChain Node
create_key() {
    print_info "<=========== Generating Session Keys for ZenChain Node ==============>"


     read -p "Enter your ZenChain account (address): " ETH_ACCOUNT
    if [ -z "$ETH_ACCOUNT" ]; then
        print_error "ZenChain account is required. Please enter a valid address."
        exit 1
    else
        print_info "ZenChain account set to: $ETH_ACCOUNT"
    fi


    # Ensure the node is running before making the RPC call
    NODE_RPC_URL="http://localhost:9944"
    
    # Use curl to call the author_rotateKeys RPC method
    session_keys=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"author_rotateKeys","params":[],"id":1}' \
        $NODE_RPC_URL | jq -r '.result')

    if [ -n "$session_keys" ]; then
        print_info "Session keys generated successfully: $session_keys"
    else
        print_error "Failed to generate session keys."
        exit 1
    fi

    # Set session keys using ZenChain account
    CONTRACT_ADDRESS="0x0000000000000000000000000000000000000802"  # KeyManager contract

    print_info "Setting session keys for ZenChain account $ETH_ACCOUNT..."

    # Use web3 or ethers.js script to call setKeys function (pseudo code for illustration)
    set_keys_tx_hash=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{
            "to": "'$CONTRACT_ADDRESS'",
            "data": "setKeys('$session_keys', '0x$ETH_ACCOUNT')" 
        }' $ETH_RPC_URL)  # Replace with the actual endpoint for Ethereum RPC

    if [ -n "$set_keys_tx_hash" ]; then
        print_info "Session keys set successfully. Transaction hash: $set_keys_tx_hash"
    else
        print_error "Failed to set session keys."
        exit 1
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
    print_info "Staking $STAKE_AMOUNT ZCX from account $ETH_ACCOUNT..."

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
    print_info ""
    print_info "1. Install-Dependencies"
    print_info "2. Setup-Node"
    print_info "3. Run-Node"
    print_info "4. Create-Key"
    print_info "5. Staking"
    print_info "6. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : CryptoBureauMaster "
    print_info "==============================="
    print_info ""  

    # Prompt the user for input
    read -p "Enter your choice (1 to 6): " user_choice
    
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
            create_key
            ;;
        5)   
            staking
            ;;
        6)    
            print_info "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1-6"
            node_menu # Re-prompt if invalid input
            ;;
    esac
}

# Call the node_menu function
node_menu
