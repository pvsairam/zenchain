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
                "internalType": "address[]",
                "name": "targets",
                "type": "address[]"
            }
        ],
        "name": "nominate",
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
        'inputs': [{'internalType': 'uint256', 'name': 'value', 'type': 'uint256'}],
        'name': 'bondExtra',
        'outputs': [],
        'stateMutability': 'nonpayable',
        'type': 'function'
    },
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



def nominate_with_conditions():
    targets = ['0xCFE98EcE20Bf688e9B0BE7dD3f348B90A3a48127', '0xef459153B68648947B6D2863B902595e22040FfA']  # List of target validator addresses
    try:
        # Step 1: Check if the user is bonded
        is_bonded = staking_contract.functions.bonded(MY_ADDRESS).call()
        
        if is_bonded:
            print(f"You are already a nominator on Zenchain Server, {MY_ADDRESS}.")
        else:
            print(f"{GREEN}Address {MY_ADDRESS} is not registered. Registering now...{RESET}")
            
            # Bonding function call
            bond_function = staking_contract.functions.bondWithPayeeAddress(value_wei, payee)
            
            # Send bond transaction
            try:
                tx_hash = send_transaction(bond_function)
                print(f"{GREEN}Nominator bond transaction sent successfully.{RESET}")

                # Wait for 10 seconds before proceeding
                print(f"{GREEN}Please wait, preparing for nominator activation...{RESET}")
                time.sleep(10)

                # Proceed to nominate and stake 1 token
                print("Proceeding to nominate and stake...")
                send_transaction(staking_contract.functions.nominate(targets))
                send_transaction(staking_contract.functions.bondExtra(1 * 10**18))  # Staking 1 token in wei
                print(f"Nomination and 1 token stake successful for {MY_ADDRESS}.")

            except Exception as e:
                print(f"{RED}Bond transaction failed: {e}{RESET}")
                return  # Exit if the bond transaction fails

    except Exception as e:
        print(f"Error occurred: {str(e)}")

        

# Call the nominate_with_conditions function
nominate_with_conditions()
