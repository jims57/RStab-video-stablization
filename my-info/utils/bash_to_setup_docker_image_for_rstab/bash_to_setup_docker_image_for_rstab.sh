#!/bin/bash
#######################################################################################################
# RStab Docker 自动化构建和运行脚本
#######################################################################################################
#
# 用法:
#   chmod +x bash_to_setup_docker_image_for_rstab.sh
#   ./bash_to_setup_docker_image_for_rstab.sh [命令]
#
# 命令:
#   build       - 构建 Docker 镜像
#   run         - 运行 Docker 容器 (交互模式)
#   demo        - 运行 demo 视频稳定化 (jiangbo-1min.mp4)
#   demo-monst3r - 使用 MonST3R 模式运行 demo
#   stop        - 停止运行中的容器
#   clean       - 删除镜像和容器
#   help        - 显示帮助信息
#
# 示例:
#   ./bash_to_setup_docker_image_for_rstab.sh build    # 构建镜像
#   ./bash_to_setup_docker_image_for_rstab.sh run      # 启动容器
#   ./bash_to_setup_docker_image_for_rstab.sh demo     # 运行 demo
#
# 目录结构 (上传到服务器后):
#   /root/bash_to_setup_docker_image_for_rstab/
#   ├── bash_to_setup_docker_image_for_rstab.sh  (本脚本)
#   ├── related-files/
#   │   ├── Dockerfile
#   │   └── run_rstab.sh
#   └── videos/
#       └── jiangbo-1min.mp4  (demo 视频)
#
# 挂载目录 (可在服务器上直接访问):
#   /root/rstab_input/   - 输入视频目录
#   /root/rstab_output/  - 输出结果目录
#
# 容器内工作目录:
#   /mnt/rstab/RStab     - RStab 代码目录
#   /mnt/rstab/input/    - 输入视频 (挂载自 /root/rstab_input/)
#   /mnt/rstab/output/   - 输出结果 (挂载自 /root/rstab_output/)
#
# 在容器内运行稳定化:
#   ./run_rstab.sh <video_name> [mode]
#   例如: ./run_rstab.sh jiangbo-1min.mp4
#         ./run_rstab.sh jiangbo-1min.mp4 monst3r
#
# 兼容环境:
#   - NVIDIA A10 (CUDA 12.4) - 阿里云服务器
#   - NVIDIA RTX 3070 (CUDA 13.0/11.5) - Vast.ai 服务器
#   - 其他 NVIDIA GPU (CUDA 11.x - 12.x)
#
#######################################################################################################

set -e

# 配置
IMAGE_NAME="rstab"
IMAGE_TAG="latest"
CONTAINER_NAME="rstab-container"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 服务器上的挂载目录
HOST_INPUT_DIR="/root/rstab_input"
HOST_OUTPUT_DIR="/root/rstab_output"
HOST_CHECKPOINTS_DIR="/root/rstab_checkpoints"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 修复 dpkg 错误 (如果存在)
fix_dpkg_errors() {
    # 检查是否有 dpkg 错误
    if dpkg --configure -a 2>&1 | grep -q "error"; then
        log_warn "检测到 dpkg 错误，尝试修复..."
        
        # 修复 /etc/environment 中的错误
        if [ -f /etc/environment ]; then
            # 备份原文件
            cp /etc/environment /etc/environment.bak 2>/dev/null || true
            # 移除包含 ssh-ed25519 的错误行
            sed -i '/ssh-ed25519/d' /etc/environment 2>/dev/null || true
        fi
        
        # 重新配置 dpkg
        dpkg --configure -a 2>/dev/null || true
        
        log_info "dpkg 修复完成"
    fi
}

# 安装必要的系统工具
install_system_tools() {
    log_info "检查并安装必要的系统工具..."
    
    # 先修复可能的 dpkg 错误
    fix_dpkg_errors
    
    # 安装 unzip (如果没有)
    if ! command -v unzip &> /dev/null; then
        log_info "安装 unzip..."
        apt-get update -qq 2>/dev/null || true
        apt-get install -y unzip 2>/dev/null || {
            # 如果安装失败，尝试修复后重试
            fix_dpkg_errors
            apt-get install -y unzip
        }
    fi
    
    # 安装 ffmpeg (如果没有) - 用于视频裁剪
    if ! command -v ffmpeg &> /dev/null; then
        log_info "安装 ffmpeg..."
        apt-get update -qq 2>/dev/null || true
        apt-get install -y ffmpeg 2>/dev/null || {
            fix_dpkg_errors
            apt-get install -y ffmpeg
        }
    fi
    
    # 安装 gdown (如果没有)
    if ! command -v gdown &> /dev/null; then
        log_info "安装 gdown..."
        pip install gdown -q 2>/dev/null || pip3 install gdown -q 2>/dev/null || true
    fi
}

