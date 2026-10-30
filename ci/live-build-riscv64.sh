#!/bin/sh
# =====================================================
# Teach live-build to build a bootable riscv64 ISO.
#
# live-build (up to and including Debian trixie's 20250505) knows riscv64
# kernels but has no riscv64 UEFI support:
#   - binary_grub-efi has no riscv64 case, so the ISO gets no EFI boot image
#   - binary_grub_cfg only looks for vmlinuz-*, while the Debian riscv64
#     kernel is installed as /boot/vmlinux-*, so the GRUB menu has no entry
#
# This script patches the installed live-build in place. It is idempotent
# and fails loudly if live-build changed in a way it does not recognise.
#
# usage: sudo ci/live-build-riscv64.sh [live-build script dir]
# =====================================================

set -e

LB_DIR=${1:-/usr/lib/live/build}
EFI="$LB_DIR/binary_grub-efi"
CFG="$LB_DIR/binary_grub_cfg"

for f in "$EFI" "$CFG"; do
    [ -w "$f" ] || { echo "cannot write $f (run as root?)" >&2; exit 1; }
done

if grep -q riscv64-efi "$EFI"; then
    echo "live-build already has riscv64 UEFI support"
else
    # Dependency check: GRUB riscv64 EFI modules
    sed -i '/Check_package chroot \/usr\/lib\/grub\/arm-efi\/configfile.mod grub-efi-arm-bin/{n;s|^\t\t;;$|\t\t;;\n\triscv64)\n\t\tCheck_package chroot /usr/lib/grub/riscv64-efi/configfile.mod grub-efi-riscv64-bin\n\t\t;;|}' "$EFI"
    # EFI image with EFI/boot/bootriscv64.efi, the UEFI removable-media path
    sed -i '/gen_efi_boot_img "arm-efi" "arm" "debian-live\/arm"/{n;n;s|^\t\t;;$|\t\t;;\n\triscv64)\n\t\tgen_efi_boot_img "riscv64-efi" "riscv64" "debian-live/riscv64"\n\t\tPATH="\\${PRE_EFI_IMAGE_PATH}"\n\t\t;;|}' "$EFI"
    # Clean up generated files like for the other arches
    sed -i 's|^rm -rf binary/boot/efi.img binary/boot/grub/i386-efi/ .*binary/boot/grub/arm-efi$|& binary/boot/grub/riscv64-efi|' "$EFI"
    sed -i 's|^rm -rf chroot/grub-efi-temp-arm-efi$|&\nrm -rf chroot/grub-efi-temp-riscv64-efi|' "$EFI"
    echo "patched $EFI"
fi

if grep -q 'vmlinu\[xz\]' "$CFG"; then
    echo "live-build already finds vmlinux kernels"
else
    sed -i 's|chroot/boot/vmlinuz-|chroot/boot/vmlinu[xz]-|g; s/s|vmlinuz-||/s|vmlinu[xz]-||/g' "$CFG"
    echo "patched $CFG"
fi

# Verify
grep -q 'grub-efi-riscv64-bin' "$EFI" || { echo "riscv64 dependency patch did not apply to $EFI" >&2; exit 1; }
grep -q 'gen_efi_boot_img "riscv64-efi"' "$EFI" || { echo "riscv64 EFI image patch did not apply to $EFI" >&2; exit 1; }
! grep -q 'chroot/boot/vmlinuz-' "$CFG" || { echo "vmlinux patch did not apply to $CFG" >&2; exit 1; }
sh -n "$EFI"
sh -n "$CFG"
echo "live-build is ready for riscv64"
