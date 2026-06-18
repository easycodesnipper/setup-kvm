#!/bin/bash

# Configuration
INSTALL_PLAYBOOK="playbook-install.yml"
UNINSTALL_PLAYBOOK="playbook-uninstall.yml"
VFIO_PLAYBOOK="playbook-vfio.yml"
UNVFIO_PLAYBOOK="playbook-unvfio.yml"
CONNECTION_TYPE="ssh" 
INVENTORY="inventory.ini" 
ACTION=""
IS_LOCAL=false

# Disable SSH host key validation globally for this script execution
export ANSIBLE_HOST_KEY_CHECKING=False

# Function to ensure ansible-playbook is available, install if missing
ensure_ansible_installed() {
    if command -v ansible-playbook >/dev/null 2>&1; then
        return 0
    fi

    echo "ansible-playbook not found. Attempting to install ansible using pip..."

    # Determine which pip command to use
    local PIP_CMD=""
    if command -v pip3 >/dev/null 2>&1; then
        PIP_CMD="pip3"
    elif command -v pip >/dev/null 2>&1; then
        PIP_CMD="pip"
    else
        echo "ERROR: pip not found. Please install pip or ansible manually."
        exit 1
    fi

    echo "Installing ansible with: $PIP_CMD install --user ansible"
    if $PIP_CMD install --user ansible; then
        echo "Ansible installed successfully."

        # Add ~/.local/bin to PATH if not already present (for user installs)
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            export PATH="$HOME/.local/bin:$PATH"
            echo "Added ~/.local/bin to PATH for this session."
        fi

        # Refresh command cache
        hash -r

        # Verify installation
        if command -v ansible-playbook >/dev/null 2>&1; then
            return 0
        else
            echo "WARNING: ansible-playbook still not found after installation. Please ensure ~/.local/bin is in your PATH."
            exit 1
        fi
    else
        echo "ERROR: Failed to install ansible. Please install it manually (e.g., 'pip install ansible')."
        exit 1
    fi
}

# Function to display usage
usage() {
  echo "Usage: $0 [--install | --uninstall | --vfio | --unvfio] [--local]"
  echo "  --install    Run the KVM installation playbook"
  echo "  --uninstall  Run the KVM uninstallation playbook"
  echo "  --vfio       Run the VFIO PCI passthrough configuration playbook"
  echo "  --unvfio     Remove VFIO PCI passthrough configuration"
  echo "  --local      Run on the local machine (bypasses SSH)"
  exit 1
}

# Parse arguments
for arg in "$@"; do
  case $arg in
    --install)   ACTION="install"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --vfio)      ACTION="vfio"; shift ;;
    --unvfio)    ACTION="unvfio"; shift ;;
    --local)     IS_LOCAL=true; shift ;;
    *) ;;
  esac
done

if [ -z "$ACTION" ]; then usage; fi

# Ensure Ansible is installed before any further operations
ensure_ansible_installed

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
if [[ "$ACTION" == "install" ]]; then
  PLAYBOOK=$INSTALL_PLAYBOOK
elif [[ "$ACTION" == "uninstall" ]]; then
  PLAYBOOK=$UNINSTALL_PLAYBOOK
elif [[ "$ACTION" == "vfio" ]]; then
  PLAYBOOK=$VFIO_PLAYBOOK
elif [[ "$ACTION" == "unvfio" ]]; then
  PLAYBOOK=$UNVFIO_PLAYBOOK
fi

echo "--- Action: $ACTION KVM ($CONNECTION_TYPE) ---"

# Run Ansible (Added -K because modifying GRUB/modprobe requires sudo privileges)
ansible-playbook -i "$INVENTORY" \
                 -e "ansible_connection=$CONNECTION_TYPE" \
                 "$PLAYBOOK_VARS" \
                 "$PLAYBOOK"

