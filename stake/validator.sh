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


priv() {
    # Define the path for priv-data.txt
    priv_data_file="/root/chain-data/chains/priv-data.txt"

    # Create the directory for priv-data.txt if it doesn't exist
    mkdir -p /root/chain-data/chains

    # Check if the node name is already set
    if [ -z "$NODE_NAME" ]; then
        # Prompt for the node name
        read -p "Enter your node name: " NODE_NAME
        print_info "Node name set to: $NODE_NAME"
    else
        print_info "Node name is already set to: $NODE_NAME"
        print_info "You cannot change the node name once it is set."
        # Prompt for a new node name (if needed)
        read -p "Enter a new node name: " NODE_NAME
        print_info "Node name updated to: $NODE_NAME"
    fi

    print_info "Saving data to $priv_data_file..."
    
    # Remove existing NODE_NAME entry
    sed -i "/^NODE_NAME=/d" "$priv_data_file"
    echo "NODE_NAME=$NODE_NAME" >> "$priv_data_file"  # Save NODE_NAME

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
}



# Docker resetup function
resetup() {
    # Stop the zenchain Docker container
    if [ "$(docker ps -q -f name=zenchain)" ]; then
        docker stop zenchain
        print_info "Stopped zenchain Docker container."
    fi

    # Remove the zenchain Docker container
    if [ "$(docker ps -aq -f status=exited -f name=zenchain)" ]; then
        docker rm zenchain
        print_info "Removed zenchain Docker container."
    fi

    # Load data from priv-data.txt
    if [ ! -f /root/chain-data/chains/priv-data.txt ]; then
        print_error "Private data file not found!"
        exit 1
    fi
    print_info "Private data file found. Loading data..."

    # Read values from the file
    source /root/chain-data/chains/priv-data.txt

    # Check if the necessary variables are set
    missing_variables=()

    if [ -z "$NODE_NAME" ]; then
       missing_variables+=("NODE_NAME")
    fi
    if [ -z "$MY_ADDRESS" ]; then
       missing_variables+=("MY_ADDRESS")
    fi
    if [ -z "$PRIVATE_KEY" ]; then
       missing_variables+=("PRIVATE_KEY")
    fi
    if [ -z "$SESSION_KEYS" ]; then
       missing_variables+=("SESSION_KEYS")
    fi

    if [ ${#missing_variables[@]} -ne 0 ]; then
       print_error "The following variables are missing: ${missing_variables[*]}"
       print_error "Please ensure that NODE_NAME, MY_ADDRESS, PRIVATE_KEY, and SESSION_KEYS are created in priv-data.txt."
       print_info "Redirecting to the priv function to create the missing data..."
    
       priv  # Call the priv function to allow the user to create the missing data
       exit 1
    fi

    print_info "Loaded MY_ADDRESS, PRIVATE_KEY, and SESSION_KEYS successfully."

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

    # Loop until the node is fully synced
    while true; do
        # Use curl to call the system_health RPC method
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
            http://localhost:9944)

        # Extract the isSyncing field from the response
        is_syncing=$(echo "$response" | jq -r '.result.isSyncing')

        if [ "$is_syncing" == "true" ]; then
            print_info "isSyncing: true"
            print_info "Your node is still syncing."
            sleep 10 # Wait for 10 seconds before checking again
        elif [ "$is_syncing" == "false" ]; then
            print_info "isSyncing: false"
            print_info "Your node is fully synced."
            break # Exit the loop
        else
            print_error "Error: Unable to determine sync status."
            break # Exit if we cannot determine the status
        fi
    done



    
}

# Call the resetup function to execute the process
resetup


# Function to Refesh Node 
refresh_node() {
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


# New Validator register function  
validator(){
print_info "<=========== New Validator Register ZenChain Node ==============>"

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

    
    # Download the validator_register.py file from the GitHub repository
    zen_py_url1="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/validator_register.py"
    print_info "Downloading validator_register.py from: $zen_py_url1"
    
    # Download zen.py using curl and save it to a local file
    curl -o validator_register.py "$zen_py_url1"
    
    if [ ! -f "validator_register.py" ]; then
        print_error "Failed to download validator_register"
        exit 1
    fi
    print_info "validator_register downloaded successfully."

    # Execute validator_register with Python, passing the required variables as arguments
    print_info "Executing validator_register..."
    python3 validator_register.py "$MY_ADDRESS" "$PRIVATE_KEY" "$SESSION_KEYS" "$rpc_url"
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing validator_register.py"
        exit 1
    else
        print_info "validator_register.py executed successfully."
    fi

    # Remove zen.py after execution
    rm -f validator_register.py
    print_info "validator_register.py removed after execution."


   # Call the node_menu function
   node_menu
   
}




# New status function  
status(){
print_info "<=========== Validator Status ZenChain Node ==============>"

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

    
    # Download the status.py file from the GitHub repository
    zen_py_url2="https://raw.githubusercontent.com/CryptoBureau01/zenChain/main/stake/validator-status.py"
    print_info "Downloading status.py from: $zen_py_url2"
    
    # Download status.py using curl and save it to a local file
    curl -o validator-status.py "$zen_py_url2"
    
    if [ ! -f "status.py" ]; then
        print_error "Failed to download validator_status."
        exit 1
    fi
    print_info "status.py downloaded successfully."

    # Execute status with Python, passing the required variables as arguments
    print_info "Executing status..."
    python3 validator-status.py "$MY_ADDRESS" "$PRIVATE_KEY" "$SESSION_KEYS" "$rpc_url"
    
    if [ $? -ne 0 ]; then
        print_error "Error while executing status.py"
        exit 1
    else
        print_info "status.py executed successfully."
    fi

    # Remove status after execution
    rm -f validator-status.py
    print_info "status.py removed after execution."


   # Call the node_menu function
   node_menu
   
}


# Function to stake ZCX
staking() {
    print_info "<=========== Staking ZCX ==============>"

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
    python3 stake.py "$MY_ADDRESS" "$PRIVATE_KEY" "$SESSION_KEYS" "$rpc_url"
    
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




# Function to display menu and handle user input
node_menu() {
    print_info "====================================="
    print_info "  ZenChain Node Tool Menu    "
    print_info "====================================="
    print_info "Sync-Status"
    print_info "1. Node-Refesh"
    print_info "2. logs-Checker"
    print_info "3. Validator-Bonded"
    print_info "4. Status"
    print_info "5. Stake-ZCX"
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
            refresh_node
            ;;
        2)
            logs_checker
            ;;
        3)  
            validator
            ;;
        4)  
            status
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
