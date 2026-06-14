# RG350 Build

Anbernic RG350 (Ingenic JZ4770) 嵌入式 Linux 构建系统。

## 组件

| 组件 | 版本 | 用途 |
|------|------|------|
| [RG350_UBIBoot](https://github.com/tonyjih/RG350_UBIBoot) | fork | Bootloader, 从 SD 卡加载内核 |
| [Linux](https://github.com/gregkh/linux) | 7.0.12 | 主线内核, 10 个 RG350 补丁 |
| [BusyBox](https://busybox.net) | latest | Stage 1 initramfs |
| [Buildroot](https://buildroot.org) | 2025.08 | 完整 rootfs (Mesa Etnaviv GPU) |

## 快速开始

### 1. 下载固件

从 [Actions](../../actions) 最新成功构建下载 `rg350-firmware`，解压得到:

```
ubiboot-rg350.bin   UBIBoot bootloader
UZIMAGE.BIN         Linux 内核
rootfs.tar.gz       根文件系统
```

### 2. 刷入 SD 卡

```bash
sudo ./flash-sdcard.sh /dev/sdX
```

脚本会:
- 写入 UBIBoot 到 sector 1
- 创建 MBR 分区 (FAT32 boot + ext4 rootfs)
- 复制内核到 boot 分区
- 部署 rootfs 到 ext4 分区

### 3. 插卡开机

将 SD 卡插入 RG350，开机。串口 (UART2 57600) 可观察启动过程。

## SD 卡分区布局

| 偏移 | 内容 |
|------|------|
| Sector 0 | MBR |
| Sector 1 | UBIBoot |
| Sector 8192 | FAT32 BOOT (UZIMAGE.BIN) |
| Sector 827392 | ext4 rootfs |

## 补丁说明

### Linux 内核 (10 patches)

- MIPS zboot: 栈保护泄露修复, DEBUG_ZBOOT 自动选择
- Input: L2/R2/L3/R3/VOL 按键, ADC 双摇杆
- DMA: jz4780 tx_status NULL 指针修复
- DRM: bridge refcount 修复, nt39016 SPI 警告消除
- MMC: jz4740 DMA 竞态修复

### UBIBoot (1 patch)

- LD_ADDR 适配 Linux 7.0.12
- 禁用 mininit-syspart (使用内嵌 initramfs)
- 串口调试输出

### Buildroot (4 patches)

- rg350_defconfig + board overlay
- Mesa Etnaviv GPU 支持

## License

各组件遵循其原始许可证: GPLv2 / GPLv2+
