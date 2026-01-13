# RStab Docker Setup

## Quick Start

```bash
# 1. 上传整个文件夹到服务器 /root/
# 2. 进入目录并添加执行权限
cd /root/bash_to_setup_docker_image_for_rstab
chmod +x bash_to_setup_docker_image_for_rstab.sh

# 3. 构建 Docker 镜像
./bash_to_setup_docker_image_for_rstab.sh build

# 4. 下载 Checkpoint (见下方说明)

# 5. 运行 Demo
./bash_to_setup_docker_image_for_rstab.sh demo
```

## Checkpoint 下载 (必需)

由于 Google Drive 下载限制，需要手动下载 Checkpoint 文件。

### 1. RStab Checkpoint (必需)

| 项目 | 内容 |
|------|------|
| 下载链接 | https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view |
| 目标目录 | `/root/rstab_checkpoints/RStab/` |
| 文件格式 | zip 压缩包，需解压 |

**命令行下载 (无需浏览器):**
```bash
# 安装 gdown (如果没有)
pip install gdown

# 创建目录并下载
mkdir -p /root/rstab_checkpoints/RStab
cd /root/rstab_checkpoints/RStab

# 方法1: 使用 gdown 下载 (推荐)
gdown --fuzzy "https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view"

# 方法2: 如果 gdown 失败，使用 wget + Google Drive 直链
# 文件ID: 1q3QM1damtvHLukhIOIAdv9IKm646Oj11
wget --no-check-certificate "https://drive.google.com/uc?export=download&id=1q3QM1damtvHLukhIOIAdv9IKm646Oj11&confirm=t" -O checkpoint.zip

# 解压
unzip checkpoint.zip

# 验证文件
ls -la /root/rstab_checkpoints/RStab/
# 应该看到 *.pth 文件
```

### 2. MonST3R Checkpoint (可选)

仅当使用 MonST3R 模式时需要。

| 项目 | 内容 |
|------|------|
| 下载链接 | https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view |
| 目标路径 | `/root/rstab_checkpoints/MonST3R/MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth` |
| 文件格式 | 单个 .pth 文件 |

**命令行下载 (无需浏览器):**
```bash
# 创建目录
mkdir -p /root/rstab_checkpoints/MonST3R
cd /root/rstab_checkpoints/MonST3R

# 方法1: 使用 gdown 下载 (推荐)
gdown --fuzzy "https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view"

# 方法2: 如果 gdown 失败，使用 wget
# 文件ID: 1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa
wget --no-check-certificate "https://drive.google.com/uc?export=download&id=1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa&confirm=t" -O MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth

# 验证文件
ls -la /root/rstab_checkpoints/MonST3R/
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