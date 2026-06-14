#!/usr/bin/env bash
#
# flash-sdcard.sh — 将 RG350 固件刷入 SD 卡
#
# 用法:
#   ./flash-sdcard.sh /dev/sdX                # 完整刷写 (UBIBoot + boot + rootfs)
#   ./flash-sdcard.sh --boot-only /dev/sdX     # 仅刷 UBIBoot + 内核
#   ./flash-sdcard.sh --rootfs-only /dev/sdX   # 仅刷 rootfs
#
# 需要的文件 (在当前目录或指定路径):
#   ubiboot-rg350.bin   UBIBoot bootloader
#   UZIMAGE.BIN         Linux 内核 (uImage 格式)
#   rootfs.tar.gz       Buildroot rootfs

set -euo pipefail

# ─── 颜色 ────────────────────────────────────────────────────────
c_r='\033[1;31m'; c_g='\033[1;32m'; c_y='\033[1;33m'; c_b='\033[1;36m'; c_n='\033[0m'
log()  { printf "${c_b}==>${c_n} %s\n" "$*"; }
ok()   { printf "${c_g}OK${c_n}  %s\n" "$*"; }
warn() { printf "${c_y}WARN${c_n} %s\n" "$*"; }
err()  { printf "${c_r}ERR${c_n} %s\n" "$*" >&2; exit 1; }

# ─── 参数解析 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="full"
DEV=""
FW_DIR="$SCRIPT_DIR"

for arg in "$@"; do
    case "$arg" in
        --boot-only)   MODE="boot" ;;
        --rootfs-only) MODE="rootfs" ;;
        --fw-dir=*)    FW_DIR="${arg#--fw-dir=}" ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        -*) err "未知选项: $arg" ;;
        *)  DEV="$arg" ;;
    esac
done

# ─── 检查固件文件 ────────────────────────────────────────────────
UBIBOOT="$FW_DIR/ubiboot-rg350.bin"
KERNEL="$FW_DIR/UZIMAGE.BIN"
ROOTFS_TAR="$FW_DIR/rootfs.tar.gz"

[[ -f "$UBIBOOT" ]]  || err "ubiboot-rg350.bin 不存在: $UBIBOOT"
[[ -f "$KERNEL" ]]    || err "UZIMAGE.BIN 不存在: $KERNEL"
[[ -f "$ROOTFS_TAR" ]] || err "rootfs.tar.gz 不存在: $ROOTFS_TAR"

# ─── 检查设备 ────────────────────────────────────────────────────
[[ -z "$DEV" ]] && err "请指定 SD 卡设备, 如: $0 /dev/sdX"
[[ -b "$DEV" ]] || err "$DEV 不是块设备"
[[ "$(id -u)" -eq 0 ]] || err "需要 root 权限 (请用 sudo)"

ROOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
[[ "$DEV" == "$ROOT_DEV" ]] && err "$DEV 是系统盘! 拒绝操作"

# ─── 确认 ────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo " 目标设备: $DEV"
echo " 模式:     $MODE"
echo " UBIBoot:  $UBIBOOT ($(du -h "$UBIBOOT" | cut -f1))"
echo " 内核:     $KERNEL ($(du -h "$KERNEL" | cut -f1))"
echo " Rootfs:   $ROOTFS_TAR ($(du -h "$ROOTFS_TAR" | cut -f1))"
echo "========================================="
echo ""
printf "${c_y}警告: $DEV 上的所有数据将被擦除!${c_n}\n"
echo ""
read -p "确认继续? (输入 YES): " confirm
[[ "$confirm" == "YES" ]] || { echo "已取消"; exit 0; }

# ─── 卸载 ────────────────────────────────────────────────────────
log "卸载 ${DEV}* ..."
umount "${DEV}"* 2>/dev/null || true
sleep 1

# ─── 写入 UBIBoot ────────────────────────────────────────────────
log "写入 UBIBoot → sector 1 ..."
dd if="$UBIBOOT" of="$DEV" bs=512 seek=1 conv=notrunc 2>/dev/null
ok "UBIBoot"

# 验证 LPSM 魔数
MAGIC=$(dd if="$DEV" bs=1 skip=512 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
[[ "$MAGIC" == "4c50534d" ]] || err "LPSM 魔数不匹配: $MAGIC"
ok "LPSM 魔数验证通过"

if [[ "$MODE" == "full" || "$MODE" == "boot" ]]; then
    # ─── 创建分区表 ──────────────────────────────────────────────
    log "创建 MBR 分区表 ..."
    BOOT_START=8192
    BOOT_SIZE=819200   # 400 MB
    sfdisk --quiet "$DEV" <<EOF
label: dos
unit: sectors

${DEV}1 : start=${BOOT_START}, size=${BOOT_SIZE}, type=0c, bootable
${DEV}2 : start=$((BOOT_START + BOOT_SIZE)), type=83
EOF
    ok "分区表已创建"

    log "格式化 ..."
    sleep 1
    partprobe "$DEV" 2>/dev/null || true
    sleep 1
    mkfs.vfat -F 32 -n "BOOT" "${DEV}1"
    ok "FAT32 BOOT 分区"

    # ─── 写入内核 ────────────────────────────────────────────────
    MP=$(mktemp -d)
    mount "${DEV}1" "$MP"
    cp "$KERNEL" "$MP/UZIMAGE.BIN"
    sync
    echo "BOOT 分区:"
    ls -lh "$MP/"
    umount "$MP"
    rmdir "$MP"
    ok "内核已写入"
fi

if [[ "$MODE" == "full" || "$MODE" == "rootfs" ]]; then
    # ─── rootfs 分区 ─────────────────────────────────────────────
    if [[ "$MODE" == "rootfs" ]]; then
        # rootfs-only: 检查 p2 是否存在
        [[ -b "${DEV}2" ]] || err "${DEV}2 不存在, 请用完整模式先创建分区"
    else
        mkfs.ext4 -L rootfs "${DEV}2"
        ok "ext4 rootfs 分区"
    fi

    log "部署 rootfs ..."
    MP=$(mktemp -d)
    mount "${DEV}2" "$MP"
    tar -xzf "$ROOTFS_TAR" -C "$MP"
    sync
    du -sh "$MP/"
    umount "$MP"
    rmdir "$MP"
    ok "rootfs 已部署"
fi

echo ""
ok "刷写完成! 插卡开机, 串口 (UART2 57600) 可观察启动过程"
