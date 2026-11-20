#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# start-ubuntu.sh - Mounts virtual filesystems and enters Ubuntu 24.04 chroot
# Location in Termux: ~/start-ubuntu.sh
# Usage: sudo bash ~/start-ubuntu.sh (or alias: ubuntu)
# =============================================================================

unset LD_PRELOAD
ROOTFS="/data/local/ubuntu"
SHARED_DIR="/data/local/workspace"

mkdir -p "$SHARED_DIR" "$ROOTFS/root/workspace" "$ROOTFS/tmp"
chmod 1777 "$ROOTFS/tmp"

# Ensure /data allows binary execution and suid inside chroot
mount -o remount,exec,suid,dev /data 2>/dev/null || true

# Mount kernel virtual filesystems if not already mounted
if ! mountpoint -q "$ROOTFS/proc"; then
  mount -t proc proc "$ROOTFS/proc"
  mount -t sysfs sysfs "$ROOTFS/sys"
  mount -o bind /dev "$ROOTFS/dev"
  mount -t devpts devpts "$ROOTFS/dev/pts"
fi

# Bind-mount shared workspace directory (/data/local/workspace -> /root/workspace)
if ! mountpoint -q "$ROOTFS/root/workspace"; then
  mount -o bind "$SHARED_DIR" "$ROOTFS/root/workspace"
fi

# Configure DNS resolution and localhost inside chroot
echo "nameserver 8.8.8.8" > "$ROOTFS/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$ROOTFS/etc/resolv.conf"
echo "127.0.0.1 localhost" > "$ROOTFS/etc/hosts"

# Enter chroot via su - root so supplementary GID 3003 (aid_inet) is initialized
/system/bin/chroot "$ROOTFS" /bin/bash -c "export HOME=/root TERM=xterm-256color LANG=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; exec /bin/su - root"