# 检查 Docker 和 NVIDIA Docker
check_prerequisites() {
    log_info "检查系统环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA 驱动未安装"
        exit 1
    fi
    
    log_info "NVIDIA GPU 信息:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    
    # 安装必要工具
    install_system_tools
    
    log_info "系统环境检查通过"
}

# 创建挂载目录
create_directories() {
    log_info "创建挂载目录..."
    mkdir -p "$HOST_INPUT_DIR"
    mkdir -p "$HOST_OUTPUT_DIR"
    mkdir -p "$HOST_CHECKPOINTS_DIR"
    log_info "输入目录: $HOST_INPUT_DIR"
    log_info "输出目录: $HOST_OUTPUT_DIR"
    log_info "Checkpoint 目录: $HOST_CHECKPOINTS_DIR"
}

# 下载 RStab checkpoint
download_rstab_checkpoint() {
    local RSTAB_DIR="$HOST_CHECKPOINTS_DIR/RStab"
    
    # 检查是否已存在
    if [ -d "$RSTAB_DIR" ] && [ -n "$(ls -A $RSTAB_DIR/*.pth 2>/dev/null)" ]; then
        log_info "RStab Checkpoint 已存在，跳过下载"
        return 0
    fi
    
    log_info "下载 RStab Checkpoint..."
    mkdir -p "$RSTAB_DIR"
    cd "$RSTAB_DIR"
    
    # 使用 gdown 下载
    if gdown --fuzzy "https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view" -O checkpoint.zip; then
        log_info "下载成功，解压中..."
        unzip -o checkpoint.zip
        rm -f checkpoint.zip
        log_info "RStab Checkpoint 下载完成"
    else
        log_warn "gdown 下载失败，尝试 wget..."
        wget --no-check-certificate "https://drive.google.com/uc?export=download&id=1q3QM1damtvHLukhIOIAdv9IKm646Oj11&confirm=t" -O checkpoint.zip
        if [ -f checkpoint.zip ]; then
            unzip -o checkpoint.zip
            rm -f checkpoint.zip
            log_info "RStab Checkpoint 下载完成"
        else
            log_error "RStab Checkpoint 下载失败!"
            log_error "请手动下载: https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view"
            log_error "解压到: $RSTAB_DIR/"
            return 1
        fi
    fi
}

# 下载 MonST3R checkpoint
download_monst3r_checkpoint() {
    local MONST3R_DIR="$HOST_CHECKPOINTS_DIR/MonST3R"
    local MONST3R_FILE="MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth"
    
    # 检查是否已存在
    if [ -f "$MONST3R_DIR/$MONST3R_FILE" ]; then
        log_info "MonST3R Checkpoint 已存在，跳过下载"
        return 0
    fi
    
    log_info "下载 MonST3R Checkpoint..."
    mkdir -p "$MONST3R_DIR"
    cd "$MONST3R_DIR"
    
    # 使用 gdown 下载
    if gdown --fuzzy "https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view" -O "$MONST3R_FILE"; then
        log_info "MonST3R Checkpoint 下载完成"
    else
        log_warn "gdown 下载失败，尝试 wget..."
        wget --no-check-certificate "https://drive.google.com/uc?export=download&id=1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa&confirm=t" -O "$MONST3R_FILE"
        if [ -f "$MONST3R_FILE" ]; then
            log_info "MonST3R Checkpoint 下载完成"
        else
            log_error "MonST3R Checkpoint 下载失败!"
            log_error "请手动下载: https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view"
            log_error "放到: $MONST3R_DIR/$MONST3R_FILE"
            return 1
        fi
    fi
}

# 下载所有 checkpoints
download_checkpoints() {
    log_info "检查并下载 Checkpoints..."
    
    # 下载 RStab checkpoint (必需)
    download_rstab_checkpoint || {
        log_error "RStab Checkpoint 下载失败，无法继续"
        exit 1
    }
    
    # 下载 MonST3R checkpoint (可选)
    download_monst3r_checkpoint || {
        log_warn "MonST3R Checkpoint 下载失败，MonST3R 模式将不可用"
    }
    
    log_info "Checkpoints 准备完成"
}

