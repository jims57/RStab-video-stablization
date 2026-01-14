# RStab Video Stabilization Docker Image
# 支持 Deep3D 和 MonST3R 两种预处理模式
# 兼容 CUDA 11.x 和 12.x 环境
# 支持中国网络 (使用 GitHub 镜像)

FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

# 构建参数: 是否使用中国镜像 (默认 false)
ARG USE_CHINA_MIRROR=false

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=$CUDA_HOME/bin:$PATH
ENV LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# 设置工作目录
WORKDIR /mnt/rstab

# 配置 Ubuntu 镜像源 (中国使用阿里云镜像)
RUN if [ "$USE_CHINA_MIRROR" = "true" ]; then \
        echo "配置阿里云 Ubuntu 镜像源..." && \
        sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list && \
        sed -i 's|http://security.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list; \
    fi

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    vim \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    unzip \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    cmake \
    build-essential \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# 设置 Python 3.10 为默认
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# 升级 pip (使用清华镜像加速, 如果在中国)
RUN if [ "$USE_CHINA_MIRROR" = "true" ]; then \
        pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
        pip install --upgrade pip setuptools wheel; \
    else \
        pip install --upgrade pip setuptools wheel; \
    fi

# 安装 gdown 用于下载 Google Drive 文件
RUN pip install gdown

# 复制本地 RStab 代码 (由于 GitHub 在中国被封锁，需要预先准备代码)
# 代码应该放在 related-files/RStab/ 目录下
COPY RStab /mnt/rstab/RStab

# 验证 RStab 代码是否存在 (关键文件检查)
RUN echo "=== 验证 RStab 代码 ===" && \
    ls -la /mnt/rstab/RStab/ && \
    if [ ! -f "/mnt/rstab/RStab/Deep3D/geometry_optimizer.py" ]; then \
        echo "错误: Deep3D/geometry_optimizer.py 不存在!" && \
        echo "请确保 RStab 代码已放置在 related-files/RStab/ 目录下" && \
        exit 1; \
    fi && \
    if [ ! -d "/mnt/rstab/RStab/RStab_core" ]; then \
        echo "错误: RStab_core 目录不存在!" && \
        exit 1; \
    fi && \
    echo "RStab 代码验证通过!"

# 安装 PyTorch (兼容 CUDA 11.8, 向后兼容 11.x 和部分 12.x)
RUN pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 torchaudio==2.0.2+cu118 --extra-index-url https://download.pytorch.org/whl/cu118

# 调试: 列出克隆后的目录内容
RUN echo "=== RStab 目录内容 ===" && ls -la /mnt/rstab/RStab/ && \
    echo "=== 检查 requirements.txt ===" && \
    (cat /mnt/rstab/RStab/requirements.txt 2>/dev/null || echo "requirements.txt 不存在")

# 安装 RStab 依赖
WORKDIR /mnt/rstab/RStab

# 检查 requirements.txt 是否存在，如果不存在则手动安装核心依赖
RUN if [ -f "requirements.txt" ]; then \
        echo "找到 requirements.txt, 安装依赖..." && \
        pip install -r requirements.txt; \
    else \
        echo "requirements.txt 不存在, 手动安装核心依赖..." && \
        pip install numpy opencv-python pillow scipy tqdm einops timm && \
        pip install transformers accelerate && \
        pip install roma gradio matplotlib; \
    fi

# 创建 checkpoint 目录 (需要手动下载 checkpoint)
# RStab checkpoint: https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view
# 下载后放到 /root/rstab_checkpoints/ 目录，脚本会自动挂载
RUN mkdir -p /mnt/rstab/RStab/RStab_core/pretrained /mnt/rstab/checkpoints

# 设置 MonST3R 环境
WORKDIR /mnt/rstab/RStab/MonST3R

# 安装 MonST3R 依赖
RUN pip install -r requirements.txt || true
RUN pip install -r requirements_optional.txt || true

# 创建 MonST3R checkpoint 目录 (需要手动下载 checkpoint)
# MonST3R checkpoint: https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view
RUN mkdir -p /mnt/rstab/RStab/MonST3R/checkpoints

# 编译 RoPE CUDA kernels (可选，加速用)
WORKDIR /mnt/rstab/RStab/MonST3R/croco/models/curope
RUN python setup.py build_ext --inplace || echo "RoPE CUDA kernels compilation skipped (optional)"

# 创建输入输出目录
RUN mkdir -p /mnt/rstab/input /mnt/rstab/output/Deep3D /mnt/rstab/output/RStab /mnt/rstab/output/MonST3R

# 回到工作目录
WORKDIR /mnt/rstab/RStab

# 复制运行脚本
COPY run_rstab.sh /mnt/rstab/run_rstab.sh
RUN chmod +x /mnt/rstab/run_rstab.sh

# 设置入口点
ENTRYPOINT ["/bin/bash"]
