#!/bin/bash
# setup-kvm.sh: Install or uninstall KVM via Ansible

set -e

# Default action is install
ACTION="${1:-install}"

case "$ACTION" in
    install)
        STATE="present"
        ;;
    uninstall)
        STATE="absent"
        ;;
    *)
        echo "Usage: $0 [install|uninstall]"
        exit 1
        ;;
esac

ansible-playbook -i localhost, setup-kvm.yml -e "kvm_state=$STATE" --connection=local