# 检查 RStab checkpoint 是否存在
check_checkpoints() {
    if [ ! -d "$HOST_CHECKPOINTS_DIR/RStab" ] || [ -z "$(ls -A $HOST_CHECKPOINTS_DIR/RStab 2>/dev/null)" ]; then
        log_warn "RStab Checkpoint 未找到，尝试下载..."
        download_rstab_checkpoint || {
            log_error "RStab Checkpoint 下载失败!"
            exit 1
        }
    fi
    log_info "RStab Checkpoint 已找到"
}

# 检查 MonST3R checkpoint 是否存在
check_checkpoints_monst3r() {
    check_checkpoints
    if [ ! -d "$HOST_CHECKPOINTS_DIR/MonST3R" ] || [ -z "$(ls -A $HOST_CHECKPOINTS_DIR/MonST3R 2>/dev/null)" ]; then
        log_warn "MonST3R Checkpoint 未找到，尝试下载..."
        download_monst3r_checkpoint || {
            log_error "MonST3R Checkpoint 下载失败!"
            exit 1
        }
    fi
    log_info "MonST3R Checkpoint 已找到"
}

# 复制 demo 视频到输入目录
copy_demo_video() {
    if [ -f "$SCRIPT_DIR/videos/jiangbo-1min.mp4" ]; then
        log_info "复制 demo 视频到输入目录..."
        cp "$SCRIPT_DIR/videos/jiangbo-1min.mp4" "$HOST_INPUT_DIR/"
        log_info "Demo 视频已复制: $HOST_INPUT_DIR/jiangbo-1min.mp4"
    else
        log_warn "Demo 视频不存在: $SCRIPT_DIR/videos/jiangbo-1min.mp4"
    fi
}

# 构建 Docker 镜像
build_image() {
    log_info "开始构建 Docker 镜像..."
    check_prerequisites
    create_directories
    
    cd "$SCRIPT_DIR/related-files"
    
    log_info "构建镜像: $IMAGE_NAME:$IMAGE_TAG"
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
    
    log_info "Docker 镜像构建完成!"
    docker images | grep "$IMAGE_NAME"
    
    # 自动下载 checkpoints
    echo ""
    log_info "========== 开始下载 Checkpoints =========="
    download_checkpoints
    log_info "========== 构建和下载全部完成 =========="
    echo ""
    log_info "现在可以运行:"
    log_info "  ./bash_to_setup_docker_image_for_rstab.sh stabilize                                      # 使用默认 demo 视频"
    log_info "  ./bash_to_setup_docker_image_for_rstab.sh stabilize /root/rstab_input/jiangbo-1min.mp4 '' 00:00:05  # 裁剪前5秒"
}

# 运行容器 (交互模式)
run_container() {
    log_info "启动 Docker 容器..."
    check_prerequisites
    create_directories
    copy_demo_video
    
    # 停止已存在的容器
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # 检查 checkpoint 是否存在
    check_checkpoints
    
    log_info "启动容器: $CONTAINER_NAME"
    docker run -it --gpus all \
        --name "$CONTAINER_NAME" \
        -v "$HOST_INPUT_DIR:/mnt/rstab/input" \
        -v "$HOST_OUTPUT_DIR:/mnt/rstab/output" \
        -v "$HOST_CHECKPOINTS_DIR/RStab:/mnt/rstab/RStab/RStab_core/pretrained" \
        -v "$HOST_CHECKPOINTS_DIR/MonST3R:/mnt/rstab/RStab/MonST3R/checkpoints" \
        -w /mnt/rstab \
        "$IMAGE_NAME:$IMAGE_TAG"
}

