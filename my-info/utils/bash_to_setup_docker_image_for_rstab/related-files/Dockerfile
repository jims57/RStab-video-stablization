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

# 克隆 RStab 仓库 (使用 GitHub 镜像, 如果在中国)
# 尝试多个镜像源: FastGit, CNPMJS, gitclone.com
RUN if [ "$USE_CHINA_MIRROR" = "true" ]; then \
        echo "使用 GitHub 镜像克隆 RStab..." && \
        ( git clone https://hub.fastgit.xyz/pzzz-cv/RStab.git /mnt/rstab/RStab && echo "FastGit 成功" ) || \
        ( rm -rf /mnt/rstab/RStab; git clone https://github.com.cnpmjs.org/pzzz-cv/RStab.git /mnt/rstab/RStab && echo "CNPMJS 成功" ) || \
        ( rm -rf /mnt/rstab/RStab; git clone https://gitclone.com/github.com/pzzz-cv/RStab.git /mnt/rstab/RStab && echo "gitclone.com 成功" ) || \
        ( rm -rf /mnt/rstab/RStab; git clone https://github.akams.cn/pzzz-cv/RStab.git /mnt/rstab/RStab && echo "akams 成功" ) || \
        ( rm -rf /mnt/rstab/RStab; echo "所有镜像失败, 尝试直接克隆..."; git clone https://github.com/pzzz-cv/RStab.git /mnt/rstab/RStab ) && \
        cd /mnt/rstab/RStab && \
        git config --global url."https://hub.fastgit.xyz/".insteadOf "https://github.com/" && \
        git submodule update --init --recursive || \
        ( git config --global url."https://github.com.cnpmjs.org/".insteadOf "https://github.com/" && git submodule update --init --recursive ) || \
        echo "submodule 更新失败, 继续..."; \
    else \
        git clone https://github.com/pzzz-cv/RStab.git --recursive /mnt/rstab/RStab; \
    fi

# 安装 PyTorch (兼容 CUDA 11.8, 向后兼容 11.x 和部分 12.x)
RUN pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 torchaudio==2.0.2+cu118 --extra-index-url https://download.pytorch.org/whl/cu118

# 安装 RStab 依赖
WORKDIR /mnt/rstab/RStab
RUN pip install -r requirements.txt

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
