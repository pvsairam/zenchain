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

abi = [{'inputs': [{'internalType': 'uint256', 'name': 'value', 'type': 'uint256'}, {'internalType': 'uint8', 'name': 'dest', 'type': 'uint8'} ], 
        'name': 'bondWithRewardDestination', 'outputs': [], 'stateMutability': 'nonpayable', 'type': 'function'}]


staking_contract = w3.eth.contract(address=native_staking_contract, abi=abi)


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


print(f"Stake Amount: {stake_amount_wei}")



# User input for reward destination
while True:
    try:
        reward_destination = int(input("Enter the reward destination (0 for Staked, 1 for Stash, 2 for None): "))
        if reward_destination not in [0, 1, 2]:
            print("Please enter a valid Reward Destination (0, 1, or 2).")
        else:
            break
    except ValueError:
        print("Invalid input! Please enter a numeric value.")


print(f"Reward Destination: {reward_destination}")




def bond_tokens(stake_amount_wei, reward_destination):
    # Create the transaction dictionary directly without a function object
    txn = staking_contract.functions.bondWithRewardDestination(stake_amount_wei, reward_destination).buildTransaction({
        'chainId': 8408,
        'gas': 2000000,  # Set a reasonable gas limit
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })

    # Sign the transaction using the private key
    signed_txn = w3.eth.account.sign_transaction(txn, PRIVATE_KEY)

    try:
        # Send the signed transaction
        tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)  # Corrected attribute

        # Wait for the transaction receipt
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        # Return the transaction receipt for further use
        return tx_receipt

    except Exception as e:
        print(f"Error during bonding tokens: {str(e)}")
        raise

# Bond tokens
try:
    # Call the bond_tokens function and get the receipt
    tx_receipt = bond_tokens(stake_amount_wei, reward_destination)

    # Output transaction details
    print(f"Staking successful! Transaction Hash: {tx_receipt.transactionHash.hex()}")

except ValueError as ve:
    print(f"Value Error: {str(ve)}")
except Exception as e:
    print(f"Error occurred: {str(e)}")

