# 复制自定义视频到输入目录
copy_custom_video() {
    local VIDEO_PATH="$1"
    if [ -z "$VIDEO_PATH" ]; then
        return 0
    fi
    
    if [ -f "$VIDEO_PATH" ]; then
        local VIDEO_NAME=$(basename "$VIDEO_PATH")
        local DEST_PATH="$HOST_INPUT_DIR/$VIDEO_NAME"
        
        # 检查源文件和目标文件是否相同
        local SRC_REAL=$(realpath "$VIDEO_PATH" 2>/dev/null || echo "$VIDEO_PATH")
        local DEST_REAL=$(realpath "$DEST_PATH" 2>/dev/null || echo "$DEST_PATH")
        
        if [ "$SRC_REAL" = "$DEST_REAL" ]; then
            log_info "视频已在输入目录中: $DEST_PATH"
        else
            log_info "复制自定义视频到输入目录..."
            cp "$VIDEO_PATH" "$HOST_INPUT_DIR/"
            log_info "视频已复制: $DEST_PATH"
        fi
    else
        log_error "视频文件不存在: $VIDEO_PATH"
        exit 1
    fi
}

# 裁剪视频 (使用 ffmpeg)
# 参数: $1=输入视频, $2=输出视频, $3=开始时间, $4=结束时间
clip_video() {
    local INPUT_VIDEO="$1"
    local OUTPUT_VIDEO="$2"
    local START_TIME="$3"
    local END_TIME="$4"
    
    local FFMPEG_ARGS=""
    
    # 构建 ffmpeg 参数
    if [ -n "$START_TIME" ]; then
        FFMPEG_ARGS="$FFMPEG_ARGS -ss $START_TIME"
    fi
    if [ -n "$END_TIME" ]; then
        FFMPEG_ARGS="$FFMPEG_ARGS -to $END_TIME"
    fi
    
    log_info "裁剪视频: $INPUT_VIDEO"
    if [ -n "$START_TIME" ]; then
        log_info "  开始时间: $START_TIME"
    fi
    if [ -n "$END_TIME" ]; then
        log_info "  结束时间: $END_TIME"
    fi
    
    # 使用 ffmpeg 裁剪视频 (保持原始编码)
    log_info "执行 ffmpeg 裁剪命令..."
    ffmpeg -y $FFMPEG_ARGS -i "$INPUT_VIDEO" -c copy "$OUTPUT_VIDEO"
    
    if [ $? -eq 0 ] && [ -f "$OUTPUT_VIDEO" ]; then
        local FILE_SIZE=$(ls -lh "$OUTPUT_VIDEO" | awk '{print $5}')
        log_info "视频裁剪完成: $OUTPUT_VIDEO (大小: $FILE_SIZE)"
    else
        log_error "视频裁剪失败"
        exit 1
    fi
}

# 运行视频稳定化 (Deep3D 模式)
# 参数: $1=视频文件路径, $2=开始时间(HH:MM:SS), $3=结束时间(HH:MM:SS)
run_stabilize() {
    local VIDEO_PATH="$1"
    local START_TIME="$2"
    local END_TIME="$3"
    local VIDEO_NAME
    local CLIPPED_VIDEO_NAME
    
    check_prerequisites
    create_directories
    
    # 确定视频文件
    if [ -z "$VIDEO_PATH" ]; then
        # 使用默认 demo 视频
        copy_demo_video
        VIDEO_NAME="jiangbo-1min.mp4"
        log_info "使用默认 Demo 视频: $VIDEO_NAME"
    else
        # 使用自定义视频
        copy_custom_video "$VIDEO_PATH"
        VIDEO_NAME=$(basename "$VIDEO_PATH")
        log_info "使用自定义视频: $VIDEO_NAME"
    fi
    
    # 如果指定了裁剪参数, 先裁剪视频
    if [ -n "$START_TIME" ] || [ -n "$END_TIME" ]; then
        local BASE_NAME="${VIDEO_NAME%.*}"
        local EXT="${VIDEO_NAME##*.}"
        local TIME_SUFFIX=""
        if [ -n "$START_TIME" ]; then
            TIME_SUFFIX="${TIME_SUFFIX}_from${START_TIME//:/}"
        fi
        if [ -n "$END_TIME" ]; then
            TIME_SUFFIX="${TIME_SUFFIX}_to${END_TIME//:/}"
        fi
        CLIPPED_VIDEO_NAME="${BASE_NAME}${TIME_SUFFIX}.${EXT}"
        
        clip_video "$HOST_INPUT_DIR/$VIDEO_NAME" "$HOST_INPUT_DIR/$CLIPPED_VIDEO_NAME" "$START_TIME" "$END_TIME"
        VIDEO_NAME="$CLIPPED_VIDEO_NAME"
    fi
    
    # 停止已存在的容器
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # 检查 checkpoint 是否存在
    check_checkpoints
    
    log_info "处理视频: $VIDEO_NAME (Deep3D 模式)"
    log_info "启动 Docker 容器进行稳定化处理..."
    docker run --gpus all \
        --name "$CONTAINER_NAME" \
        --entrypoint /bin/bash \
        -v "$HOST_INPUT_DIR:/mnt/rstab/input" \
        -v "$HOST_OUTPUT_DIR:/mnt/rstab/output" \
        -v "$HOST_CHECKPOINTS_DIR/RStab:/mnt/rstab/RStab/RStab_core/pretrained" \
        -v "$HOST_CHECKPOINTS_DIR/MonST3R:/mnt/rstab/RStab/MonST3R/checkpoints" \
        -w /mnt/rstab \
        "$IMAGE_NAME:$IMAGE_TAG" \
        -c "/mnt/rstab/run_rstab.sh $VIDEO_NAME deep3d"
    
    local EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        log_info "稳定化处理完成!"
    else
        log_error "稳定化处理失败 (退出码: $EXIT_CODE)"
    fi
    
    log_info "输出目录: $HOST_OUTPUT_DIR"
    log_info "输出内容:"
    ls -la "$HOST_OUTPUT_DIR"
    
    # 显示 RStab 输出目录
    if [ -d "$HOST_OUTPUT_DIR/RStab" ]; then
        log_info "RStab 稳定化结果:"
        find "$HOST_OUTPUT_DIR/RStab" -name "*.mp4" -type f 2>/dev/null | while read f; do
            log_info "  稳定化视频: $f"
        done
    fi
}

