#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# setup-all.sh - Automated Native Ubuntu 24.04 ARM64 Chroot Installer for Android
# Run inside a standard (non-root) Termux session: bash setup-all.sh
# =============================================================================
set -e

echo "==> [1/5] Installing required Termux host utilities..."
pkg update && pkg upgrade -y
pkg install -y tsu curl tar git openssh

echo "==> [2/5] Disabling Android Phantom Process Killer (requires root)..."
su -c "/system/bin/device_config set_sync_disabled_for_tests persistent" 2>/dev/null || true
su -c "/system/bin/device_config put activity_manager max_phantom_processes 2147483647" 2>/dev/null || true
su -c "settings put global settings_enable_monitor_phantom_procs false" 2>/dev/null || true

echo "==> [3/5] Installing ~/start-ubuntu.sh, ~/stop-ubuntu.sh & shell aliases..."
cat << 'LAUNCH_EOF' > ~/start-ubuntu.sh
#!/data/data/com.termux/files/usr/bin/bash
# Launch native Ubuntu 24.04 ARM64 chroot
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
LAUNCH_EOF
chmod +x ~/start-ubuntu.sh

cat << 'STOP_EOF' > ~/stop-ubuntu.sh
#!/data/data/com.termux/files/usr/bin/bash
# Safely unmount Ubuntu chroot virtual filesystems before rebooting
ROOTFS="/data/local/ubuntu"

umount -l "$ROOTFS/root/workspace" 2>/dev/null || true
umount -l "$ROOTFS/dev/pts" 2>/dev/null || true
umount -l "$ROOTFS/dev" 2>/dev/null || true
umount -l "$ROOTFS/sys" 2>/dev/null || true
umount -l "$ROOTFS/proc" 2>/dev/null || true

echo "Chroot at /data/local/ubuntu safely unmounted."
STOP_EOF
chmod +x ~/stop-ubuntu.sh

if ! grep -q "alias ubuntu=" ~/.bashrc 2>/dev/null; then
  cat << 'ALIAS_EOF' >> ~/.bashrc
alias ubuntu='sudo bash ~/start-ubuntu.sh'
alias stop-ubuntu='sudo bash ~/stop-ubuntu.sh'
ALIAS_EOF
fi

echo "==> [4/5] Downloading & verifying Ubuntu 24.04.4 LTS ARM64 rootfs..."
su -c '
unset LD_PRELOAD
ROOTFS="/data/local/ubuntu"
SHARED_DIR="/data/local/workspace"
TERMUX_BIN="/data/data/com.termux/files/usr/bin"

if [ ! -x "$ROOTFS/usr/bin/env" ] || [ ! -e "$ROOTFS/lib/ld-linux-aarch64.so.1" ]; then
  echo "Extracting clean Ubuntu 24.04.4 ARM64 rootfs into $ROOTFS..."
  umount -l "$ROOTFS/root/workspace" 2>/dev/null || true
  umount -l "$ROOTFS/dev/pts" 2>/dev/null || true
  umount -l "$ROOTFS/dev" 2>/dev/null || true
  umount -l "$ROOTFS/sys" 2>/dev/null || true
  umount -l "$ROOTFS/proc" 2>/dev/null || true

  rm -rf "$ROOTFS"
  mkdir -p "$ROOTFS"
  cd "$ROOTFS"
  "$TERMUX_BIN/curl" -fL "https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz" -o ubuntu.tar.gz
  "$TERMUX_BIN/tar" -xzf ubuntu.tar.gz --numeric-owner -C "$ROOTFS"
  rm -f ubuntu.tar.gz
  echo "Ubuntu rootfs extraction complete!"
fi

mkdir -p "$SHARED_DIR" "$ROOTFS/root/workspace" "$ROOTFS/tmp"
chmod 1777 "$ROOTFS/tmp"
mount -o remount,exec,suid,dev /data 2>/dev/null || true

if ! mountpoint -q "$ROOTFS/proc"; then
  mount -t proc proc "$ROOTFS/proc"
  mount -t sysfs sysfs "$ROOTFS/sys"
  mount -o bind /dev "$ROOTFS/dev"
  mount -t devpts devpts "$ROOTFS/dev/pts"
