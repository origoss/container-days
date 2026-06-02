#!/usr/bin/env bash
# Container Days 2026 - Calico v3.32.0 Demo Cleanup
# Run this inside: nix develop
set -euo pipefail

echo "=== Cleaning up demo environment ==="

# --- 1. Delete the kind cluster ---
echo ""
echo "1. Deleting kind cluster..."
if kind get clusters 2>/dev/null | grep -q "whisker-the-game"; then
    kind delete cluster --name whisker-the-game
    echo "Cluster deleted."
else
    echo "Cluster not found — skipping."
fi

# Truncate stale kubeconfig
: > kubeconfig
echo "kubeconfig truncated."

# --- 2. Remove the dummy network interface ---
echo ""
echo "2. Removing dummy interface..."
if ip link show whisker &>/dev/null; then
    sudo ip addr del 3.14.137.65/28 dev whisker 2>/dev/null || true
    sudo ip link del dev whisker
    echo "Interface 'whisker' removed."
else
    echo "Interface not found — skipping."
fi

# --- 3. Kill the netcat listener ---
echo ""
echo "3. Killing netcat listener..."
if pgrep -f "nc -kl 3.14.137.65" &>/dev/null; then
    sudo pkill -f "nc -kl 3.14.137.65"
    echo "Netcat listener killed."
else
    echo "Netcat listener not found — skipping."
fi

echo ""
echo "=== Cleanup complete ==="
