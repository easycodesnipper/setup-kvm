#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " SR-IOV Physical Function (PF) / Virtual Function (VF) Check"
echo " Date: $(date)"
echo "============================================"
echo ""

# ── 1. PFs with SR-IOV capability ─────────────────────────────────────────────
echo "[ 1/4 ] Physical Functions (PFs) with SR-IOV support:"
echo "------------------------------------------------------"
found_pf=0
for f in /sys/bus/pci/devices/*/sriov_totalvfs; do
  [ -f "$f" ] || continue
  total=$(cat "$f")
  [ "$total" -gt 0 ] || continue
  dir=$(dirname "$f")
  addr=$(basename "$dir")
  numvfs=$(cat "$dir/sriov_numvfs")
  found_pf=1
  echo "  PF: $addr | total_vfs=$total | enabled_vfs=$numvfs"
  lspci -s "$addr" 2>/dev/null || echo "    (lspci info unavailable)"
done
[ "$found_pf" -eq 0 ] && echo "  (No SR-IOV capable PFs found)"
echo ""

# ── 2. Active VFs and their parent PFs ────────────────────────────────────────
echo "[ 2/4 ] Active Virtual Functions (VFs) and their parent PFs:"
echo "-------------------------------------------------------------"
found_vf=0
for physfn_link in /sys/bus/pci/devices/*/physfn; do
  [ -L "$physfn_link" ] || continue
  vf_addr=$(dirname "$physfn_link" | xargs basename)
  pf_addr=$(readlink "$physfn_link" | xargs basename)
  found_vf=1
  echo "  VF: $vf_addr  ->  PF: $pf_addr"
done
[ "$found_vf" -eq 0 ] && echo "  (No active VFs found)"
echo ""

# ── 3. NVIDIA GPU status (VFIO / driver binding) ──────────────────────────────
echo "[ 3/4 ] NVIDIA GPU PCI device status:"
echo "--------------------------------------"
lspci -nnk | grep -iA 4 'nvidia' || echo "  (No NVIDIA devices found)"
echo ""

# ── 4. VFIO modules loaded ────────────────────────────────────────────────────
echo "[ 4/4 ] VFIO kernel modules:"
echo "-----------------------------"
lsmod | grep vfio || echo "  (No VFIO modules loaded)"
echo ""

echo "============================================"
echo " Check complete."
echo "============================================"
