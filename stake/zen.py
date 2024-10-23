import sys
from web3 import Web3
import time


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

        # Check if the balance is less than 1 token
        if balance_in_ether < 1:
            print(f"{GREEN}You need to deposit at least 1 token to proceed.{RESET}")
            sys.exit(1)  # Exit the program if balance is less than 1 token

    except Exception as e:
        print(f"Error getting balance: {e}")


# Set the KeyManager contract address and ABI
key_manager_address = '0x0000000000000000000000000000000000000802'
abi = [{'inputs': [{'internalType': 'bytes', 'name': 'keys', 'type': 'bytes'}], 
        'name': 'setKeys', 'outputs': [], 'stateMutability': 'nonpayable', 'type': 'function'}]
contract = w3.eth.contract(address=key_manager_address, abi=abi)


# Convert the session keys from hex string to bytes
try:
    session_keys_bytes = bytes.fromhex(SESSION_KEYS)
except ValueError as e:
    print(f"Error converting session keys to bytes: {e}")
    sys.exit(1)

# Prepare the transaction
CHAIN_ID = 8408  

def send_transaction(func):
    nonce = w3.eth.get_transaction_count(MY_ADDRESS)
    # Build the transaction
    transaction = func.build_transaction({
        'chainId': CHAIN_ID,
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })

    # Sign the transaction using the private key
    signed_txn = w3.eth.account.sign_transaction(transaction, private_key=PRIVATE_KEY)

    # Send the transaction to the network
    try:
        tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)

        # Wait for the transaction receipt
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        # Output transaction details
        print(f'{GREEN}Transaction Block Number: {tx_receipt.blockNumber}')
        print(f'{GREEN}Transaction Hash: {tx_receipt.transactionHash.hex()}')

    except Exception as e:
        print(f"Error occurred while sending the transaction: {str(e)}")
        sys.exit(1)



# Call the send_transaction function to execute the contract method
try:
    send_transaction(contract.functions.setKeys(session_keys_bytes))
except Exception as e:
    print(f"Error while sending transaction: {e}")