fi

if ! mountpoint -q "$ROOTFS/root/workspace"; then
  mount -o bind "$SHARED_DIR" "$ROOTFS/root/workspace"
fi

echo "nameserver 8.8.8.8" > "$ROOTFS/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$ROOTFS/etc/resolv.conf"
echo "127.0.0.1 localhost" > "$ROOTFS/etc/hosts"

echo "==> [5/5] Provisioning Ubuntu (Network GIDs, Build Tools, Node.js 22 & Claude Code)..."
cat << "CHROOT_SETUP" > "$ROOTFS/root/provision.sh"
#!/bin/bash
set -e
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

# 1. Register Android kernel networking groups (aid_inet = 3003, aid_net_raw = 3004)
groupadd -g 3003 aid_inet 2>/dev/null || true
groupadd -g 3004 aid_net_raw 2>/dev/null || true
usermod -G nogroup -g aid_inet _apt 2>/dev/null || true
usermod -a -G aid_inet,aid_net_raw root 2>/dev/null || true

# 2. Run package installation inside su - root so GID 3003 is active in kernel memory
su - root -c '"'"'
set -e
export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

apt update && apt upgrade -y
apt install -y curl wget git unzip xz-utils zip build-essential clang cmake \
  ninja-build pkg-config sudo ca-certificates openssh-client nano htop

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt install -y nodejs
fi

npm install -g @anthropic-ai/claude-code
'"'"'

# 3. Install /root/verify-setup.sh diagnostic script inside Ubuntu
cat << "VERIFY_EOF" > /root/verify-setup.sh
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

pass() { echo -e "  [${GREEN}PASS${NC}] $1"; }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; }

echo ""
echo "       Ubuntu ARM64 Chroot Environment Health Check     "
echo ""

echo -e "\n1. System & Kernel Mounts:"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  pass "OS: ${PRETTY_NAME} ($(uname -m))"
else
  fail "Could not detect Ubuntu OS release"
fi

for mp in /proc /sys /dev /dev/pts /root/workspace; do
  if grep -qs " $mp " /proc/mounts; then
    pass "Mounted: $mp"
  else
    fail "Not mounted: $mp"
  fi
done

echo -e "\n2. Shared Workspace (/root/workspace):"
if touch /root/workspace/.chroot_test 2>/dev/null; then
  rm -f /root/workspace/.chroot_test
  pass "Read/Write verified on /root/workspace (Android: /data/local/workspace)"
else
  fail "Cannot write to /root/workspace"
fi

echo -e "\n3. Android Network & DNS:"
if id -G root | grep -qw "3003"; then
  pass "Android aid_inet (GID 3003) network group attached"
else
  fail "Missing aid_inet (GID 3003) group"
fi

if curl -fsS --max-time 5 https://api.github.com >/dev/null 2>&1; then
  pass "Outbound HTTPS & DNS resolution working"
else
  fail "Cannot reach outbound internet via HTTPS"
fi

echo -e "\n4. Core CLI & Development Tools:"
for cmd in git curl wget gcc clang cmake ninja make; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd installed ($(command -v "$cmd"))"
  else
    fail "$cmd is missing"
  fi
done

if command -v node >/dev/null 2>&1; then
  pass "Node.js: $(node -v) | npm:$(npm -v)"
else
  fail "Node.js is not installed"
fi

if command -v claude >/dev/null 2>&1; then
  pass "Claude Code CLI: $(claude --version 2>/dev/null || echo "Installed")"
else
  fail "Claude Code CLI not found in PATH"
fi

echo "========================================================"
VERIFY_EOF
chmod +x /root/verify-setup.sh

echo ""
echo " Setup Complete! Native Ubuntu 24.04 ARM64 is ready."
echo " Shared Workspace: /root/workspace (/data/local/workspace)"
echo " Run /root/verify-setup.sh anytime to check system health."
echo ""
CHROOT_SETUP

chmod +x "$ROOTFS/root/provision.sh"
/system/bin/chroot "$ROOTFS" /bin/bash /root/provision.sh
rm -f "$ROOTFS/root/provision.sh"
'

echo "==> Entering Ubuntu Chroot..."
sudo bash ~/start-ubuntu.sh
