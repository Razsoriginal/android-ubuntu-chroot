# Native Ubuntu 24.04 LTS (`chroot`) on Rooted Android

Run a **100% native ARM64 Ubuntu 24.04 LTS Linux environment** directly on the Android Linux kernel using `chroot` and Termux.

Unlike Android's built-in Virtualization Framework (`pKVM`, which is disabled or locked down on many OEM devices) or userspace `proot-distro` (which intercepts system calls via `ptrace` and slows down file I/O), a rooted `chroot` runs directly on the device's hardware with zero virtualization or syscall translation overhead.

---

## Key Features

- **100% Native Performance:** Direct execution on the ARM64 Linux kernel without `ptrace` or VM overhead.
- **Persistent Shared Workspace:** Automatically bind-mounts `/data/local/workspace` on Android to `/root/workspace` inside Ubuntu, allowing seamless access from root-enabled Android file managers (such as MiXplorer).
- **Android Network Socket Fix Included:** Automatically configures Android's `aid_inet` (`GID 3003`) and `aid_net_raw` (`GID 3004`) kernel groups so `apt`, `curl`, `git`, `ssh`, and Node.js work out of the box.
- **Phantom Process Killer Bypass:** Disables Android 12+ background child-process limits so heavy builds, servers, and AI CLI agents (like Claude Code) are never terminated by the OS.
- **Pre-configured Modern Dev Stack:** Installs `git`, `curl`, `clang`, `cmake`, `ninja`, `build-essential`, **Node.js 22 LTS**, and **Claude Code CLI**.

---

## Repository Structure

| File | Description | Where It Runs |
| :--- | :--- | :--- |
| `README.md` | Complete setup, architecture, and troubleshooting guide. | — |
| `setup-all.sh` | Automated one-step installer that downloads Ubuntu, configures mounts, and provisions packages. | Termux (Normal Session) |
| `start-ubuntu.sh` | Mounts kernel filesystems (`/proc`, `/sys`, `/dev`, `/dev/pts`) and enters the Ubuntu `chroot`. | Termux (`sudo bash ~/start-ubuntu.sh` or `ubuntu`) |
| `stop-ubuntu.sh` | Safely unmounts all virtual filesystems before a device reboot. | Termux (`sudo bash ~/stop-ubuntu.sh` or `stop-ubuntu`) |
| `verify-setup.sh` | Diagnostic health-check script that verifies mounts, network GIDs, DNS, and CLI tools. | Inside Ubuntu (`/root/verify-setup.sh`) |

---

## Prerequisites

1. **Rooted ARM64 Android Device:** Rooted via Magisk, KernelSU, or APatch.
2. **Termux App:**
   - **Important:** Do **not** install Termux from the Google Play Store (it is deprecated).
   - Install the latest release from [F-Droid](https://f-droid.org/en/packages/com.termux/) or [GitHub Releases](https://github.com/termux/termux-app/releases).
3. **Grant Superuser Access to Termux:**
   - Open Termux, run `su`, and tap **Grant** on the superuser prompt.
   - Run `exit` to return to the standard Termux shell (`~ $`).

---

## Quick Start (Automated Installation)

Open a standard (non-root) Termux session (`~ $`) and clone this repository or run `setup-all.sh`:

```bash
pkg update && pkg install -y git
git clone https://github.com/Razsoriginal/android-ubuntu-chroot.git ~/android-ubuntu-chroot
cd ~/android-ubuntu-chroot
chmod +x *.sh
bash setup-all.sh
```

> **Note if copying scripts from `/sdcard/Download`:** Android text editors sometimes insert Windows `CRLF` (`\r\n`) line endings, which will break Linux shell scripts. Strip them first using:
> ```bash
> sed -i 's/\r$//' setup-all.sh
> bash setup-all.sh
> ```

---

## Daily Usage

Once `setup-all.sh` completes, it registers two shortcut aliases in your Termux `~/.bashrc`:

### 1. Enter Ubuntu
Open Termux and run:
```bash
ubuntu
```
*(Or run `sudo bash ~/start-ubuntu.sh`).*

### 2. Work in the Shared Workspace
Inside Ubuntu, store your code and files in `/root/workspace`:
```bash
cd /root/workspace
```
- **Accessing Files from Android:** Using any root-enabled file manager (e.g., **MiXplorer**), bookmark `/data/local/workspace` (or `/data/local/ubuntu` for the full rootfs) to browse, edit, or copy files directly on Android.

### 3. Run the Health Check Anytime
Inside Ubuntu (`root@localhost:~#`), run:
```bash
/root/verify-setup.sh
```

### 4. Exiting & Rebooting Safely
- **Daily Exit:** Type `exit` inside Ubuntu to return to Termux. Kernel mounts stay active in the background so re-entering via `ubuntu` is instantaneous.
- **Before Rebooting Your Phone:** Run `stop-ubuntu` (or `sudo bash ~/stop-ubuntu.sh`) from Termux to cleanly unmount `/proc`, `/sys`, `/dev`, and `/root/workspace`.

---

## Optional: Creating a Non-Root User Inside Ubuntu

Some CLI tools and package managers prefer running under a standard non-root user account with `sudo` privileges. Inside Ubuntu (`root@localhost:~#`), run:

```bash
adduser dev
usermod -aG sudo,aid_inet,aid_net_raw dev
```
*(Important: Always include `aid_inet` and `aid_net_raw` when creating new users on Android kernels so the user has outbound network access).*

To switch to this user inside Ubuntu:
```bash
su - dev
```

---

## Technical Architecture & Troubleshooting

| Symptom / Error | Root Cause on Android | How This Repo Solves It |
| :--- | :--- | :--- |
| `tar: Not tar` during rootfs extraction | Running `su` in Termux resets `PATH` to `/system/bin`, invoking Android's stripped-down `toybox tar` instead of GNU `tar`. | `setup-all.sh` explicitly invokes Termux's `/data/data/com.termux/files/usr/bin/tar` and `curl -fL`. |
| `chroot: failed to run command '/usr/bin/env': No such file or directory` | Termux sets `LD_PRELOAD` to `libtermux-exec.so`. Inside the Ubuntu chroot, the ELF linker cannot find that Android path and aborts. | `start-ubuntu.sh` runs `unset LD_PRELOAD` on the host before invoking `/system/bin/chroot`. |
| `apt` works, but `curl`, `git`, or `npm` fail to connect to the internet | Android's kernel restricts network socket creation to processes with `GID 3003` (`aid_inet`). Adding `root` to `aid_inet` in `/etc/group` does not take effect if entering via `/bin/bash`. | `start-ubuntu.sh` enters the chroot using `/bin/su - root`, which calls `initgroups()` and activates `GID 3003` in kernel memory immediately. |
| Background processes or builds get killed randomly (`Signal 9`) | Android 12+ enforces a `max_phantom_processes` limit (default 32) that kills background child processes spawned by terminal apps. | `setup-all.sh` uses root `device_config` and `settings` commands to disable phantom process monitoring persistently. |
| Permission denied when executing binaries inside `/data/local/ubuntu` | Android mounts `/data` with `nosuid` or `noexec` flags on certain configurations. | `start-ubuntu.sh` runs `mount -o remount,exec,suid,dev /data` prior to entering the chroot. |

---

## License

MIT License — see [LICENSE](/home/ubuntu/projects/open-source/android-ubuntu-chroot/LICENSE). Free to use, modify, and distribute.