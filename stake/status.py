import sys
from web3 import Web3

# ANSI escape codes for green text
GREEN = "\033[92m"
RESET = "\033[0m"  # Reset to default color

# Set the ZenChain RPC URL
rpc_url = "https://zenchain-testnet.api.onfinality.io/public"

# Load data from priv-data.txt
file_path = "/root/chain-data/chains/priv-data.txt"

try:
    with open(file_path, 'r') as file:
        data = file.readlines()
        MY_ADDRESS = data[0].split('=')[1].strip()
        PRIVATE_KEY = data[1].split('=')[1].strip()
        SESSION_KEYS = data[2].split('=')[1].strip()
except FileNotFoundError:
    print("Private data file not found!")
    sys.exit(1)
except IndexError:
    print("Failed to load MY_ADDRESS, PRIVATE_KEY, or SESSION_KEYS from priv-data.txt.")
    sys.exit(1)

if SESSION_KEYS.startswith("0x"):
    SESSION_KEYS = SESSION_KEYS[2:]

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(rpc_url))



# Check if connected to the ZenChain network
if not w3.is_connected():
    print('Not connected to ZenChain')
    sys.exit(1)

if not w3.is_address(MY_ADDRESS):
    print(f"Invalid address: {MY_ADDRESS}")
else:
    try:
        balance = w3.eth.get_balance(MY_ADDRESS)
        balance_in_ether = w3.from_wei(balance, 'ether')
        print(f"{GREEN}Balance for {MY_ADDRESS}: {balance_in_ether} ZCX{RESET}")
    except Exception as e:
        print(f"Error getting balance: {e}")



# Load the NativeStaking contract
native_staking_contract = '0x0000000000000000000000000000000000000800'

abi = [
    
    {
        "inputs": [
            {"internalType": "address", "name": "who", "type": "address"}
        ],
        "name": "stake",
        "outputs": [
            {"internalType": "uint256", "name": "totalStake", "type": "uint256"},
            {"internalType": "uint256", "name": "activeStake", "type": "uint256"}
        ],
        "stateMutability": "view",  # This is a read-only function
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "who", "type": "address"}
        ],
        "name": "bonded",
        "outputs": [
            {"internalType": "bool", "name": "isBonded", "type": "bool"}
        ],
        "stateMutability": "view",  # This is a read-only function
        "type": "function"
    },
    {
        "inputs": [
      {
        "internalType": "address",
        "name": "who",
        "type": "address"
      }
     ],
        "name": "status",
        "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
     ],
       "stateMutability": "view",
       "type": "function"
    },
    {
        "inputs": [],
        "name": "activeEra",
        "outputs": [
            {"internalType": "uint256", "name": "", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "historyDepth",
        "outputs": [
            {"internalType": "uint256", "name": "", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "who", "type": "address"}
        ],
        "name": "validatorStatus",
        "outputs": [
            {"internalType": "uint8", "name": "", "type": "uint8"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
]




# Contract setup
staking_contract = w3.eth.contract(address=native_staking_contract, abi=abi)

# Function to check bonded status of an account
def check_bonded(address):
    try:
        return staking_contract.functions.bonded(address).call()
    except Exception as e:
        print(f"Error checking bonded status: {e}")
        return False



def format_wei_to_zcx(wei_amount):
    # Convert from wei to ZCX (divide by 10^18)
    return wei_amount / 10**18



def check_stake(address):
    try:
        # Assuming the stake function returns a tuple (total_stake, active_stake)
        total_stake, active_stake = staking_contract.functions.stake(address).call()
        
        # Convert the stakes to ZCX
        total_stake_zcx = format_wei_to_zcx(total_stake)
        active_stake_zcx = format_wei_to_zcx(active_stake)
        
        return total_stake_zcx, active_stake_zcx
    except Exception as e:
        print(f"Error retrieving stake: {e}")
        return None, None


def get_staking_status(address):
    try:
        raw_output = staking_contract.functions.status(address).call()
        # Assuming the output is a uint256 (0 for false, non-zero for true)
        return raw_output > 0  # Non-zero means "bonded"
    except Exception as e:
        print(f"Error getting staking status: {e}")
        return None


# Function to get the active era index
def get_active_era():
    try:
        return staking_contract.functions.activeEra().call()
    except Exception as e:
        print(f"Error retrieving active era: {e}")
        return None

# Function to get the number of eras stored in history
def get_history_depth():
    try:
        return staking_contract.functions.historyDepth().call()
    except Exception as e:
        print(f"Error retrieving history depth: {e}")
        return None

def check_validator_status(address):
    try:
        status = staking_contract.functions.status(address).call()
        status_meanings = {
            0: f"{GREEN} Not staking",
            1: f"{GREEN} Nominator",
            2: f"{GREEN} Validator waiting",
            3: f"{GREEN} Validator active"
        }
        return status_meanings.get(status, f"{GREEN} Unknown status: {status}")
    except Exception as e:
        return f"{GREEN} Error retrieving status: {e}"





# Main execution
if check_bonded(MY_ADDRESS):
    print(f"{GREEN}Your bonded status is true, Your Nominator Node is connected to ZenChain Server!{RESET}")

    # Example usage
    validator_status = check_validator_status(MY_ADDRESS)
    if validator_status is not None:
        print(f"{GREEN}Validator Status: {validator_status}{RESET}")
    
    # Get and print staking status
    staking_status = get_staking_status(MY_ADDRESS)
    if staking_status is not None:
        print(f"{GREEN}Staking Status: {staking_status}{RESET}")
    
    # Get and print the active era
    active_era = get_active_era()
    if active_era is not None:
        print(f"{GREEN}Active Era Index: {active_era}{RESET}")
    
    # Get and print the history depth
    history_depth = get_history_depth()
    if history_depth is not None:
        print(f"{GREEN}History Depth (Number of Eras Stored): {history_depth}{RESET}")

    # Retrieve and print stake balance
    total_stake, active_stake = check_stake(MY_ADDRESS)
    if total_stake is not None and active_stake is not None:
        # Print the values in a human-readable format
        print(f"{GREEN}Your stake balance: Total Stake = {total_stake:.2f} ZCX, Active Stake = {active_stake:.2f} ZCX{RESET}")  

else:
    print(f"{GREEN}You are not bonded yet. Your Validator is not connected to ZenChain Server!{RESET}")
