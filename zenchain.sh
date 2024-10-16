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
    
    # Clone the repository and navigate to the directory
    git clone https://github.com/zenchain-protocol/zenchain-node.git
    if [ $? -eq 0 ]; then
        print_info "ZenChain repository cloned successfully."
    else
        print_error "Failed to clone the ZenChain repository."
        exit 1
    fi

    cd ./zenchain-node
    if [ $? -eq 0 ]; then
        print_info "Navigated to zenchain-node directory successfully."
    else
        print_error "Failed to navigate to zenchain-node directory."
        exit 1
    fi

    # Build the node for development
    print_info "Building the ZenChain node for development..."
    cargo build --release
    if [ $? -eq 0 ]; then
        print_info "Development build completed successfully."
    else
        print_error "Failed to build for development."
        exit 1
    fi

    # Build the node for production
    print_info "Building the ZenChain node for production..."
    cargo build --profile=production
    if [ $? -eq 0 ]; then
        print_info "Production build completed successfully."
    else
        print_error "Failed to build for production."
        exit 1
    fi

    print_info "ZenChain Node setup completed."

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

    # Build the command for running the node
    command="./target/production/zenchain-node \
    --base-path=/chain-data \
    --rpc-cors=all \
    --unsafe-rpc-external \
    --validator \
    --name=\"$NODE_NAME\" \
    --bootnodes=/dns4/node-7242611732906999808-0.p2p.onfinality.io/tcp/26266/p2p/12D3KooWLAH3GejHmmchsvJpwDYkvacrBeAQbJrip5oZSymx5yrE \
    --chain=zenchain_testnet"

    # Run the node
    print_info "Starting the ZenChain node with the following command:"
    echo "$command"
    
    eval "$command"
    if [ $? -eq 0 ]; then
        print_info "ZenChain node is running successfully."
    else
        print_error "Failed to start ZenChain node."
        exit 1
    fi
}






# Function to display menu and handle user input
node_menu() {
    print_info "====================================="
    print_info "  ZenChain Node Tool Menu    "
    print_info "====================================="
    print_info ""
    print_info "1. Install-Dependencies"
    print_info "2. Setup-Node"
    print_info "3. Run-Nodet"
    print_info "4. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : CryptoBureauMaster "
    print_info "==============================="
    print_info ""  

    # Prompt the user for input
    read -p "Enter your choice (1 to 4): " user_choice
    
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
            print_info "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1, 2, or 3."
            node_menu # Re-prompt if invalid input
            ;;
    esac
}

# Call the node_menu function
node_menu
