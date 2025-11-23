# Ansible KVM Setup

This Ansible project automates the installation and configuration of KVM (Kernel-based Virtual Machine) on both Debian-based and Red Hat-based Linux distributions.

## Features

- ✅ Supports Debian-based systems (Debian, Ubuntu)
- ✅ Supports Red Hat-based systems (RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux)
- ✅ Automatic CPU virtualization detection
- ✅ Installs all necessary KVM and libvirt packages
- ✅ Configures user permissions for KVM access
- ✅ Optional nested virtualization support
- ✅ SELinux configuration for Red Hat systems
- ✅ Clean uninstallation support

## Prerequisites

- Ansible 2.9 or higher
- Target systems must support hardware virtualization (Intel VT-x or AMD-V)
- SSH access to target hosts with sudo privileges
- Python 3 installed on target hosts

## Project Structure

```
setup-kvm/
├── .ansible-lint                    # Ansible lint configuration
├── .gitignore                       # Git ignore file
├── inventory.ini                    # Inventory file
├── playbook-install.yml             # Installation playbook
├── playbook-uninstall.yml           # Uninstallation playbook
├── group_vars/
│   └── all.yml                      # Variables for all hosts
├── roles/
│   └── kvm/
│       ├── defaults/
│       │   └── main.yml             # Default variables
│       ├── tasks/
│       │   ├── install.yml          # Installation tasks
│       │   └── uninstall.yml        # Uninstallation tasks
│       └── handlers/
│           └── main.yml             # Handlers
└── README.md
```

## Quick Start

### 1. Configure Inventory

Edit `inventory.ini` and add your target hosts:

```ini
[kvm_hosts]
server1 ansible_host=192.168.1.10 ansible_user=admin
server2 ansible_host=192.168.1.11 ansible_user=admin

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
```

### 2. Run the Playbook

```bash
# Test connectivity
ansible kvm_hosts -m ping

# Install KVM
ansible-playbook playbook-install.yml

# Uninstall KVM
ansible-playbook playbook-uninstall.yml

# Run with verbose output
ansible-playbook playbook-install.yml -v

# Run with check mode (dry-run)
ansible-playbook playbook-install.yml --check
```

### 3. Verify Installation

After the playbook completes, verify KVM is working:

```bash
# On Debian/Ubuntu
sudo kvm-ok

# On all systems
virsh version
virsh list --all
```

## Configuration Options

### Variables Location

Variables can be configured in two places:
- `group_vars/all.yml` - Variables for all hosts (packages, user groups)
- `roles/kvm/defaults/main.yml` - Default role variables (nested virtualization)

### Enable Nested Virtualization

Edit `roles/kvm/defaults/main.yml` and set:

```yaml
kvm_enable_nested_virtualization: true
```

Or pass it as an extra variable:

```bash
ansible-playbook playbook-install.yml -e "kvm_enable_nested_virtualization=true"
```

### Custom Package Lists

The `kvm_packages` variable in `group_vars/all.yml` is organized by OS family:

```yaml
kvm_packages:
  Debian:
    - qemu-kvm
    - libvirt-daemon-system
    - libvirt-clients
    - bridge-utils
    - virtinst
    - virt-manager
    - cpu-checker
  RedHat:
    - qemu-kvm
    - libvirt
    - libvirt-client
    - virt-install
    - virt-manager
    - virt-viewer
    - bridge-utils
```

### User Groups

Configure which groups users should be added to for KVM access:

```yaml
kvm_user_groups:
  - libvirt
  - kvm
```

## Supported Operating Systems

### Debian-based
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)

### Red Hat-based
- RHEL 8/9
- CentOS Stream 8/9
- Rocky Linux 8/9
- AlmaLinux 8/9
- Fedora 38/39/40

## What Gets Installed

### Debian/Ubuntu Packages
- `qemu-kvm` - KVM hypervisor
- `libvirt-daemon-system` - Libvirt daemon
- `libvirt-clients` - Libvirt client tools
- `bridge-utils` - Network bridge utilities
- `virtinst` - Virtual machine installation tools
- `virt-manager` - Virtual machine manager GUI
- `cpu-checker` - CPU virtualization checker

### RHEL/CentOS/Fedora Packages
- `qemu-kvm` - KVM hypervisor
- `libvirt` - Libvirt virtualization API
- `libvirt-client` - Libvirt client tools
- `virt-install` - Virtual machine installation tool
- `virt-manager` - Virtual machine manager GUI
- `virt-viewer` - Virtual machine viewer
- `bridge-utils` - Network bridge utilities

## Post-Installation

After running the playbook:

1. **Log out and log back in** for group membership changes to take effect
2. **Verify virtualization support**: `egrep -c '(vmx|svm)' /proc/cpuinfo` (should return > 0)
3. **Check libvirt status**: `sudo systemctl status libvirtd`
4. **Test virsh access**: `virsh list --all`

## Uninstallation

To completely remove KVM from your system:

```bash
ansible-playbook playbook-uninstall.yml
```

This will:
- Stop and disable the libvirt service
- Remove all KVM packages
- Remove nested virtualization configuration
- Unload KVM kernel modules
- Remove users from KVM groups
- Clean up configuration files

**Note**: You may need to reboot the system after uninstallation.

## Creating Your First VM

```bash
# Download a cloud image (example: Ubuntu)
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Create a VM
virt-install \
  --name test-vm \
  --memory 2048 \
  --vcpus 2 \
  --disk jammy-server-cloudimg-amd64.img \
  --import \
  --os-variant ubuntu22.04 \
  --network default \
  --graphics none \
  --console pty,target_type=serial
```

## Troubleshooting

### CPU doesn't support virtualization
- Enable VT-x (Intel) or AMD-V (AMD) in your BIOS/UEFI settings
- If running in a VM, ensure nested virtualization is enabled on the host

### Permission denied errors
- Ensure your user is in the `libvirt` and `kvm` groups
- Log out and log back in after running the playbook
- Check group membership: `groups`

### SELinux issues (Red Hat systems)
- The playbook automatically configures SELinux for libvirt
- If issues persist, check: `sudo ausearch -m avc -ts recent`
- Verify SELinux booleans: `getsebool -a | grep virt`

### Service won't start
```bash
# Check service status
sudo systemctl status libvirtd

# Check logs
sudo journalctl -u libvirtd -n 50

# Restart service
sudo systemctl restart libvirtd
```

### Ansible Lint

This project includes an `.ansible-lint` configuration file. To run linting:

```bash
ansible-lint
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


