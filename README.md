# RG350 Build

Anbernic RG350 (Ingenic JZ4770) 嵌入式 Linux 构建系统。

## 组件

| 组件 | 版本 | 用途 |
|------|------|------|
| [RG350_UBIBoot](https://github.com/tonyjih/RG350_UBIBoot) | fork | Bootloader, 从 SD 卡加载内核 |
| [Linux](https://github.com/gregkh/linux) | 7.0.12 | 主线内核, 10 个 RG350 补丁 |
| [BusyBox](https://busybox.net) | 1.39.0 | Stage 1 initramfs |
| [Buildroot](https://buildroot.org) | 2025.08 | 完整 rootfs (Mesa Etnaviv GPU) |

## 快速开始

### 使用预编译镜像

1. 从 [Releases](../../releases) 下载 `rg350.img`
2. 刷入 SD 卡:
   ```bash
   sudo dd if=rg350.img of=/dev/sdX bs=4M status=progress
   sync
   ```
3. 插入 RG350, 开机

### 从源码构建

使用 GitHub Actions (推荐): 推送到 main 分支后自动构建, 产物在 Actions → Artifacts 下载。

本地构建: 参见 `.github/workflows/build.yml` 中的步骤。

## SD 卡分区布局

| 偏移 | 大小 | 内容 |
|------|------|------|
| Sector 0 | 512B | MBR |
| Sector 1 | ~8KB | UBIBoot bootloader |
| Sector 8192 | 400MB | FAT32 BOOT 分区 (UZIMAGE.BIN) |
| Sector 827392 | 剩余 | ext4 rootfs 分区 |

## 补丁说明

### Linux 内核 (10 patches)

- MIPS zboot: 栈保护泄露修复, DEBUG_ZBOOT 自动选择
- Input: L2/R2/L3/R3/VOL 按键, ADC 双摇杆
- DMA: jz4780 tx_status NULL 指针修复
- DRM: bridge refcount 修复, nt39016 SPI 警告消除
- MMC: jz4740 DMA 竞态修复

### UBIBoot (1 patch)

- LD_ADDR 适配 Linux 7.0.12 (0x00b90000)
- 禁用 mininit-syspart (使用内嵌 initramfs)
- 串口调试输出

### Buildroot (4 patches)

- rg350_defconfig 和 board overlay
- dosfstools, fsck.fat 支持

## License

各组件遵循其原始许可证:
- Linux: GPLv2
- BusyBox: GPLv2
- Buildroot: GPLv2+
- UBIBoot: GPLv2
