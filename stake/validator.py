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
            {"internalType": "uint256", "name": "commission", "type": "uint256"},
            {"internalType": "bool", "name": "blocked", "type": "bool"}
        ],
        "name": "validate",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
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
    }
]




staking_contract = w3.eth.contract(address=native_staking_contract, abi=abi)

# Prepare the transaction
nonce = w3.eth.get_transaction_count(MY_ADDRESS)


# Function to check bonded status of an account
def check_bonded(address):
    return staking_contract.functions.bonded(address).call()

# Function to check the total and active stake of an account
def check_stake(address):
    total_stake, active_stake = staking_contract.functions.stake(address).call()
    return total_stake, active_stake


def declare_validator(commission_wei, blocked):
    try:
        # Create the transaction for the validate function
        txn = staking_contract.functions.validate(commission_wei, blocked).build_transaction({
            'chainId': 8408,  # Make sure the chain ID is correct for your network
            'gas': 2000000,   # Set a reasonable gas limit
            'gasPrice': w3.eth.gas_price,
            'nonce': nonce,   # Nonce should be the next available transaction number
        })

        # Sign the transaction
        signed_txn = w3.eth.account.sign_transaction(txn, PRIVATE_KEY)

        # Send the transaction
        tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)

        # Wait for the transaction receipt
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        print(f"Validator declaration successful! Transaction Hash: {tx_receipt.transactionHash.hex()}")

    except Exception as e:
        print(f"Error during validator declaration: {str(e)}")
        raise


# Check if the user is bonded
is_bonded = check_bonded(MY_ADDRESS)

if is_bonded:
    print(f"{GREEN}Your status is true, you are already bonded!{RESET}")
    
    # Retrieve and print stake balance
    total_stake, active_stake = check_stake(MY_ADDRESS)
    print(f"{GREEN}Your stake balance: Total Stake = {total_stake}, Active Stake = {active_stake}{RESET}")

else:
    # Example of declaring validator with 15% commission and not blocked
    commission_wei = 70_000_000_000_000_000   # 7% commission in Wei format (adjust for decimals if needed)
    blocked = False  # Assuming False for 'blocked' status

    # Call the function to declare validator
    declare_validator(commission_wei, blocked)
