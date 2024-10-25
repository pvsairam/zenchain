
# ZenChain Node Auto Tool

In today’s rapidly evolving blockchain landscape, ZenChain emerges as a groundbreaking Layer 1 solution, designed to set new standards in cross-chain interoperability. Zenchain envisions seamless, trust-minimized interactions across ecosystems for Bitcoin, Ethereum, and beyond.

## System Requirements

| **Hardware** | **Minimum Requirement** |
|--------------|-------------------------|
| **CPU**      | 4 Cores                 |
| **RAM**      | 8 GB                    |
| **Disk**     | 50 GB                   |
| **Bandwidth**| 50 MBit/s               |

## Tool Installation Command

To install the necessary tools for managing your ZenChain node, run the following command in your terminal:

```bash

 cd $HOME && wget https://raw.githubusercontent.com/pvsairam/zenchain/main/zenchain.sh && chmod +x zenchain.sh && ./zenchain.sh
```


## Script Summary

This script is a Bash-Auto tool designed to facilitate the setup and management of a ZenChain node. Below, you will find a detailed description of its functionalities.

### Key Features:

1. **Initialization**:
   - Downloads and executes an external script for setup.
   - Pauses the script for a brief period to ensure readiness.

2. **Utility Functions**:
   - `print_info()` and `print_error()`: Functions for formatted output, displaying messages in green for info and red for errors.

3. **Dependency Installation**:
   - Checks and installs necessary system packages such as `curl`, `wget`, `docker`, and Python and its packages.
   - Ensures Docker is installed or installs it if not.

4. **Node Setup**:
   - Pulls the latest ZenChain Docker image and sets up the node environment.
   - Prompts user for node name and creates necessary directories to store chain data.

5. **Node Management**:
   - Interact with the running Docker container that hosts the ZenChain node.
   - Includes functions to run the node, check syncing status, create session keys, and set keys for the ZenChain account.

6. **Validator Functions**:
   - Functions to register a new validator, check validator status, and stake ZCX tokens.
   - Each function also involves downloading specific Python scripts to execute relevant actions.

7. **Logging**:
   - Provides an option to check logs of the ZenChain node running in Docker.

8. **User Interaction**:
   - A simple menu system that allows users to select various actions to perform.

9. **Exit Handling**:
   - Includes an exit option, prompting a clean exit from the script.
  


# Error Handling && Interactive Prompt
1. **Interactive Prompt**:  
   The `while true` loop keeps the script running until the user selects the "Exit" option (Option 11).  
   For each selection, the script displays relevant information and calls the corresponding function to perform the action.

2. **Error Handling**:  
   If an invalid option is chosen, the script prompts the user to enter a valid number (between 1 and 11).



# Conclusion
This Auto Script for Node Management on the ZenChain has been created by CryptoBuroMaster. It is a comprehensive solution designed to simplify and enhance the node management experience. By providing a clear and organized interface, it allows users to efficiently manage their nodes with ease. Whether you are a newcomer or an experienced user, this script empowers you to handle node operations seamlessly, ensuring that you can focus on what truly matters in your blockchain journey.


**Join our TG : https://t.me/CryptoBureau01**
