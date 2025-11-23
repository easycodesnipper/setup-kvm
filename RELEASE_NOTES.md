# Release Notes

## KVM Setup Role Updates

### 📦 Package Management Refinement
- **Optimized Dependencies**: 
  - Switched to minimal installation mode to avoid installing unnecessary recommended or weak dependencies.
  - **Debian/Ubuntu**: Uses `install_recommends: no`.
  - **RHEL/CentOS**: Uses `install_weak_deps: no`.
- **Package List Updates**:
  - **Debian**: Removed `libvirt-daemon`, `libosinfo-bin`, `libguestfs-tools`, and `cpu-checker`. Added `libvirt-clients`.
  - **RedHat**: Added `libvirt-client`.

### 🛠️ Installation Logic
- Replaced the generic `package` module with specific `apt`, `dnf`, and `yum` modules to support granular dependency control.
- Replaced `kvm-ok` verification with `virsh version` to directly verify the Libvirt/KVM stack functionality.

### 🧹 Cleanup & Maintenance
- **Uninstall Task**: Unified the uninstallation logic into a single task that dynamically uses the OS family variable.
- **Documentation**: Updated `README.md` to reflect the streamlined package lists.
