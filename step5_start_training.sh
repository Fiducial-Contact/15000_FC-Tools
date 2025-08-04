#!/bin/bash

# Step 5: 开始训练
# 这是第五步：启动训练流程

set -e

echo "========================================="
echo "Step 5: 开始训练"
echo "========================================="
echo ""

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

cd "$PROJECT_ROOT"

# 检查前置条件
echo "检查前置条件..."

# 检查 train.py
if [ ! -f "train.py" ]; then
    echo "✗ 错误: 未找到 train.py"
    echo "请确保在正确的项目目录中"
    exit 1
fi

# 检查模型
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"
if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "✗ 错误: 模型文件未找到"
    echo "请先运行: ./step3_download_models.sh"
    exit 1
fi

# 检查配置文件
if [ ! -f "2.2/configs/wan2.2_5b_lora.toml" ]; then
    echo "✗ 错误: 配置文件未找到"
    echo "请先运行: ./step2_create_structure.sh"
    exit 1
fi

# 检查数据集
DATASET_DIR="$PROJECT_ROOT/datasets"
video_count=$(find "$DATASET_DIR/videos" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" \) 2>/dev/null | wc -l)
image_count=$(find "$DATASET_DIR/images" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | wc -l)

echo ""
echo "数据集统计："
echo "  - 视频文件: $video_count 个"
echo "  - 图片文件: $image_count 个"

if [ "$video_count" -eq 0 ] && [ "$image_count" -eq 0 ]; then
    echo ""
    echo "⚠️  警告: 数据集为空！"
    echo ""
    echo "请先准备训练数据："
    echo "1. 将视频文件（.mp4/.avi/.mov）放入: $DATASET_DIR/videos/"
    echo "2. 将图片文件（.jpg/.png/.jpeg）放入: $DATASET_DIR/images/"
    echo "3. 为每个文件创建对应的 .txt 描述文件"
    echo ""
    echo "示例："
    echo "  video1.mp4 → video1.txt (包含视频描述)"
    echo "  image1.jpg → image1.txt (包含图片描述)"
    echo ""
    read -p "是否仍要继续？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 1
    fi
fi

echo ""
echo "✓ 所有检查通过"

# 显示训练参数
echo ""
echo "训练参数："
echo "  - 模型: Wan2.2-TI2V-5B"
echo "  - 适配器: LoRA (rank=32)"
echo "  - 批次大小: 1 (梯度累积=4)"
echo "  - 学习率: 2e-5"
echo "  - 训练轮数: 100"
echo "  - 输出目录: $PROJECT_ROOT/training_outputs"

# 启动训练
echo ""
echo "========================================="
echo "启动训练..."
echo "========================================="
echo ""
echo "提示："
echo "  - 按 Ctrl+C 可以中断训练"
echo "  - 训练会自动保存检查点，可以恢复训练"
echo "  - 日志保存在: training_outputs/"
echo ""

# 执行训练脚本
exec "$PROJECT_ROOT/2.2/scripts/train.sh" "$@"