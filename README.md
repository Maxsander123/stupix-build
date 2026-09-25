# stupix-build

Build system for the Stupix live OS.

Stupix is a minimal Debian Bookworm based live system designed for server diagnostics.
It boots entirely from RAM using OverlayFS, obtains an IP address via DHCP,
and automatically clones and runs the [stupix script repo](https://github.com/Maxsander123/stupix) on startup.

## Download

Latest ISOs from [Releases](https://github.com/Maxsander123/stupix-build/releases/latest):

| File | Architecture | Boot modes |
|---|---|---|
| `stupix-linux-amd64.iso` | x86-64 (PC, server) | Legacy BIOS + UEFI |
| `stupix-linux-arm64.iso` | ARM64 (RPi, ARM server) | UEFI |

## Writing to USB

```bash
# Linux (replace sdX with your USB device — use lsblk to find it)
sudo dd if=stupix-linux-amd64.iso of=/dev/sdX bs=4M status=progress && sync

# macOS
sudo dd if=stupix-linux-amd64.iso of=/dev/rdiskX bs=4m && sync
```

**Do not use your system drive.** Double-check with `lsblk` before running dd.

## Boot

Boot from USB. The system:
1. Loads kernel + initrd via GRUB (UEFI)
2. Mounts squashfs read-only, adds RAM overlay
3. Gets DHCP on all ethernet interfaces
4. Clones the stupix repo and runs `auto.sh`

SSH in after ~30 seconds:
```
ssh root@<ip>       # password: stupix
```

## Log files

All output is written to `/var/log/stupix/`:

| File | Contents |
|---|---|
| `check-deps.log` | Tool availability check (runs first) |
| `serials.log` | All hardware serial numbers |
| `inventory.json` | Full structured JSON inventory |
| `init.log` | Boot init, clone progress |
| `auto.log` | Main log with timestamps |
| `network.log` | IP, routing, DNS |
| `system-info.log` | Manufacturer, model, BIOS |
| `cpu.log` | CPU details |
| `memory.log` | RAM modules (dmidecode) |
| `storage.log` | Block devices, NVMe, RAID |
| `smart.log` | S.M.A.R.T. data per disk |
| `pci.log` | PCI devices |
| `usb.log` | USB devices |
| `ipmi.log` | IPMI chassis, BMC, FRU, sensors, SEL |
| `hardware-full.log` | Full lshw output |
| `dmesg-errors.log` | MCE, I/O errors, EDAC, kernel taint |
| `nic-link.log` | NIC speed/duplex + LLDP neighbors |
| `raid-hardware.log` | Hardware RAID controllers |
| `disk-perf.log` | fio sequential + random read per disk |
| `memtest.log` | memtester 256 MB quick check |

Quick access:
```bash
cat /var/log/stupix/serials.log
python3 -m json.tool /var/log/stupix/inventory.json
cat /var/log/stupix/dmesg-errors.log
```

## Building locally

Requires a Debian/Ubuntu host with `live-build`.

```bash
sudo apt-get install live-build debootstrap squashfs-tools xorriso
git clone https://github.com/Maxsander123/stupix-build
cd stupix-build
sudo lb config
sudo lb build
# Output: live-image-amd64.hybrid.iso
```

### Custom repo source

Override the script repo at build time (Gitea, GitLab, Forgejo, GitHub Enterprise):

```bash
# Gitea / Forgejo / GitLab — user + token
sudo STUPIX_REPO=https://gitea.example.com/org/stupix \
     STUPIX_REPO_USER=myuser \
     STUPIX_REPO_TOKEN=mytoken \
     lb build

# GitHub PAT
sudo STUPIX_REPO=https://github.com/myorg/stupix \
     STUPIX_REPO_TOKEN=ghp_xxxx \
     lb build
```

Credentials are baked into `/etc/stupix/repo.conf` (chmod 600) inside the ISO.

## Repository structure

```
auto/config                                          live-build configuration + repo env vars
config/package-lists/stupix.list.chroot              packages installed into the ISO
config/hooks/normal/0010-stupix-setup.hook.chroot    post-install hook (SSH, MOTD, services)
config/includes.chroot/usr/local/bin/stupix-init.sh  boot init script (clone + run auto.sh)
config/includes.chroot/etc/stupix/repo.conf          repo URL + credentials (build-time generated)
.github/workflows/build-iso.yml                      CI: build → boot test → release
```

## CI

Every push to `main`:
1. Builds the ISO with `lb build` (~14 min)
2. Boots it in QEMU (KVM) and verifies squashfs mounts, network comes up, stupix-init starts
3. Only publishes a GitHub Release if the boot test passes

## SSH access

Root login enabled. Default password: `stupix`

Change in: `config/hooks/normal/0010-stupix-setup.hook.chroot`

## Included tools

- `ipmitool`, `openipmi`, `freeipmi-tools` — IPMI / BMC
- `dmidecode`, `lshw`, `lspci`, `hwinfo` — hardware info
- `smartmontools`, `nvme-cli`, `sg3-utils`, `lsscsi` — storage
- `ethtool`, `lldpd`, `tcpdump`, `iperf3`, `mtr` — network
- `fio` — disk benchmarks
- `memtester`, `stress-ng` — memory and stress tests
- `htop`, `iotop`, `sysstat` — monitoring
- `openssh-server` — SSH access
- `git`, `curl`, `vim`, `tmux`, `jq`, `python3` — utilities
