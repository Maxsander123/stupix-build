# stupix-build

Build system for the Stupix live boot system based on Debian Bookworm.

## Repository layout

    stupix-build/
    ├── .github/workflows/build-iso.yml     GitHub Actions workflow
    ├── auto/
    │   ├── config                           live-build configuration
    │   ├── build                            build script
    │   └── clean                            clean script
    └── config/
        ├── package-lists/
        │   └── stupix.list.chroot           installed packages
        ├── hooks/normal/
        │   └── 0010-stupix-setup.hook.chroot  root password, SSH, IPMI modules, MOTD
        └── includes.chroot/
            ├── etc/systemd/system/
            │   └── stupix-init.service      systemd unit for boot init
            └── usr/local/bin/
                └── stupix-init.sh           boot init script

## Boot flow

    USB/ISO boot
      -> GRUB
      -> Kernel + initrd
      -> live-boot (OverlayFS, write layer in RAM)
      -> systemd
      -> DHCP on all ethernet interfaces (eth*, en*, ens*, eno*, enp*, em*)
      -> stupix-init.service
         -> wait for network
         -> git clone https://github.com/Maxsander123/stupix /opt/stupix
         -> bash /opt/stupix/auto.sh
      -> STUPIX ready

## Log files

All output is written to /var/log/stupix/:

    /var/log/stupix/init.log          boot init and clone log
    /var/log/stupix/auto.log          auto.sh main log
    /var/log/stupix/network.log       network info
    /var/log/stupix/system-info.log   system manufacturer, BIOS
    /var/log/stupix/cpu.log           CPU details
    /var/log/stupix/memory.log        RAM modules
    /var/log/stupix/storage.log       block devices, NVMe, RAID
    /var/log/stupix/smart.log         S.M.A.R.T. data
    /var/log/stupix/pci.log           PCI devices
    /var/log/stupix/usb.log           USB devices
    /var/log/stupix/ipmi.log          IPMI/BMC data, FRU, sensors, SEL
    /var/log/stupix/hardware-full.log full lshw output

## Default credentials

    User     : root
    Password : stupix
    SSH      : enabled on port 22

## Build locally

Requires a Debian 12 (Bookworm) host.

    sudo apt-get install live-build debootstrap squashfs-tools xorriso
    git clone https://github.com/Maxsander123/stupix-build
    cd stupix-build
    chmod +x auto/*
    sudo ./auto/config
    sudo lb build

Output: live-image-amd64.hybrid.iso (~400 MB)

## Scripts repository

https://github.com/Maxsander123/stupix
