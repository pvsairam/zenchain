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
        # Parse the data for MY_ADDRESS, PRIVATE_KEY, and SESSION_KEYS
        MY_ADDRESS = data[0].split('=')[1].strip()
        PRIVATE_KEY = data[1].split('=')[1].strip()
        SESSION_KEYS = data[2].split('=')[1].strip()
except FileNotFoundError:
    print("Private data file not found!")
    sys.exit(1)
except IndexError:
    print("Failed to load MY_ADDRESS, PRIVATE_KEY, or SESSION_KEYS from priv-data.txt.")
    sys.exit(1)

# Ensure the session keys don't have the "0x" prefix
if SESSION_KEYS.startswith("0x"):
    SESSION_KEYS = SESSION_KEYS[2:]

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(rpc_url))

# Check if connected to the ZenChain network
if not w3.is_connected():
    print('Not connected to ZenChain')
    sys.exit(1)

# Set the KeyManager contract address and ABI
key_manager_address = '0x0000000000000000000000000000000000000803'
abi = [{'inputs': [{'internalType': 'bytes', 'name': 'keys', 'type': 'bytes'}], 
        'name': 'setKeys', 'outputs': [], 'stateMutability': 'nonpayable', 'type': 'function'}]
contract = w3.eth.contract(address=key_manager_address, abi=abi)
