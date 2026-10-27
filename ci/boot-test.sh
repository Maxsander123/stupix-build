#!/bin/bash
# =====================================================
# Boot the released ISO — unmodified — in QEMU and check that it gets all
# the way to a cloned stupix repo. Output is read from the serial console.
#
# usage: ci/boot-test.sh <iso> <mode> [log]
#   amd64: bios-cd | bios-usb | uefi-cd | uefi-usb | uefi-sb-cd
#   arm64: arm64-cd | arm64-usb
#
#   *-cd   ISO attached as optical drive (VMs, BMC virtual media)
#   *-usb  ISO attached as raw USB stick (what `dd` to a stick produces)
#   uefi-sb  Secure Boot enabled, Microsoft keys enrolled
# =====================================================

set -u

ISO=$1
MODE=$2
LOG=${3:-boot-$MODE.log}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ovmf() { for f in "$@"; do [ -f "$f" ] && { echo "$f"; return; }; done; echo "missing firmware: $*" >&2; exit 2; }

KVM=""
case "$MODE" in
    arm64-*)
        QEMU=qemu-system-aarch64
        TIMEOUT=${BOOT_TIMEOUT:-1500}
        FW="-machine virt -cpu cortex-a57 -smp 4
            -bios $(ovmf /usr/share/qemu-efi-aarch64/QEMU_EFI.fd /usr/share/AAVMF/QEMU_EFI.fd)"
        NET="-device virtio-net-pci,netdev=n0,romfile="
        ;;
    *)
        QEMU=qemu-system-x86_64
        if [ -w /dev/kvm ]; then KVM="-enable-kvm -cpu host"; TIMEOUT=${BOOT_TIMEOUT:-300}
        else TIMEOUT=${BOOT_TIMEOUT:-900}; fi
        NET="-device e1000,netdev=n0"
        case "$MODE" in
            bios-*)
                FW="-machine pc -smp 2" ;;
            uefi-sb-*)
                cp "$(ovmf /usr/share/OVMF/OVMF_VARS_4M.ms.fd)" "$TMP/vars.fd"
                FW="-machine q35,smm=on -smp 2
                    -global driver=cfi.pflash01,property=secure,value=on
                    -drive if=pflash,format=raw,readonly=on,file=$(ovmf /usr/share/OVMF/OVMF_CODE_4M.secboot.fd)
                    -drive if=pflash,format=raw,file=$TMP/vars.fd" ;;
            uefi-*)
                cp "$(ovmf /usr/share/OVMF/OVMF_VARS_4M.fd)" "$TMP/vars.fd"
                FW="-machine q35 -smp 2
                    -drive if=pflash,format=raw,readonly=on,file=$(ovmf /usr/share/OVMF/OVMF_CODE_4M.fd)
                    -drive if=pflash,format=raw,file=$TMP/vars.fd" ;;
            *) echo "unknown mode: $MODE" >&2; exit 2 ;;
        esac
        ;;
esac

case "$MODE" in
    arm64-cd)
        MEDIA="-device virtio-scsi-pci -drive file=$ISO,media=cdrom,readonly=on,if=none,id=cd0
               -device scsi-cd,drive=cd0,bootindex=0" ;;
    *-cd)
        MEDIA="-drive file=$ISO,media=cdrom,readonly=on,if=none,id=cd0 -device ide-cd,drive=cd0,bootindex=0" ;;
    *-usb)
        cp "$ISO" "$TMP/usb.img"
        MEDIA="-device qemu-xhci -drive file=$TMP/usb.img,format=raw,if=none,id=usb0
               -device usb-storage,drive=usb0,bootindex=0" ;;
esac

echo "== $MODE: $QEMU ${KVM:+(KVM)} timeout ${TIMEOUT}s"
: > "$LOG"
# shellcheck disable=SC2086
$QEMU $KVM $FW -m 2048 $MEDIA $NET -netdev user,id=n0 \
    -display none -monitor none -serial file:"$LOG" &
QPID=$!

# Stop as soon as the outcome is known
for _ in $(seq 1 "$TIMEOUT"); do
    grep -qE "stupix: (Repository cloned|ERROR)" "$LOG" && break
    kill -0 "$QPID" 2>/dev/null || break
    sleep 1
done
sleep 2
kill "$QPID" 2>/dev/null
wait "$QPID" 2>/dev/null

FAIL=0
check() { if grep -qE "$1" "$LOG"; then echo "  ok   $2"; else echo "  FAIL $2"; FAIL=1; fi; }
check "Linux version"              "bootloader started the kernel"
check "squashfs: version|overlay"  "live medium found, squashfs mounted"
check "stupix: Network interface is up" "systemd + stupix-init running"
check "stupix: Host .* reachable"  "DHCP + DNS + internet"
check "stupix: Repository cloned"  "stupix repo cloned"

if [ "$FAIL" -ne 0 ]; then
    echo "--- last 40 lines of $LOG"
    tail -40 "$LOG"
    echo "❌ $MODE boot test FAILED"
    exit 1
fi
echo "✅ $MODE boot test passed"
