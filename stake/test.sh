#!/bin/bash

# Function to update the /etc/apt/sources.list with provided repository entries
update_sources_list() {
    # Backup the original sources.list file before making changes
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

    echo "Updating the /etc/apt/sources.list file..."

    # Replace the existing content with the new repository entries
    sudo tee /etc/apt/sources.list <<EOF
# deb http://asi-fs-d.contabo.net/ubuntu focal main restricted

# deb http://asi-fs-d.contabo.net/ubuntu focal-updates main restricted
# deb http://security.ubuntu.com/ubuntu focal-security main restricted

# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://asi-fs-d.contabo.net/ubuntu jammy main restricted
# deb-src http://asi-fs-d.contabo.net/ubuntu focal main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb http://asi-fs-d.contabo.net/ubuntu jammy-updates main restricted
# deb-src http://asi-fs-d.contabo.net/ubuntu focal-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb http://asi-fs-d.contabo.net/ubuntu jammy universe
# deb-src http://asi-fs-d.contabo.net/ubuntu focal universe
deb http://asi-fs-d.contabo.net/ubuntu jammy-updates universe
# deb-src http://asi-fs-d.contabo.net/ubuntu focal-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb http://asi-fs-d.contabo.net/ubuntu jammy multiverse
# deb-src http://asi-fs-d.contabo.net/ubuntu focal multiverse
deb http://asi-fs-d.contabo.net/ubuntu jammy-updates multiverse
# deb-src http://asi-fs-d.contabo.net/ubuntu focal-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb http://asi-fs-d.contabo.net/ubuntu jammy-backports main restricted universe multiverse
# deb-src http://asi-fs-d.contabo.net/ubuntu focal-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu jammy-security main restricted
# deb-src http://security.ubuntu.com/ubuntu focal-security main restricted
deb http://security.ubuntu.com/ubuntu jammy-security universe
# deb-src http://security.ubuntu.com/ubuntu focal-security universe
deb http://security.ubuntu.com/ubuntu jammy-security multiverse
# deb-src http://security.ubuntu.com/ubuntu focal-security multiverse
EOF

    echo "sources.list file updated successfully."
}

# Function to update the system after modifying sources.list
update_system() {
    echo "Updating the system..."
    sudo apt-get update
    if [ $? -eq 0 ]; then
        echo "System updated successfully!"
    else
        echo "System update failed!" >&2
        exit 1
    fi
}

# Main function to execute the script
main() {
    update_sources_list
    update_system
}

# Run the script
main
