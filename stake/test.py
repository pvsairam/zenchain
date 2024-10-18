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
native_staking_address = '0x0000000000000000000000000000000000000800'
native_staking_abi = [
    {
        'inputs': [
            {'internalType': 'uint256', 'name': 'value', 'type': 'uint256'},
            {'internalType': 'uint8', 'name': 'dest', 'type': 'uint8'}
        ],
        'name': 'bondWithRewardDestination',
        'outputs': [],
        'stateMutability': 'nonpayable',
        'type': 'function'
    },
    {
        'inputs': [
            {'internalType': 'uint256', 'name': 'commission', 'type': 'uint256'},
            {'internalType': 'bool', 'name': 'blocked', 'type': 'bool'}
        ],
        'name': 'validate',
        'outputs': [],
        'stateMutability': 'nonpayable',
        'type': 'function'
    },
]



staking_contract = w3.eth.contract(address=native_staking_address, abi=native_staking_abi)


def bond_tokens(stake_amount_wei, reward_destination):
    # Ensure reward_destination is an integer and matches the expected type in the contract
    bond_function = staking_contract.functions.bondWithRewardDestination(stake_amount_wei, reward_destination)
    
    # Get the nonce for the transaction
    nonce = w3.eth.get_transaction_count(MY_ADDRESS)

    # Estimate gas for the transaction
    gas_estimate = bond_function.estimateGas({'from': MY_ADDRESS})

    # Build the transaction
    transaction = bond_function.buildTransaction({
        'chainId': 8408,
        'gas': gas_estimate,
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })

    # Sign the transaction
    signed_txn = w3.eth.account.signTransaction(transaction, private_key=PRIVATE_KEY)

    # Send the transaction
    tx_hash = w3.eth.sendRawTransaction(signed_txn.rawTransaction)
    return tx_hash



def activate_stake(commission, blocked):
    # Ensure commission is converted to the appropriate type (uint256)
    validate_function = staking_contract.functions.validate(int(commission), blocked)

    # Get the nonce for the transaction
    nonce = w3.eth.get_transaction_count(MY_ADDRESS)

    # Estimate gas for the transaction
    gas_estimate = validate_function.estimateGas({'from': MY_ADDRESS})

    # Build the transaction
    transaction = validate_function.buildTransaction({
        'chainId': 8408,
        'gas': gas_estimate,
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })

    # Sign the transaction
    signed_txn = w3.eth.account.signTransaction(transaction, private_key=PRIVATE_KEY)

    # Send the transaction
    tx_hash = w3.eth.sendRawTransaction(signed_txn.rawTransaction)
    return tx_hash



# Execution for stake amount
while True:
    try:
        stake_amount = float(input("Enter the amount you want to stake (in ZCX, minimum required): "))
        if stake_amount <= 0:
            print("Please enter a valid amount greater than zero.")
        else:
            break
    except ValueError:
        print("Invalid input! Please enter a numeric value.")



# Convert stake amount to wei
stake_amount_wei = w3.to_wei(stake_amount, 'ether')

# Claim Reward Adreess
REWARD_DESTINATION = MY_ADDRESS  # or user input



# User input for reward destination
while True:
    try:
        REWARD_DESTINATION = int(input("Enter the reward destination (0 for Staked, 1 for Stash, 2 for None): "))
        if REWARD_DESTINATION not in [0, 1, 2]:
            print("Please enter a valid reward destination (0, 1, or 2).")
        else:
            break
    except ValueError:
        print("Invalid input! Please enter a numeric value.")





# Bond tokens
try:
    tx_hash = bond_tokens(stake_amount_wei, REWARD_DESTINATION)
    print(f"Staking successful! Transaction Hash: {tx_hash.hex()}")

    # Prompt user for commission rate and blocking status
    commission_rate = float(input("Enter your commission rate (in percentage): "))
    blocked = input("Do you want to block nominations? (yes/no): ").strip().lower() == 'yes'

    # Now activate your stake as a Validator
    validate_tx_hash = activate_stake(commission_rate, blocked)
    print(f"Validator activation successful! Transaction Hash: {validate_tx_hash.hex()}")

except ValueError as ve:
    print(f"Value Error: {str(ve)}")
except Exception as e:
    print(f"Error occurred: {str(e)}")
