# RStab Docker Setup

RStab 是一个基于深度学习的视频稳定化框架，支持 Deep3D 和 MonST3R 两种预处理模式。

## 前置要求

- Ubuntu 服务器 (推荐 22.04)
- NVIDIA GPU (推荐 8GB+ 显存)
- NVIDIA 驱动已安装
- Docker 已安装
- nvidia-docker 已安装

## 完整安装步骤

### Step 1: 上传文件到服务器

将整个 `bash_to_setup_docker_image_for_rstab` 文件夹上传到服务器的 `/root/` 目录:

```bash
# 使用 scp 上传 (在本地 Mac 执行)
scp -r bash_to_setup_docker_image_for_rstab root@your_server_ip:/root/

# 或使用 rsync
rsync -avz bash_to_setup_docker_image_for_rstab root@your_server_ip:/root/
```

### Step 2: 登录服务器并进入目录

```bash
ssh root@your_server_ip
cd /root/bash_to_setup_docker_image_for_rstab
```

### Step 3: 添加执行权限

```bash
chmod +x bash_to_setup_docker_image_for_rstab.sh
chmod +x related-files/run_rstab.sh
```

### Step 4: 构建 Docker 镜像并下载 Checkpoints

```bash
./bash_to_setup_docker_image_for_rstab.sh build
```

这个命令会自动:
1. 检查系统环境 (Docker, NVIDIA GPU)
2. 安装必要工具 (unzip, gdown)
3. 修复可能的 dpkg 错误
4. 构建 Docker 镜像 (约 33GB)
5. 自动下载 RStab 和 MonST3R Checkpoints

构建时间约 15-30 分钟，取决于网络速度。

### Step 5: 运行 Demo 测试

```bash
# Deep3D 模式 (推荐)
./bash_to_setup_docker_image_for_rstab.sh demo

# 或 MonST3R 模式
./bash_to_setup_docker_image_for_rstab.sh demo-monst3r
```

### Step 6: 查看输出结果

```bash
ls -la /root/rstab_output/
```

## 手动下载 Checkpoints (如果自动下载失败)

如果 Google Drive 下载受限，可以手动下载:

### RStab Checkpoint (必需)

| 项目 | 内容 |
|------|------|
| 下载链接 | https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view |
| 目标目录 | `/root/rstab_checkpoints/RStab/` |
| 文件格式 | zip 压缩包，需解压 |

```bash
pip install gdown
mkdir -p /root/rstab_checkpoints/RStab
cd /root/rstab_checkpoints/RStab
gdown --fuzzy "https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view"
unzip checkpoint.zip
```

### MonST3R Checkpoint (可选)

| 项目 | 内容 |
|------|------|
| 下载链接 | https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view |
| 目标路径 | `/root/rstab_checkpoints/MonST3R/MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth` |

```bash
mkdir -p /root/rstab_checkpoints/MonST3R
cd /root/rstab_checkpoints/MonST3R
gdown --fuzzy "https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view"
```

## 目录结构

```
/root/
├── bash_to_setup_docker_image_for_rstab/   # 脚本目录
│   ├── bash_to_setup_docker_image_for_rstab.sh
│   ├── related-files/
│   │   ├── Dockerfile
│   │   └── run_rstab.sh
│   └── videos/
│       └── jiangbo-1min.mp4
├── rstab_input/                            # 输入视频目录
├── rstab_output/                           # 输出结果目录
└── rstab_checkpoints/                      # Checkpoint 目录
    ├── RStab/                              # RStab checkpoint (必需)
    │   └── *.pth
    └── MonST3R/                            # MonST3R checkpoint (可选)
        └── MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth
```

## 命令说明

| 命令 | 说明 |
|------|------|
| `./bash_to_setup_docker_image_for_rstab.sh build` | 构建 Docker 镜像 |
| `./bash_to_setup_docker_image_for_rstab.sh run` | 交互模式进入容器 |
| `./bash_to_setup_docker_image_for_rstab.sh demo` | 运行 Demo (Deep3D 模式) |
| `./bash_to_setup_docker_image_for_rstab.sh demo-monst3r` | 运行 Demo (MonST3R 模式) |
| `./bash_to_setup_docker_image_for_rstab.sh stop` | 停止容器 |
| `./bash_to_setup_docker_image_for_rstab.sh clean` | 删除镜像和容器 |
| `./bash_to_setup_docker_image_for_rstab.sh help` | 显示帮助 |

## 在容器内运行自定义视频

```bash
# 1. 将视频放到 /root/rstab_input/ 目录
cp your_video.mp4 /root/rstab_input/

# 2. 进入容器
./bash_to_setup_docker_image_for_rstab.sh run

# 3. 在容器内运行
cd /mnt/rstab
./run_rstab.sh your_video.mp4           # Deep3D 模式
./run_rstab.sh your_video.mp4 monst3r   # MonST3R 模式

# 4. 输出结果在 /root/rstab_output/ 目录
```