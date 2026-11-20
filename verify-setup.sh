#!/bin/bash
# =============================================================================
# verify-setup.sh - Verifies mounts, networking, and CLI tools inside Ubuntu
# Location inside Ubuntu: /root/verify-setup.sh
# Usage: /root/verify-setup.sh
# =============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

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
  pass "Claude Code CLI: $(claude --version 2>/dev/null || echo 'Installed')"
else
  fail "Claude Code CLI not found in PATH"
fi

echo "========================================================"
