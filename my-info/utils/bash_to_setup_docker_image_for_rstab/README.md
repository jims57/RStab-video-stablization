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

## \u76ee\u5f55\u7ed3\u6784

```
/root/
\u251c\u2500\u2500 bash_to_setup_docker_image_for_rstab/   # \u811a\u672c\u76ee\u5f55
\u2502   \u251c\u2500\u2500 bash_to_setup_docker_image_for_rstab.sh
\u2502   \u251c\u2500\u2500 related-files/
\u2502   \u2502   \u251c\u2500\u2500 Dockerfile
\u2502   \u2502   \u2514\u2500\u2500 run_rstab.sh
\u2502   \u2514\u2500\u2500 videos/
\u2502       \u2514\u2500\u2500 jiangbo-1min.mp4
\u251c\u2500\u2500 rstab_input/                            # \u8f93\u5165\u89c6\u9891\u76ee\u5f55 (\u53ef\u76f4\u63a5\u8bbf\u95ee)
\u251c\u2500\u2500 rstab_output/                           # \u8f93\u51fa\u7ed3\u679c\u76ee\u5f55 (\u53ef\u76f4\u63a5\u8bbf\u95ee)
\u2514\u2500\u2500 rstab_checkpoints/                      # Checkpoint \u76ee\u5f55
    \u251c\u2500\u2500 RStab/                              # RStab checkpoint (\u5fc5\u9700)
    \u2502   \u2514\u2500\u2500 *.pth
    \u2514\u2500\u2500 MonST3R/                            # MonST3R checkpoint (\u53ef\u9009)
        \u2514\u2500\u2500 MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth
```

## \u547d\u4ee4\u8bf4\u660e

| \u547d\u4ee4 | \u8bf4\u660e |
|------|------|
| `./bash_to_setup_docker_image_for_rstab.sh build` | \u6784\u5efa Docker \u955c\u50cf\u5e76\u81ea\u52a8\u4e0b\u8f7d Checkpoints |
| `./bash_to_setup_docker_image_for_rstab.sh stabilize` | \u4f7f\u7528\u9ed8\u8ba4 demo \u89c6\u9891\u8fd0\u884c\u7a33\u5b9a\u5316 (Deep3D) |
| `./bash_to_setup_docker_image_for_rstab.sh stabilize /path/to/video.mp4` | \u4f7f\u7528\u81ea\u5b9a\u4e49\u89c6\u9891\u8fd0\u884c\u7a33\u5b9a\u5316 (Deep3D) |
| `./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r` | \u4f7f\u7528\u9ed8\u8ba4 demo \u89c6\u9891\u8fd0\u884c\u7a33\u5b9a\u5316 (MonST3R) |
| `./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r /path/to/video.mp4` | \u4f7f\u7528\u81ea\u5b9a\u4e49\u89c6\u9891\u8fd0\u884c\u7a33\u5b9a\u5316 (MonST3R) |
| `./bash_to_setup_docker_image_for_rstab.sh run` | \u8fdb\u5165\u5bb9\u5668\u4ea4\u4e92\u6a21\u5f0f (\u7528\u4e8e\u8c03\u8bd5) |
| `./bash_to_setup_docker_image_for_rstab.sh stop` | \u505c\u6b62\u8fd0\u884c\u4e2d\u7684\u5bb9\u5668 |
| `./bash_to_setup_docker_image_for_rstab.sh clean` | \u5220\u9664\u955c\u50cf\u548c\u5bb9\u5668 |
| `./bash_to_setup_docker_image_for_rstab.sh help` | \u663e\u793a\u5e2e\u52a9\u4fe1\u606f |

## \u8be6\u7ec6\u4f7f\u7528\u793a\u4f8b

### Case 1: \u4f7f\u7528\u9ed8\u8ba4 Demo \u89c6\u9891 (jiangbo-1min.mp4)

```bash
# Deep3D \u6a21\u5f0f (\u63a8\u8350)
./bash_to_setup_docker_image_for_rstab.sh stabilize

# MonST3R \u6a21\u5f0f
./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r
```

### Case 2: \u4f7f\u7528\u81ea\u5b9a\u4e49\u89c6\u9891

```bash
# Deep3D \u6a21\u5f0f - \u6307\u5b9a\u89c6\u9891\u7edd\u5bf9\u8def\u5f84
./bash_to_setup_docker_image_for_rstab.sh stabilize /root/my_videos/shaky_video.mp4

# MonST3R \u6a21\u5f0f - \u6307\u5b9a\u89c6\u9891\u7edd\u5bf9\u8def\u5f84
./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r /root/my_videos/shaky_video.mp4

# \u89c6\u9891\u4f1a\u81ea\u52a8\u590d\u5236\u5230 /root/rstab_input/ \u76ee\u5f55
```

