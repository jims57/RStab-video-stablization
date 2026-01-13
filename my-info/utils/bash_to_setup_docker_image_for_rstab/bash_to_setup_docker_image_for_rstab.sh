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

# 检查 RStab checkpoint 是否存在
check_checkpoints() {
    if [ ! -d "$HOST_CHECKPOINTS_DIR/RStab" ] || [ -z "$(ls -A $HOST_CHECKPOINTS_DIR/RStab 2>/dev/null)" ]; then
        log_error "RStab Checkpoint 未找到!"
        echo ""
        echo "请下载 RStab Checkpoint:"
        echo "  下载: https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view"
        echo "  解压到: $HOST_CHECKPOINTS_DIR/RStab/"
        echo ""
        exit 1
    fi
    log_info "RStab Checkpoint 已找到"
}

# 检查 MonST3R checkpoint 是否存在
check_checkpoints_monst3r() {
    check_checkpoints
    if [ ! -d "$HOST_CHECKPOINTS_DIR/MonST3R" ] || [ -z "$(ls -A $HOST_CHECKPOINTS_DIR/MonST3R 2>/dev/null)" ]; then
        log_error "MonST3R Checkpoint 未找到!"
        echo ""
        echo "请下载 MonST3R Checkpoint:"
        echo "  下载: https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view"
        echo "  放到: $HOST_CHECKPOINTS_DIR/MonST3R/MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth"
        echo ""
        exit 1
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
    
    echo ""
    log_warn "========== 重要: 需要手动下载 Checkpoint =========="
    log_warn "Google Drive 下载受限，请手动下载以下文件:"
    echo ""
    echo "1. RStab Checkpoint:"
    echo "   下载: https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view"
    echo "   解压到: $HOST_CHECKPOINTS_DIR/RStab/"
    echo "   (解压后应有 $HOST_CHECKPOINTS_DIR/RStab/*.pth 文件)"
    echo ""
    echo "2. MonST3R Checkpoint (可选, 仅当使用 MonST3R 模式时需要):"
    echo "   下载: https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view"
    echo "   放到: $HOST_CHECKPOINTS_DIR/MonST3R/MonST3R_PO-TA-S-W_ViTLarge_BaseDecoder_512_dpt.pth"
    echo ""
    log_warn "================================================="
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

# 运行 demo (Deep3D 模式)
run_demo() {
    log_info "运行 Demo 视频稳定化 (Deep3D 模式)..."
    check_prerequisites
    create_directories
    copy_demo_video
    
    # 停止已存在的容器
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # 检查 checkpoint 是否存在
    check_checkpoints
    
    log_info "处理视频: jiangbo-1min.mp4"
    docker run --gpus all \
        --name "$CONTAINER_NAME" \
        -v "$HOST_INPUT_DIR:/mnt/rstab/input" \
        -v "$HOST_OUTPUT_DIR:/mnt/rstab/output" \
        -v "$HOST_CHECKPOINTS_DIR/RStab:/mnt/rstab/RStab/RStab_core/pretrained" \
        -v "$HOST_CHECKPOINTS_DIR/MonST3R:/mnt/rstab/RStab/MonST3R/checkpoints" \
        -w /mnt/rstab \
        "$IMAGE_NAME:$IMAGE_TAG" \
        -c "/mnt/rstab/run_rstab.sh jiangbo-1min.mp4 deep3d"
    
    log_info "Demo 处理完成!"
    log_info "输出目录: $HOST_OUTPUT_DIR"
    ls -la "$HOST_OUTPUT_DIR"
}

# 运行 demo (MonST3R 模式)
run_demo_monst3r() {
    log_info "运行 Demo 视频稳定化 (MonST3R 模式)..."
    check_prerequisites
    create_directories
    copy_demo_video
    
    # 停止已存在的容器
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # 检查 checkpoint 是否存在
    check_checkpoints_monst3r
    
    log_info "处理视频: jiangbo-1min.mp4 (MonST3R)"
    docker run --gpus all \
        --name "$CONTAINER_NAME" \
        -v "$HOST_INPUT_DIR:/mnt/rstab/input" \
        -v "$HOST_OUTPUT_DIR:/mnt/rstab/output" \
        -v "$HOST_CHECKPOINTS_DIR/RStab:/mnt/rstab/RStab/RStab_core/pretrained" \
        -v "$HOST_CHECKPOINTS_DIR/MonST3R:/mnt/rstab/RStab/MonST3R/checkpoints" \
        -w /mnt/rstab \
        "$IMAGE_NAME:$IMAGE_TAG" \
        -c "/mnt/rstab/run_rstab.sh jiangbo-1min.mp4 monst3r"
    
    log_info "Demo 处理完成!"
    log_info "输出目录: $HOST_OUTPUT_DIR"
    ls -la "$HOST_OUTPUT_DIR"
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
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  build        - 构建 Docker 镜像"
    echo "  run          - 运行 Docker 容器 (交互模式)"
    echo "  demo         - 运行 demo 视频稳定化 (Deep3D 模式)"
    echo "  demo-monst3r - 运行 demo 视频稳定化 (MonST3R 模式)"
    echo "  stop         - 停止运行中的容器"
    echo "  clean        - 删除镜像和容器"
    echo "  help         - 显示帮助信息"
    echo ""
    echo "挂载目录:"
    echo "  输入: $HOST_INPUT_DIR -> /mnt/rstab/input"
    echo "  输出: $HOST_OUTPUT_DIR -> /mnt/rstab/output"
    echo "  Checkpoint: $HOST_CHECKPOINTS_DIR -> /mnt/rstab/RStab/*/pretrained|checkpoints"
    echo ""
    echo "Checkpoint 下载:"
    echo "  RStab: https://drive.google.com/file/d/1q3QM1damtvHLukhIOIAdv9IKm646Oj11/view"
    echo "         解压到 $HOST_CHECKPOINTS_DIR/RStab/"
    echo "  MonST3R: https://drive.google.com/file/d/1e-2lGrnxcQXIqjOn-UoIsZnV98CvjKXa/view"
    echo "           放到 $HOST_CHECKPOINTS_DIR/MonST3R/"
    echo ""
    echo "在容器内运行:"
    echo "  ./run_rstab.sh <video_name> [mode]"
    echo "  mode: deep3d (默认) 或 monst3r"
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
        demo)
            run_demo
            ;;
        demo-monst3r)
            run_demo_monst3r
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
