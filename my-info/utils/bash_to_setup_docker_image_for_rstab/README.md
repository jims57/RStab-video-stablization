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
| `./bash_to_setup_docker_image_for_rstab.sh build` | 构建 Docker 镜像并下载 Checkpoints |
| `./bash_to_setup_docker_image_for_rstab.sh stabilize [视频] [开始] [结束]` | 运行视频稳定化 (Deep3D 模式) |
| `./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r [视频] [开始] [结束]` | 运行视频稳定化 (MonST3R 模式) |
| `./bash_to_setup_docker_image_for_rstab.sh run` | 进入容器交互模式 (用于调试) |
| `./bash_to_setup_docker_image_for_rstab.sh stop` | 停止运行中的容器 |
| `./bash_to_setup_docker_image_for_rstab.sh clean` | 删除镜像和容器 |
| `./bash_to_setup_docker_image_for_rstab.sh help` | 显示帮助信息 |

## 视频裁剪参数

由于 GPU 内存限制, 长视频可能导致 CUDA OOM 错误。可以使用裁剪参数处理视频的特定片段:

| 参数 | 格式 | 说明 |
|------|------|------|
| 开始时间 | HH:MM:SS | 不指定则从 00:00:00 开始 |
| 结束时间 | HH:MM:SS | 不指定则到视频结尾 |

**裁剪示例:**

```bash
# Case A: 只指定结束时间 - 裁剪前15秒 (从00:00:00到00:00:15)
./bash_to_setup_docker_image_for_rstab.sh stabilize /path/to/video.mp4 '' 00:00:15

# Case B: 只指定开始时间 - 从10秒开始到视频结尾
./bash_to_setup_docker_image_for_rstab.sh stabilize /path/to/video.mp4 00:00:10 ''

# Case C: 同时指定开始和结束时间 - 裁剪5秒到20秒的片段
./bash_to_setup_docker_image_for_rstab.sh stabilize /path/to/video.mp4 00:00:05 00:00:20
```

## 详细使用示例

### Case 1: 使用默认 Demo 视频

```bash
# Deep3D 模式 (推荐)
./bash_to_setup_docker_image_for_rstab.sh stabilize

# MonST3R 模式
./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r
```

### Case 2: 使用自定义视频

```bash
# Deep3D 模式 - 指定视频绝对路径
./bash_to_setup_docker_image_for_rstab.sh stabilize /root/my_videos/shaky_video.mp4

# MonST3R 模式 - 指定视频绝对路径
./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r /root/my_videos/shaky_video.mp4

# 视频会自动复制到 /root/rstab_input/ 目录
```

### Case 3: 使用视频裁剪 (避免 GPU 内存不足)

```bash
# 裁剪前15秒并稳定化 (推荐用于 8GB GPU)
./bash_to_setup_docker_image_for_rstab.sh stabilize /root/my_videos/long_video.mp4 '' 00:00:15

# 裁剪10秒到25秒的片段
./bash_to_setup_docker_image_for_rstab.sh stabilize /root/my_videos/long_video.mp4 00:00:10 00:00:25

# MonST3R 模式裁剪前20秒
./bash_to_setup_docker_image_for_rstab.sh stabilize-monst3r /root/my_videos/long_video.mp4 '' 00:00:20
```

### Case 4: 进入容器交互模式 (用于调试)

`run` 命令用于进入 Docker 容器的交互式 bash shell, 适用于:
- 调试问题
- 查看容器内部文件
- 手动运行命令
- 检查环境配置

```bash
# 进入容器
./bash_to_setup_docker_image_for_rstab.sh run

# 进入后你会看到 bash 提示符, 可以手动运行命令:
cd /mnt/rstab
ls -la                                    # 查看文件结构
./run_rstab.sh video.mp4                  # 手动运行稳定化
./run_rstab.sh video.mp4 monst3r          # MonST3R 模式
exit                                      # 退出容器
```

### Case 5: 查看输出结果

输出结果直接在服务器上可见, 无需进入容器:

```bash
# 查看输出目录
ls -la /root/rstab_output/

# 查看 Deep3D 输出
ls -la /root/rstab_output/Deep3D/

# 查看 RStab 最终结果 (稳定化后的视频)
ls -la /root/rstab_output/RStab/
```

## GPU 内存要求

| GPU | 显存 | 建议视频时长 |
|-----|------|--------------|
| RTX 3070 | 8GB | < 30秒 |
| RTX 3080 | 10GB | < 45秒 |
| RTX 3090 / A10 | 24GB | < 2分钟 |
| A100 | 40GB/80GB | 更长视频 |

如果遇到 `CUDA out of memory` 错误, 请尝试:
1. 使用更短的视频
2. 使用更大显存的 GPU
3. 降低视频分辨率

## 故障排除

### 问题: CUDA out of memory

```
torch.OutOfMemoryError: CUDA out of memory
```

**解决方案**: 视频太长, 请使用更短的视频 (建议 <30秒 对于 8GB GPU)

可以用 ffmpeg 裁剪视频:
```bash
# 裁剪前20秒
ffmpeg -i input.mp4 -t 20 -c copy output_20s.mp4
```

### 问题: poses.npy not found

```
FileNotFoundError: No such file or directory: '../output/Deep3D/xxx/poses.npy'
```

**解决方案**: Deep3D 预处理失败 (通常是 GPU 内存不足), 请使用更短的视频

### 问题: Checkpoint 下载失败

如果自动下载失败, 请参考上方 "手动下载 Checkpoints" 部分