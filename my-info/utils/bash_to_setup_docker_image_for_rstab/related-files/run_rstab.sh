#!/bin/bash
# RStab 视频稳定化运行脚本
# 用法: ./run_rstab.sh <video_file> [mode]
# mode: deep3d (默认) 或 monst3r

VIDEO_PATH=$1
MODE=${2:-deep3d}

if [ -z "$VIDEO_PATH" ]; then
    echo "用法: ./run_rstab.sh <video_file> [mode]"
    echo "  video_file: 输入视频文件路径 (相对于 /mnt/rstab/input/)"
    echo "  mode: deep3d (默认) 或 monst3r"
    echo ""
    echo "示例:"
    echo "  ./run_rstab.sh jiangbo-1min.mp4"
    echo "  ./run_rstab.sh jiangbo-1min.mp4 monst3r"
    exit 1
fi

# 获取视频文件名（不含路径）
VIDEO_NAME=$(basename "$VIDEO_PATH")

echo "========================================"
echo "RStab 视频稳定化"
echo "========================================"
echo "输入视频: $VIDEO_PATH"
echo "视频名称: $VIDEO_NAME"
echo "处理模式: $MODE"
echo "========================================"

cd /mnt/rstab/RStab

if [ "$MODE" == "deep3d" ]; then
    echo "[Step 1/2] 使用 Deep3D 进行预处理..."
    cd Deep3D
    python geometry_optimizer.py --video_path /mnt/rstab/input/$VIDEO_PATH --output_dir /mnt/rstab/output/Deep3D --name $VIDEO_NAME
    
    echo "[Step 2/2] 运行 RStab 稳定化..."
    cd ../RStab_core
    python rectify.py --expname $VIDEO_NAME
    
elif [ "$MODE" == "monst3r" ]; then
    echo "[Step 1/3] 使用 Deep3D 提取帧..."
    cd Deep3D
    python geometry_optimizer.py --video_path /mnt/rstab/input/$VIDEO_PATH --output_dir /mnt/rstab/output/Deep3D --name $VIDEO_NAME
    
    echo "[Step 2/3] 使用 MonST3R 进行深度估计..."
    cd ../MonST3R
    python demo.py --input /mnt/rstab/output/Deep3D/$VIDEO_NAME/images --output_dir /mnt/rstab/output/MonST3R/$VIDEO_NAME --seq_name output
    
    echo "[Step 3/3] 运行 RStab 稳定化 (MonST3R 模式)..."
    cd ../RStab_core
    python rectify.py --expname $VIDEO_NAME --preprocessing_model MonST3R
else
    echo "错误: 未知模式 '$MODE'. 请使用 'deep3d' 或 'monst3r'"
    exit 1
fi

echo "========================================"
echo "处理完成!"
echo "输出目录: /mnt/rstab/output/"
echo "========================================"