### Case 3: \u8fdb\u5165\u5bb9\u5668\u4ea4\u4e92\u6a21\u5f0f (\u7528\u4e8e\u8c03\u8bd5)

`run` \u547d\u4ee4\u7528\u4e8e\u8fdb\u5165 Docker \u5bb9\u5668\u7684\u4ea4\u4e92\u5f0f bash shell\uff0c\u9002\u7528\u4e8e:
- \u8c03\u8bd5\u95ee\u9898
- \u67e5\u770b\u5bb9\u5668\u5185\u90e8\u6587\u4ef6
- \u624b\u52a8\u8fd0\u884c\u547d\u4ee4
- \u68c0\u67e5\u73af\u5883\u914d\u7f6e

```bash
# \u8fdb\u5165\u5bb9\u5668
./bash_to_setup_docker_image_for_rstab.sh run

# \u8fdb\u5165\u540e\u4f60\u4f1a\u770b\u5230 bash \u63d0\u793a\u7b26\uff0c\u53ef\u4ee5\u624b\u52a8\u8fd0\u884c\u547d\u4ee4:
cd /mnt/rstab
ls -la                                    # \u67e5\u770b\u6587\u4ef6\u7ed3\u6784
./run_rstab.sh video.mp4                  # \u624b\u52a8\u8fd0\u884c\u7a33\u5b9a\u5316
./run_rstab.sh video.mp4 monst3r          # MonST3R \u6a21\u5f0f
exit                                      # \u9000\u51fa\u5bb9\u5668
```

### Case 4: \u67e5\u770b\u8f93\u51fa\u7ed3\u679c

\u8f93\u51fa\u7ed3\u679c\u76f4\u63a5\u5728\u670d\u52a1\u5668\u4e0a\u53ef\u89c1\uff0c\u65e0\u9700\u8fdb\u5165\u5bb9\u5668:

```bash
# \u67e5\u770b\u8f93\u51fa\u76ee\u5f55
ls -la /root/rstab_output/

# \u67e5\u770b Deep3D \u8f93\u51fa
ls -la /root/rstab_output/Deep3D/

# \u67e5\u770b RStab \u6700\u7ec8\u7ed3\u679c
ls -la /root/rstab_output/RStab/
```

## GPU \u5185\u5b58\u8981\u6c42

| GPU | \u663e\u5b58 | \u5efa\u8bae\u89c6\u9891\u65f6\u957f |
|-----|------|--------------|
| RTX 3070 | 8GB | < 30\u79d2 |
| RTX 3080 | 10GB | < 45\u79d2 |
| RTX 3090 / A10 | 24GB | < 2\u5206\u949f |
| A100 | 40GB/80GB | \u66f4\u957f\u89c6\u9891 |

\u5982\u679c\u9047\u5230 `CUDA out of memory` \u9519\u8bef\uff0c\u8bf7\u5c1d\u8bd5:
1. \u4f7f\u7528\u66f4\u77ed\u7684\u89c6\u9891
2. \u4f7f\u7528\u66f4\u5927\u663e\u5b58\u7684 GPU
3. \u964d\u4f4e\u89c6\u9891\u5206\u8fa8\u7387

## \u6545\u969c\u6392\u9664

### \u95ee\u9898: CUDA out of memory

```
torch.OutOfMemoryError: CUDA out of memory
```

**\u89e3\u51b3\u65b9\u6848**: \u89c6\u9891\u592a\u957f\uff0c\u8bf7\u4f7f\u7528\u66f4\u77ed\u7684\u89c6\u9891 (\u5efa\u8bae <30\u79d2 \u5bf9\u4e8e 8GB GPU)

### \u95ee\u9898: poses.npy not found

```
FileNotFoundError: No such file or directory: '../output/Deep3D/xxx/poses.npy'
```

**\u89e3\u51b3\u65b9\u6848**: Deep3D \u9884\u5904\u7406\u5931\u8d25 (\u901a\u5e38\u662f GPU \u5185\u5b58\u4e0d\u8db3)\uff0c\u8bf7\u4f7f\u7528\u66f4\u77ed\u7684\u89c6\u9891

### \u95ee\u9898: Checkpoint \u4e0b\u8f7d\u5931\u8d25

\u5982\u679c\u81ea\u52a8\u4e0b\u8f7d\u5931\u8d25\uff0c\u8bf7\u53c2\u8003\u4e0a\u65b9 "\u624b\u52a8\u4e0b\u8f7d Checkpoints" \u90e8\u5206