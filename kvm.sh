#!/bin/bash

# Configuration
INSTALL_PLAYBOOK="playbook-install.yml"
UNINSTALL_PLAYBOOK="playbook-uninstall.yml"
CONNECTION_TYPE="ssh" 
INVENTORY="inventory.ini" 
ACTION=""
IS_LOCAL=false

# Disable SSH host key validation globally for this script execution
export ANSIBLE_HOST_KEY_CHECKING=False

# Function to display usage
usage() {
  echo "Usage: $0 [--install | --uninstall] [--local]"
  echo "  --install     Run the KVM installation playbook"
  echo "  --uninstall   Run the KVM uninstallation playbook"
  echo "  --local       Run on the local machine (bypasses SSH)"
  exit 1
}

# Parse arguments
for arg in "$@"; do
  case $arg in
    --install)   ACTION="install"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --local)     IS_LOCAL=true; shift ;;
    *) ;;
  esac
done

if [ -z "$ACTION" ]; then usage; fi

# Set connection parameters
if [ "$IS_LOCAL" = true ]; then
  CONNECTION_TYPE="local"
  INVENTORY="localhost,"
  PLAYBOOK_VARS="-e kvm_hosts=localhost"
else
  CONNECTION_TYPE="ssh"
  # For remote, we verify connectivity first
  echo "--- Checking connectivity to remote hosts in $INVENTORY ---"
  if ! ansible all -i "$INVENTORY" -m ping > /dev/null 2>&1; then
    echo "ERROR: Could not reach remote hosts via SSH. Check your inventory and keys."
    exit 1
  fi
  echo "--- Connectivity OK ---"
  PLAYBOOK_VARS=""
fi

# Determine Playbook
[[ "$ACTION" == "install" ]] && PLAYBOOK=$INSTALL_PLAYBOOK || PLAYBOOK=$UNINSTALL_PLAYBOOK

echo "--- Action: $ACTION KVM ($CONNECTION_TYPE) ---"

# Run Ansible
ansible-playbook -i "$INVENTORY" \
                 -e "ansible_connection=$CONNECTION_TYPE" \
                 $PLAYBOOK_VARS \
                 "$PLAYBOOK"