# 运行视频稳定化 (MonST3R 模式)
# 参数: $1=视频文件路径, $2=开始时间(HH:MM:SS), $3=结束时间(HH:MM:SS)
run_stabilize_monst3r() {
    local VIDEO_PATH="$1"
    local START_TIME="$2"
    local END_TIME="$3"
    local VIDEO_NAME
    local CLIPPED_VIDEO_NAME
    
    check_prerequisites
    create_directories
    
    # 确定视频文件
    if [ -z "$VIDEO_PATH" ]; then
        # 使用默认 demo 视频
        copy_demo_video
        VIDEO_NAME="jiangbo-1min.mp4"
        log_info "使用默认 Demo 视频: $VIDEO_NAME"
    else
        # 使用自定义视频
        copy_custom_video "$VIDEO_PATH"
        VIDEO_NAME=$(basename "$VIDEO_PATH")
        log_info "使用自定义视频: $VIDEO_NAME"
    fi
    
    # 如果指定了裁剪参数, 先裁剪视频
    if [ -n "$START_TIME" ] || [ -n "$END_TIME" ]; then
        local BASE_NAME="${VIDEO_NAME%.*}"
        local EXT="${VIDEO_NAME##*.}"
        local TIME_SUFFIX=""
        if [ -n "$START_TIME" ]; then
            TIME_SUFFIX="${TIME_SUFFIX}_from${START_TIME//:/}"
        fi
        if [ -n "$END_TIME" ]; then
            TIME_SUFFIX="${TIME_SUFFIX}_to${END_TIME//:/}"
        fi
        CLIPPED_VIDEO_NAME="${BASE_NAME}${TIME_SUFFIX}.${EXT}"
        
        clip_video "$HOST_INPUT_DIR/$VIDEO_NAME" "$HOST_INPUT_DIR/$CLIPPED_VIDEO_NAME" "$START_TIME" "$END_TIME"
        VIDEO_NAME="$CLIPPED_VIDEO_NAME"
    fi
    
    # 停止已存在的容器
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # 检查 checkpoint 是否存在
    check_checkpoints_monst3r
    
    log_info "处理视频: $VIDEO_NAME (MonST3R 模式)"
    log_info "启动 Docker 容器进行稳定化处理..."
    docker run --gpus all \
        --name "$CONTAINER_NAME" \
        --entrypoint /bin/bash \
        -v "$HOST_INPUT_DIR:/mnt/rstab/input" \
        -v "$HOST_OUTPUT_DIR:/mnt/rstab/output" \
        -v "$HOST_CHECKPOINTS_DIR/RStab:/mnt/rstab/RStab/RStab_core/pretrained" \
        -v "$HOST_CHECKPOINTS_DIR/MonST3R:/mnt/rstab/RStab/MonST3R/checkpoints" \
        -w /mnt/rstab \
        "$IMAGE_NAME:$IMAGE_TAG" \
        -c "/mnt/rstab/run_rstab.sh $VIDEO_NAME monst3r"
    
    local EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        log_info "稳定化处理完成!"
    else
        log_error "稳定化处理失败 (退出码: $EXIT_CODE)"
    fi
    
    log_info "输出目录: $HOST_OUTPUT_DIR"
    log_info "输出内容:"
    ls -la "$HOST_OUTPUT_DIR"
    
    # 显示 RStab 输出目录
    if [ -d "$HOST_OUTPUT_DIR/RStab" ]; then
        log_info "RStab 稳定化结果:"
        find "$HOST_OUTPUT_DIR/RStab" -name "*.mp4" -type f 2>/dev/null | while read f; do
            log_info "  稳定化视频: $f"
        done
    fi
}

