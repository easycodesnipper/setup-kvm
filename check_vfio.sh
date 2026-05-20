#!/usr/bin/env bash
# =============================================================================
# check_vfio.sh — Comprehensive VFIO / IOMMU / GPU Passthrough Health Check
# =============================================================================
set -euo pipefail

PASS="✅"
FAIL="❌"
WARN="⚠️ "
INFO="ℹ️ "

section() { echo ""; echo "══════════════════════════════════════════════════"; echo "  $1"; echo "══════════════════════════════════════════════════"; }
ok()      { echo "  $PASS $*"; }
fail()    { echo "  $FAIL $*"; }
warn()    { echo "  $WARN $*"; }
info()    { echo "  $INFO $*"; }

echo ""
echo "  VFIO / IOMMU / GPU Passthrough Health Check"
echo "  Date: $(date)"

# ── 1. Kernel Boot Parameters ─────────────────────────────────────────────────
section "1. Kernel Boot Parameters"
cmdline=$(cat /proc/cmdline)
info "Full cmdline: $cmdline"
echo ""

check_param() {
  local param="$1"
  if echo "$cmdline" | grep -q "$param"; then
    ok "$param is set"
  else
    fail "$param is NOT set in kernel cmdline"
  fi
}

# Detect CPU vendor
if grep -q "vmx" /proc/cpuinfo 2>/dev/null; then
  CPU_VENDOR="intel"
  check_param "intel_iommu=on"
elif grep -q "svm" /proc/cpuinfo 2>/dev/null; then
  CPU_VENDOR="amd"
  check_param "amd_iommu=on"
else
  warn "Could not detect CPU vendor (intel/amd)"
  CPU_VENDOR="unknown"
fi

check_param "iommu=pt"

if echo "$cmdline" | grep -q "vfio-pci.ids="; then
  ids=$(echo "$cmdline" | grep -oP 'vfio-pci\.ids=\S+')
  ok "vfio-pci.ids specified: $ids"
else
  warn "vfio-pci.ids not in cmdline (may use modprobe or udev binding instead)"
fi

# ── 2. IOMMU Status ───────────────────────────────────────────────────────────
section "2. IOMMU Status"
if [ -d /sys/class/iommu ] && ls /sys/class/iommu/ 2>/dev/null | grep -q .; then
  ok "IOMMU is active. Groups found:"
  ls /sys/class/iommu/ | while read g; do echo "    - $g"; done
else
  fail "IOMMU does not appear to be active (/sys/class/iommu is empty)"
fi

iommu_group_count=$(find /sys/kernel/iommu_groups -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
if [ "$iommu_group_count" -gt 0 ]; then
  ok "$iommu_group_count IOMMU groups found"
else
  fail "No IOMMU groups found under /sys/kernel/iommu_groups"
fi

# ── 3. VFIO Kernel Modules ────────────────────────────────────────────────────
section "3. VFIO Kernel Modules"
for mod in vfio vfio_pci vfio_pci_core vfio_iommu_type1; do
  if lsmod | grep -q "^${mod}"; then
    ok "Module loaded: $mod"
  else
    fail "Module NOT loaded: $mod"
  fi
done

# ── 4. GPU / PCI Device Binding ───────────────────────────────────────────────
section "4. PCI Device Driver Binding"
echo ""
echo "  GPU / Display Controllers:"
lspci -nnk | grep -iA 4 'vga\|3d\|display' | sed 's/^/    /'
echo ""

echo "  All devices bound to vfio-pci:"
found_vfio=0
for dev in /sys/bus/pci/devices/*; do
  driver_link="$dev/driver"
  if [ -L "$driver_link" ]; then
    driver=$(basename "$(readlink "$driver_link")")
    if [ "$driver" = "vfio-pci" ]; then
      addr=$(basename "$dev")
      pci_info=$(lspci -s "$addr" 2>/dev/null || echo "(unknown)")
      ok "$addr — $pci_info"
      found_vfio=1
    fi
  fi
done
[ "$found_vfio" -eq 0 ] && fail "No devices currently bound to vfio-pci"

# ── 5. IOMMU Groups for vfio-pci devices ─────────────────────────────────────
section "5. IOMMU Groups for vfio-pci Bound Devices"
for dev in /sys/bus/pci/devices/*; do
  driver_link="$dev/driver"
  if [ -L "$driver_link" ]; then
    driver=$(basename "$(readlink "$driver_link")")
    if [ "$driver" = "vfio-pci" ]; then
      addr=$(basename "$dev")
      group_link="$dev/iommu_group"
      if [ -L "$group_link" ]; then
        group=$(basename "$(readlink "$group_link")")
        info "$addr is in IOMMU group: $group"
        echo "    Members of group $group:"
        ls /sys/kernel/iommu_groups/$group/devices/ 2>/dev/null | while read m; do
          echo "      - $m $(lspci -s $m 2>/dev/null | cut -d' ' -f2-)"
        done
      else
        warn "$addr has no IOMMU group"
      fi
    fi
  fi
done

# ── 6. /dev/vfio entries ──────────────────────────────────────────────────────
section "6. /dev/vfio Device Nodes"
if ls /dev/vfio/ 2>/dev/null | grep -q .; then
  ok "/dev/vfio entries:"
  ls -la /dev/vfio/ | sed 's/^/    /'
else
  fail "No /dev/vfio entries found"
fi

# ── 7. GRUB / Boot Configuration ─────────────────────────────────────────────
section "7. GRUB / Boot Configuration Source"
if [ -f /etc/default/grub.d/99-vfio.cfg ]; then
  ok "Found /etc/default/grub.d/99-vfio.cfg:"
  cat /etc/default/grub.d/99-vfio.cfg | sed 's/^/    /'
elif grep -r "iommu\|vfio" /etc/default/grub 2>/dev/null | grep -q .; then
  ok "IOMMU/VFIO params found in /etc/default/grub:"
  grep "iommu\|vfio" /etc/default/grub | sed 's/^/    /'
else
  warn "No VFIO-related GRUB config found in /etc/default/grub or /etc/default/grub.d/"
fi

# ── 8. modprobe config ────────────────────────────────────────────────────────
section "8. modprobe Configuration"
for f in /etc/modprobe.d/vfio*.conf /etc/modprobe.d/kvm*.conf; do
  if [ -f "$f" ]; then
    ok "Found $f:"
    cat "$f" | sed 's/^/    /'
  fi
done
ls /etc/modprobe.d/ | grep -iE 'vfio|kvm' | grep -q . || warn "No vfio/kvm modprobe config files found"

# ── Summary ───────────────────────────────────────────────────────────────────
section "Check Complete"
echo "  Run this script with: sudo bash check_vfio.sh"
echo ""
