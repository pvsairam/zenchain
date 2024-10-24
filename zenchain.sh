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



install_dependency() {
    print_info "<=========== Install Dependency ==============>"
    print_info "Updating and upgrading system packages, and installing required tools..."

    # Update the system and install essential packages
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget tar jq git 

    # Check if Docker is already installed
    if ! command -v docker &> /dev/null; then
        print_info "Docker is not installed. Installing Docker..."
        
        # Install Docker
        sudo apt install -y docker.io
        
        # Enable and start the Docker service
        sudo systemctl enable docker
        sudo systemctl start docker

        # Check for installation errors
        if [ $? -ne 0 ]; then
            print_error "Failed to install Docker. Please check your system for issues."
            exit 1
        fi
    else
        print_info "Docker is already installed."
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_info "Docker Compose is not installed. Installing Docker Compose..."
        # Install Docker Compose (replace version with the latest stable if needed)
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        print_info "Docker Compose is already installed."
    fi

    # Install Python3 and necessary dependencies from GitHub script
    print_info "Downloading and running Python installation script from GitHub..."

    # Download the script from your GitHub repository and execute it
    if curl -s https://raw.githubusercontent.com/CryptoBureau01/packages/main/python3.sh | bash; then
        print_info "Python installation script executed successfully."
    else
        print_error "Failed to run the Python installation script. Please check the link or your network connection."
        exit 1
    fi

    # Print Docker, Docker Compose, and Python versions to confirm installation
    print_info "Checking Docker version..."
    docker --version

    print_info "Checking Docker Compose version..."
    docker-compose --version

    print_info "Checking Python version..."
    python3 --version

    # Open necessary firewall port
    sudo ufw allow 30333
    
    print_info "Please Select Y to enable ufw Port system!"
    sudo ufw enable
    
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
    mkdir -p root/chain-data/chains/priv-data.txt
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
    zen_py_url="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/zen.py"
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
    python3 zen.py
    
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



# New status function  
status(){
print_info "<=========== Validator Status ZenChain Node ==============>"

    # Download the status.py file from the GitHub repository
    zen_py_url2="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/status.py"
    print_info "Downloading status.py from: $zen_py_url2"
    
    # Download status.py using curl and save it to a local file
    curl -o status.py "$zen_py_url2"
    
    if [ ! -f "status.py" ]; then
        print_error "Failed to download validator_status."
        exit 1
    fi
    print_info "status.py downloaded successfully."

    # Execute status with Python, passing the required variables as arguments
    print_info "Executing status..."
    python3 status.py 
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing status.py"
        exit 1
    else
        print_info "status.py executed successfully."
    fi

    # Remove status after execution
    rm -f status.py
    print_info "status.py removed after execution."


   # Call the node_menu function
   node_menu
   
}




nominator(){
print_info "<=========== Nominator ZenChain Node ==============>"

    # Download the nominate.py file from the GitHub repository
    zen_py_url3="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/nominate.py"
    print_info "Downloading nominate.py from: $zen_py_url3"
    
    # Download nominate.py using curl and save it to a local file
    curl -o nominate.py "$zen_py_url3"
    
    if [ ! -f "nominate.py" ]; then
        print_error "Failed to download nominate.py."
        exit 1
    fi
    print_info "nominate.py downloaded successfully."

    # Execute status with Python, passing the required variables as arguments
    print_info "Executing nominate..."
    python3 nominate.py
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing status.py"
        exit 1
    else
        print_info "nominate.py executed successfully."
    fi

    # Remove nominate after execution
    rm -f nominate.py
    print_info "nominate.py removed after execution."


   # Call the node_menu function
   node_menu
   
}





# Function to stake ZCX
staking() {
    print_info "<=========== Staking ZCX ==============>"

    # Download the stake.py file from the GitHub repository
    zen_py_url3="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/stake.py"
    print_info "Downloading stake.py from: $zen_py_url3"
    
    # Download stake.py using curl and save it to a local file
    curl -o stake.py "$zen_py_url3"
    
    if [ ! -f "stake.py" ]; then
        print_error "Failed to download stake."
        exit 1
    fi
    print_info "stake.py downloaded successfully."

    # Execute stake with Python, passing the required variables as arguments
    print_info "Executing stake..."
    python3 stake.py
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing stake.py"
        exit 1
    else
        print_info "stake.py executed successfully."
    fi

    # Remove stake.py after execution
    rm -f stake.py
    print_info "stake.py removed after execution."


   # Call the node_menu function
   node_menu
}


change_commission(){
    print_info "<=========== Change-Commission ==============>"

    # Download the stake.py file from the GitHub repository
    zen_py_url3="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/change-commission.py"
    print_info "Downloading change-commission.py from: $zen_py_url3"
    
    # Download stake.py using curl and save it to a local file
    curl -o change-commission.py "$zen_py_url3"
    
    if [ ! -f "change-commission.py" ]; then
        print_error "Failed to download change-commission."
        exit 1
    fi
    print_info "change-commission downloaded successfully."

    # Execute stake with Python, passing the required variables as arguments
    print_info "Executing change-commission..."
    python3 change-commission.py
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing change-commission"
        exit 1
    else
        print_info "change-commission executed successfully."
    fi

    # Remove change-commission after execution
    rm -f change-commission.py
    print_info "change-commission.py removed after execution."


   # Call the node_menu function
   node_menu
}


change_stake_addres(){
    print_info "<=========== Staking ZCX ==============>"

    # Download the stake.py file from the GitHub repository
    zen_py_url3="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/change-stake-addres.py"
    print_info "Downloading change-stake-addres from: $zen_py_url3"
    
    # Download change-stake-addres.py using curl and save it to a local file
    curl -o change-stake-addres.py "$zen_py_url3"
    
    if [ ! -f "change-stake-addres.py" ]; then
        print_error "Failed to download change-stake-addres.py."
        exit 1
    fi
    print_info "change-stake-addres.py downloaded successfully."

    # Execute stake with Python, passing the required variables as arguments
    print_info "Executing change-stake-addres..."
    python3 change-stake-addres.py
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing change-stake-addres.py"
        exit 1
    else
        print_info "change-stake-addres.py executed successfully."
    fi

    # Remove change-stake-addres.py after execution
    rm -f change-stake-addres.py
    print_info "stake.py removed after execution."


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
    print_info "4. Sytem-Sync-Status"
    print_info "5. Create-Key"
    print_info "6. ZenChain-Key"
    print_info "7. logs-Checker"
    print_info "8. Nominator"
    print_info "9. Status"
    print_info "10. Stake-ZCX"
    print_info "11. Change-Commission"
    print_info "12. Change-stake-Addres"
    print_info "13. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : CryptoBureauMaster "
    print_info "==============================="
    print_info ""  

    # Prompt the user for input
    read -p "Enter your choice (1 to 13): " user_choice
    
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
            nominator
            ;;
        9)  
            status
            ;;
        10)   
            staking
            ;;
        11)
            change_commission
            ;;
        12)
            change_stake_addres
            ;;
        13)
            print_info "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1-13"
            node_menu # Re-prompt if invalid input
            ;;
    esac
}

# Call the node_menu function
node_menu
