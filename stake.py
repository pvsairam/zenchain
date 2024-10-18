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

# Set the NativeStaking contract address and ABI
native_staking_address = '0x0000000000000000000000000000000000000800'  # Ensure this is correct
native_staking_abi = [
    {
        'inputs': [{'internalType': 'uint256', 'name': 'value', 'type': 'uint256'},
                   {'internalType': 'address', 'name': 'dest', 'type': 'address'}],
        'name': 'bondWithRewardDestination',
        'outputs': [],
        'stateMutability': 'nonpayable',
        'type': 'function'
    }
]

# Contract ko instantiate karna
staking_contract = w3.eth.contract(address=native_staking_address, abi=native_staking_abi)

# Bond karne ke liye function ka call karna
def bond_tokens(value, destination, from_address, private_key):
    nonce = w3.eth.getTransactionCount(from_address)
    tx = staking_contract.functions.bondWithRewardDestination(value, destination).buildTransaction({
        'chainId': 8408,  # ZenChain Testnet chain ID
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })

    # Transaction ko sign karna
    signed_tx = w3.eth.account.signTransaction(tx, private_key)
    tx_hash = w3.eth.sendRawTransaction(signed_tx.rawTransaction)
    return tx_hash

# Minimum staking amount
MIN_STAKE_AMOUNT = 0.1  # in ZCX

# User se staking amount lena
try:
    stake_amount = float(input(f"{GREEN}Enter the amount you want to stake (in ZCX): {RESET}"))

    # Minimum staking check
    if stake_amount < MIN_STAKE_AMOUNT:
        print(f"{GREEN}Please enter at least {MIN_STAKE_AMOUNT} ZCX tokens for staking.{RESET}")
    else:
        # Staking amount ko Wei mein convert karein
        stake_amount_wei = w3.toWei(stake_amount, 'ether') # Assuming ZCX is equivalent to Ether for conversion purpose.

        # Bond tokens function call karein
        tx_hash = bond_tokens(stake_amount_wei, MY_ADDRESS, MY_ADDRESS, PRIVATE_KEY)  # Use MY_ADDRESS for destination
        print(f"{GREEN}Staking successful! Transaction Hash: {tx_hash.hex()}{RESET}")

except ValueError:
    print("Invalid input! Please enter a valid amount.")