# 停止容器
stop_container() {
    log_info "停止容器..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    log_info "容器已停止"
}

# 清理
clean() {
    log_info "清理 Docker 资源..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true
    log_info "清理完成"
}

# 显示帮助
show_help() {
    echo ""
    echo "RStab Docker 自动化构建和运行脚本"
    echo ""
    echo "用法: $0 [命令] [视频路径] [开始时间] [结束时间]"
    echo ""
    echo "命令:"
    echo "  build                                    - 构建 Docker 镜像并下载 Checkpoints"
    echo "  run                                      - 运行 Docker 容器 (交互模式, 用于调试)"
    echo "  stabilize [视频] [开始] [结束]          - 运行视频稳定化 (Deep3D 模式)"
    echo "  stabilize-monst3r [视频] [开始] [结束]  - 运行视频稳定化 (MonST3R 模式)"
    echo "  stop                                     - 停止运行中的容器"
    echo "  clean                                    - 删除镜像和容器"
    echo "  help                                     - 显示帮助信息"
    echo ""
    echo "视频裁剪参数 (可选):"
    echo "  开始时间: HH:MM:SS 格式, 不指定则从 00:00:00 开始"
    echo "  结束时间: HH:MM:SS 格式, 不指定则到视频结尾"
    echo ""
    echo "示例:"
    echo "  $0 build                                          # 构建镜像"
    echo "  $0 stabilize                                      # 使用默认 demo 视频"
    echo "  $0 stabilize /path/to/video.mp4                   # 使用自定义视频"
    echo "  $0 stabilize /path/to/video.mp4 '' 00:00:15       # 裁剪前15秒"
    echo "  $0 stabilize /path/to/video.mp4 00:00:10 ''       # 从10秒开始到结尾"
    echo "  $0 stabilize /path/to/video.mp4 00:00:05 00:00:20 # 裁剪5-20秒"
    echo "  $0 stabilize-monst3r /path/to/video.mp4 '' 00:00:15  # MonST3R 模式裁剪前15秒"
    echo "  $0 run                                            # 进入容器交互模式"
    echo ""
    echo "挂载目录 (可在服务器上直接访问):"
    echo "  输入: $HOST_INPUT_DIR"
    echo "  输出: $HOST_OUTPUT_DIR"
    echo "  Checkpoint: $HOST_CHECKPOINTS_DIR"
    echo ""
    echo "注意事项:"
    echo "  - RTX 3070 (8GB) 建议处理 <30秒 的视频，避免 GPU 内存不足"
    echo "  - 更长视频需要更大显存的 GPU (如 A10, A100)"
    echo "  - 使用裁剪参数可以处理长视频的特定片段"
    echo ""
}

# 主函数
main() {
    case "${1:-help}" in
        build)
            build_image
            ;;
        run)
            run_container
            ;;
        stabilize)
            # $2=视频路径, $3=开始时间, $4=结束时间
            run_stabilize "$2" "$3" "$4"
            ;;
        stabilize-monst3r)
            # $2=视频路径, $3=开始时间, $4=结束时间
            run_stabilize_monst3r "$2" "$3" "$4"
            ;;
        # 保留旧命令兼容性
        demo)
            run_stabilize "" "" ""
            ;;
        demo-monst3r)
            run_stabilize_monst3r "" "" ""
            ;;
        stop)
            stop_container
            ;;
        clean)
            clean
            ;;
        help|*)
            show_help
            ;;
    esac
}

main "$@"
