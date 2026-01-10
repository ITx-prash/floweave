#!/usr/bin/env bash

echo "=== Floweave Dependency Uninstaller ==="

echo "[1/4] Removing x11vnc..."
sudo apt remove -y x11vnc

echo "[2/4] Purging x11vnc configuration..."
sudo apt purge -y x11vnc

echo "[3/4] Removing x11-xserver-utils (contains xrandr)..."
sudo apt remove -y x11-xserver-utils

echo "[4/4] Purging x11-xserver-utils configuration..."
sudo apt purge -y x11-xserver-utils

echo "Running autoremove to clean unused dependencies..."
sudo apt autoremove -y

echo "=== Completed ==="
echo "x11vnc and x11-xserver-utils have been fully removed."
echo "You can now test Floweave's initial setup."

