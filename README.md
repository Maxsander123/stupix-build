# stupix-build

Build system for the Stupix live OS.

Stupix is a minimal Debian Bookworm based live system designed for server diagnostics.
It boots entirely from RAM using OverlayFS, obtains an IP address via DHCP,
and automatically clones https://github.com/Maxsander123/stupix and runs auto.sh on startup.

## Repository structure

    auto/config                                         - live-build configuration
    auto/build                                          - build trigger script
    auto/clean                                          - clean script
    config/package-lists/stupix.list.chroot             - package list
    config/hooks/normal/0010-stupix-setup.hook.chroot   - post-install hook (SSH, modules, MOTD)
    config/includes.chroot/usr/local/bin/stupix-init.sh - boot init script
    config/includes.chroot/etc/systemd/system/          - systemd unit files
    .github/workflows/build-iso.yml                     - GitHub Actions ISO build

## Building locally

Requires Debian or Ubuntu host with live-build installed.

    sudo apt-get install live-build debootstrap squashfs-tools xorriso
    git clone https://github.com/Maxsander123/stupix-build
    cd stupix-build
    chmod +x auto/config auto/build auto/clean
    sudo ./auto/config
    sudo lb build

The output is: live-image-amd64.hybrid.iso

## Writing to USB

    sudo dd if=live-image-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress

## Boot behavior

1. System boots from USB or ISO
2. GRUB loads kernel and initrd
3. live-boot mounts squashfs read-only, adds OverlayFS write layer in RAM
4. systemd starts, DHCP is obtained on all ethernet interfaces
5. stupix-init.service runs: waits for network, clones the stupix repo, executes auto.sh
6. All diagnostic output is written to /var/log/stupix/

## Included tools

- ipmitool, openipmi, freeipmi-tools   (IPMI / iDRAC / BMC)
- dmidecode, lshw, lspci               (hardware information)
- smartmontools                        (disk health)
- nvme-cli                             (NVMe)
- tcpdump, nmap, iperf3, mtr           (network diagnostics)
- htop, iotop, sysstat                 (system monitoring)
- stress-ng, memtester                 (stress and memory tests)
- openssh-server                       (SSH access into the live system)
- git, curl, vim, tmux, jq             (utilities)

## SSH access

Root login is enabled. Default password: stupix
Change this in: config/hooks/normal/0010-stupix-setup.hook.chroot

## Log files (written during boot)

All logs are stored in /var/log/stupix/

    init.log          - boot init, clone progress
    auto.log          - main log with timestamps
    network.log       - IP addresses, routing, DNS
    system-info.log   - manufacturer, model, BIOS
    cpu.log           - CPU details
    memory.log        - RAM modules
    storage.log       - block devices, NVMe, RAID
    smart.log         - S.M.A.R.T. data for all disks
    pci.log           - PCI devices
    usb.log           - USB devices
    ipmi.log          - IPMI chassis, BMC, FRU, sensors, SEL
    hardware-full.log - full lshw output
