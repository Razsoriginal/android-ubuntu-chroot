#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# stop-ubuntu.sh - Safely unmounts kernel filesystems before device reboot
# Location in Termux: ~/stop-ubuntu.sh
# Usage: sudo bash ~/stop-ubuntu.sh (or alias: stop-ubuntu)
# =============================================================================

ROOTFS="/data/local/ubuntu"

umount -l "$ROOTFS/root/workspace" 2>/dev/null || true
umount -l "$ROOTFS/dev/pts" 2>/dev/null || true
umount -l "$ROOTFS/dev" 2>/dev/null || true
umount -l "$ROOTFS/sys" 2>/dev/null || true
umount -l "$ROOTFS/proc" 2>/dev/null || true

echo "Chroot at /data/local/ubuntu safely unmounted."
