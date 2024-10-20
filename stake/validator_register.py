import time
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
NATIVE_STAKING_ADDRESS = '0x0000000000000000000000000000000000000800'
NATIVE_STAKING_ABI = [
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "payee",
                "type": "address"
            }
        ],
        "name": "bondWithPayeeAddress",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "name": "bonded",
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        'inputs': [{'internalType': 'uint32', 'name': 'commission', 'type': 'uint32'},
                   {'internalType': 'bool', 'name': 'blocked', 'type': 'bool'}],
        'name': 'validate',
        'outputs': [],
        'stateMutability': 'nonpayable',
        'type': 'function'
    }
]



staking_contract = w3.eth.contract(address=NATIVE_STAKING_ADDRESS, abi=NATIVE_STAKING_ABI)

chain_id = 8408

def send_transaction(func):
    nonce = w3.eth.get_transaction_count(MY_ADDRESS)
    transaction = func.build_transaction({
        'chainId': chain_id,
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })
    
    signed_txn = w3.eth.account.sign_transaction(transaction, private_key=PRIVATE_KEY)
    
    try:
        tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)
    
        # Create the explorer link using the transaction hash
        explorer_link = f"https://zentrace.io/tx/0x{tx_hash.hex()}"
        print(f"{GREEN}Transaction sent explorer Link: {explorer_link}")

        print(f"{GREEN} Now Please wait 10 second...!")
        
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        if tx_receipt['status'] == 1:
            print("Transaction successful!")
        else:
            print("Transaction failed with details:")
    except Exception as e:
        print(f"An error occurred: {e}")

    return tx_hash

  

def check_bonded(address):
    return staking_contract.functions.bonded(address).call()

def bond_with_payee_address(value, payee, commission_rate=0, blocked=False):
    # Amount ko wei mein convert karna
    value_wei = int(value * 10**18)  # 1 ZCX = 10^18 wei

    # Check if the user is already bonded (registered)
    if check_bonded(MY_ADDRESS):
        print(f"{GREEN}Address {MY_ADDRESS} is already registered as a validator.{RESET}")
    else:
        print(f"{GREEN}Address {MY_ADDRESS} is not registered. Registering now...{RESET}")
        
        # Bonding function call karna
        bond_function = staking_contract.functions.bondWithPayeeAddress(value_wei, payee)
        
        # Transaction bhejna
        try:
            tx_hash = send_transaction(bond_function)
            print(f"{GREEN}Validator Bond Transaction sent successfully. Transaction Hash: {tx_hash}{RESET}")
            
            # Time.sleep(10) ke zariye wait karna
            print(f"{GREEN}Please wait, we will prepare your next collection...{RESET}")
            time.sleep(10)
        except Exception as e:
            print(f"{GREEN}Transaction failed: {e}{RESET}")

        print(f"{GREEN}Activating as validator with {commission_rate/1000000}% commission...{RESET}")
        validate_function = staking_contract.functions.validate(commission_rate, blocked)
        try:
            tx_hash = send_transaction(validate_function)
            print(f"{GREEN}Validator Activation Transaction sent successfully. Transaction Hash: {tx_hash}{RESET}")
           
        except Exception as e:
            print(f"{GREEN}Activation transaction failed: {e}{RESET}")

# Example usage
commission_rate = 50000000  # For 5%
blocked = False
stake_amount = 2  # Amount to stake in ZCX
custom_payee_address = MY_ADDRESS  # Use the actual variable here

bond_with_payee_address(stake_amount, custom_payee_address)



