# stupix-build

Build system for the Stupix live OS.

Stupix is a minimal Debian based live system designed for server diagnostics
(Bookworm on amd64/arm64, Trixie on riscv64).
It boots entirely from RAM using OverlayFS, obtains an IP address via DHCP,
and automatically clones and runs the [stupix script repo](https://github.com/Maxsander123/stupix) on startup.

## Minimum Requirements

| | amd64 | arm64 | riscv64 |
|---|---|---|---|
| **CPU** | 64-bit x86 (any) | ARMv8-A / ARM64 | RV64GC (RVA20 or newer) |
| **RAM** | 2 GB (4 GB recommended) | 2 GB (4 GB recommended) | 2 GB (4 GB recommended) |
| **Boot** | Legacy BIOS or UEFI | UEFI | UEFI |
| **USB** | ≥ 1 GB | ≥ 1 GB | ≥ 1 GB |
| **Network** | Ethernet with DHCP (needed to clone scripts) | same | same |
| **Storage** | none — runs entirely from RAM | same | same |

> **Raspberry Pi 4/5:** Requires UEFI firmware on the SD card (e.g. [pftf/RPi4-UEFI-Firmware](https://github.com/pftf/RPi4-UEFI-Firmware)). The onboard bootloader alone is not sufficient.

> **RISC-V boards:** need UEFI firmware (EDK2, or U-Boot with its UEFI implementation — the
> default on most vendor images, e.g. StarFive VisionFive 2, Milk-V, SiFive). No Secure Boot:
> Debian has no signed shim/GRUB for riscv64. The kernel is Debian's generic `linux-image-riscv64`,
> so the board needs mainline kernel support.

## Download

Latest ISOs from [Releases](https://github.com/Maxsander123/stupix-build/releases/latest):

| File | Architecture | Boot modes |
|---|---|---|
| `stupix-linux-amd64.iso` | x86-64 (PC, server) | Legacy BIOS + UEFI |
| `stupix-linux-arm64.iso` | ARM64 (RPi, ARM server) | UEFI |
| `stupix-linux-riscv64.iso` | RISC-V 64 (UEFI boards, servers) | UEFI |

## Writing to USB

```bash
# Linux (replace sdX with your USB device — use lsblk to find it)
sudo dd if=stupix-linux-amd64.iso of=/dev/sdX bs=4M status=progress && sync

# macOS
sudo dd if=stupix-linux-amd64.iso of=/dev/rdiskX bs=4m && sync
```

**Do not use your system drive.** Double-check with `lsblk` before running dd.

## Boot

Boot from USB stick, BMC virtual media or as a VM CD-ROM — legacy BIOS, UEFI and
UEFI Secure Boot all work. The system:
1. Shows the boot menu (isolinux on BIOS, shim + GRUB on UEFI) and boots the
   default entry automatically after 5 seconds — no keyboard needed
2. Mounts squashfs read-only, adds RAM overlay
3. Gets DHCP on all ethernet interfaces
4. Clones the stupix repo and runs `auto.sh`

Boot menu, kernel messages and `stupix:` progress lines are mirrored to the first
serial port (`ttyS0`, 115200 8N1) on amd64, so you can follow along via IPMI SOL
or a VM serial console. On arm64 and riscv64 the kernel uses the firmware's console (SPCR/DT).

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

### Other architectures

arm64 and riscv64 are cross-built on an amd64 host through `qemu-user-static`:

```bash
# arm64 — Debian bookworm host
sudo apt-get install qemu-user-static binfmt-support
sudo STUPIX_ARCH=arm64 lb config && sudo lb build

# riscv64 — needs a Debian trixie host (or container): riscv64 is an official
# Debian architecture only since trixie. Stock live-build has no riscv64 UEFI
# support yet, ci/live-build-riscv64.sh adds it (patches /usr/lib/live/build).
# (in a container, register the qemu-riscv64 binfmt by hand — see build-riscv64 in the workflow)
sudo apt-get install live-build debootstrap squashfs-tools xorriso qemu-user-static
sudo ci/live-build-riscv64.sh
sudo STUPIX_ARCH=riscv64 lb config && sudo lb build
# Output: live-image-riscv64.hybrid.iso
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
config/hooks/normal/9000-stupix-bootloader.hook.binary  boot menu: 5s auto-boot + serial console
config/includes.chroot/usr/local/bin/stupix-init.sh  boot init script (clone + run auto.sh)
config/includes.chroot/etc/stupix/repo.conf          repo URL + credentials (build-time generated)
ci/boot-test.sh                                      boots the ISO in QEMU (BIOS/UEFI/SB, CD/USB)
ci/live-build-riscv64.sh                             adds riscv64 UEFI support to live-build
.github/workflows/build-iso.yml                      CI: build → boot test → release
```

## CI

Every push to `main`:
1. Builds the ISO with `lb build` (~14 min)
2. Boots the unmodified ISO in QEMU — amd64: BIOS and UEFI, each as CD and as USB
   stick, plus UEFI Secure Boot; arm64 and riscv64: UEFI as CD and USB — and requires every run to
   reach a cloned stupix repo (DHCP, DNS, clone)
3. Only publishes a GitHub Release if all boot tests pass

Run a boot test locally (needs `qemu-system-x86` + `ovmf`):

```bash
bash ci/boot-test.sh live-image-amd64.hybrid.iso uefi-usb

# riscv64 needs qemu-system-riscv + qemu-efi-riscv64 (Debian trixie)
bash ci/boot-test.sh live-image-riscv64.hybrid.iso riscv64-cd
```

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
