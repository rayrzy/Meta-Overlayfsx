#!/system/bin/sh
############################################
# overlayfsx diag.sh
# Prints a plain-text diagnostics report to stdout, for bug reports.
#
#   sh diag.sh > report.txt
#
# It contains the device model, versions, module ids and the log; it contains no personal
# files. Read it before sharing it.
############################################

META_DIR="/data/adb/metamodule"
CONF_DIR="/data/adb/overlayfsx.d"
IMG_FILE="$META_DIR/modules.img"
MNT_DIR="$META_DIR/mnt"
LOG_FILE="$META_DIR/overlayfsx.log"
BINARY="$META_DIR/overlayfsx"

section() {
    echo
    echo "== $1 =="
}

echo "overlayfsx diagnostics - $(date '+%Y-%m-%d %H:%M:%S %z')"

section "Module"
grep -E '^(id|name|version|versionCode)=' "$META_DIR/module.prop" 2>/dev/null || echo "(module.prop not found)"

section "Device"
echo "model: $(getprop ro.product.model)"
echo "android: $(getprop ro.build.version.release) (sdk $(getprop ro.build.version.sdk))"
echo "abi: $(getprop ro.product.cpu.abi)"
echo "kernel: $(uname -r) $(uname -m)"
echo "selinux: $(getenforce 2>/dev/null)"
echo "ksud: $(ksud -V 2>/dev/null || echo unknown)"

section "Tools"
for t in e2fsck resize2fs fstrim mke2fs dumpe2fs; do
    p=$(command -v "$t" 2>/dev/null)
    echo "$t: ${p:-missing}"
done
command -v e2fsck >/dev/null 2>&1 && e2fsck -V 2>&1 | head -n 1

section "Image"
if [ -f "$IMG_FILE" ]; then
    echo "size (logical): $(stat -c%s "$IMG_FILE") bytes"
    echo "size (on disk): $(du -k "$IMG_FILE" 2>/dev/null | awk '{print $1}') KiB"
else
    echo "image file missing: $IMG_FILE"
fi
if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    echo "mounted: yes"
    grep " $(readlink -f "$MNT_DIR" 2>/dev/null || echo "$MNT_DIR") " /proc/mounts 2>/dev/null
    df -k "$MNT_DIR" 2>/dev/null
else
    echo "mounted: no"
fi
if command -v dumpe2fs >/dev/null 2>&1 && [ -f "$IMG_FILE" ]; then
    echo
    # Superblock only; read-only and safe on a mounted image.
    dumpe2fs -h "$IMG_FILE" 2>/dev/null | grep -E '^(Filesystem (state|features|flags)|Errors behavior|Block count|Free blocks|Inode count|Free inodes|Last (mounted|checked)|Mount count|Lifetime writes)'
fi

section "Image health and requests"
if [ -f "$CONF_DIR/health" ]; then
    echo "last boot check: $(cat "$CONF_DIR/health")   (epoch, status, e2fsck rc)"
else
    echo "last boot check: not recorded"
fi
for f in backup_now restore_backup optimize_now resize_mb no_auto_backup; do
    [ -e "$CONF_DIR/$f" ] && echo "request present: $f"
done
if [ -d "$CONF_DIR/op.lock" ]; then
    echo "operation lock: held by '$(cat "$CONF_DIR/op.lock/name" 2>/dev/null)' (pid $(cat "$CONF_DIR/op.lock/pid" 2>/dev/null))"
else
    echo "operation lock: free"
fi
ls -l "$CONF_DIR" 2>/dev/null

section "Modules in image"
ls -1 "$MNT_DIR" 2>/dev/null | grep -v '^lost+found$' || echo "(none or not mounted)"

section "Mount inspector"
if [ -x "$BINARY" ]; then
    "$BINARY" inspect 2>&1 | head -n 80
else
    echo "(overlayfsx binary not found)"
fi

section "Kernel messages (ext4 / loop / overlay)"
dmesg 2>/dev/null | grep -iE 'ext4|loop[0-9]|overlay|euclean' | tail -n 40

section "Log (last 200 lines)"
tail -n 200 "$LOG_FILE" 2>/dev/null || echo "(no log)"
