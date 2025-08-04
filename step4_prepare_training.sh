#!/bin/bash

# Step 4: 准备训练脚本和测试环境
# 这是第四步：创建训练脚本并测试环境配置

set -e

echo "========================================="
echo "Step 4: 准备训练脚本和测试环境"
echo "========================================="
echo ""

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

cd "$PROJECT_ROOT"

# 创建训练脚本
echo "创建训练脚本..."
cat > "$PROJECT_ROOT/2.2/scripts/train.sh" << 'TRAIN'
#!/bin/bash

set -e

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# 查找 train.py
if [ ! -f "train.py" ]; then
    echo "错误: 未找到 train.py"
    echo "当前目录: $(pwd)"
    echo "请确保在 diffusion-pipe 项目目录中"
    exit 1
fi

# 环境变量设置
export NCCL_P2P_DISABLE="1"
export NCCL_IB_DISABLE="1"
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"

echo "========================================="
echo "Wan2.2 5B LoRA 训练"
echo "项目目录: $PROJECT_ROOT"
echo "========================================="

# 显示环境信息
echo "环境信息："
python -c "import torch; print(f'PyTorch: {torch.__version__}')" || echo "PyTorch 未安装"
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')" 2>/dev/null || echo "CUDA 不可用"
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader || echo "GPU 信息不可用"

# 检查模型文件
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"
if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo ""
    echo "错误: 模型文件未找到！"
    echo "请先运行: ./step3_download_models.sh"
    exit 1
fi

# 检查数据集
DATASET_DIR="$PROJECT_ROOT/datasets"
if [ -z "$(ls -A $DATASET_DIR/videos 2>/dev/null)" ] && [ -z "$(ls -A $DATASET_DIR/images 2>/dev/null)" ]; then
    echo ""
    echo "警告: 数据集目录为空"
    echo "请添加训练数据到:"
    echo "  - $DATASET_DIR/videos/ (视频文件)"
    echo "  - $DATASET_DIR/images/ (图片文件)"
    echo ""
    echo "每个文件需要对应的 .txt 描述文件"
    echo "例如: video1.mp4 需要 video1.txt"
fi

# 启动训练
echo ""
echo "开始训练..."
echo "配置文件: 2.2/configs/wan2.2_5b_lora.toml"
echo ""

deepspeed --num_gpus=1 train.py --deepspeed --config 2.2/configs/wan2.2_5b_lora.toml "$@"
TRAIN

chmod +x "$PROJECT_ROOT/2.2/scripts/train.sh"

# 创建测试脚本
echo "创建测试脚本..."
cat > "$PROJECT_ROOT/2.2/scripts/test_setup.sh" << 'TEST'
#!/bin/bash

echo "========================================="
echo "环境测试脚本"
echo "========================================="

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 测试 Python 和 PyTorch
echo ""
echo "1. Python 环境："
python -c "
import sys
print(f'Python: {sys.version}')

try:
    import torch
    print(f'PyTorch: {torch.__version__}')
    print(f'CUDA Available: {torch.cuda.is_available()}')
    if torch.cuda.is_available():
        print(f'CUDA Version: {torch.version.cuda}')
        print(f'GPU: {torch.cuda.get_device_name(0)}')
        print(f'GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
except ImportError:
    print('PyTorch 未安装')
except Exception as e:
    print(f'错误: {e}')
"

# 测试依赖
echo ""
echo "2. 检查关键依赖："
python -c "
packages = {
    'deepspeed': '深度学习训练框架',
    'transformers': 'Transformer模型库',
    'accelerate': '训练加速库',
    'einops': '张量操作库',
    'safetensors': '模型存储格式',
    'torch-optimi': '优化器库',
    'wandb': '实验跟踪工具',
    'tensorboard': '可视化工具'
}

for pkg, desc in packages.items():
    try:
        module = __import__(pkg.replace('-', '_'))
        version = getattr(module, '__version__', 'unknown')
        print(f'✓ {pkg}: {version} - {desc}')
    except ImportError:
        print(f'✗ {pkg}: 未安装 - {desc}')
"

# 检查项目文件
echo ""
echo "3. 检查项目文件："
echo "项目根目录: $PROJECT_ROOT"

# 检查核心文件
files_to_check=(
    "train.py:训练主程序"
    "models/wan/wan.py:Wan模型实现"
    "utils/dataset.py:数据集处理"
    "2.2/configs/wan2.2_5b_lora.toml:训练配置"
    "2.2/scripts/train.sh:训练脚本"
)

for file_desc in "${files_to_check[@]}"; do
    file="${file_desc%%:*}"
    desc="${file_desc##*:}"
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo "✓ $file - $desc"
    else
        echo "✗ $file - $desc"
    fi
done

# 检查模型文件
echo ""
echo "4. 检查模型文件："
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"
if [ -d "$MODEL_DIR" ]; then
    echo "✓ 模型目录存在: $MODEL_DIR"
    
    model_files=(
        "config.json"
        "model.safetensors.index.json"
        "model-00001-of-00003.safetensors"
        "model-00002-of-00003.safetensors"
        "model-00003-of-00003.safetensors"
        "Wan2.2_VAE.pth"
    )
    
    all_exist=true
    for file in "${model_files[@]}"; do
        if [ -f "$MODEL_DIR/$file" ]; then
            size=$(du -h "$MODEL_DIR/$file" | cut -f1)
            echo "  ✓ $file ($size)"
        else
            echo "  ✗ $file 缺失"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = false ]; then
        echo ""
        echo "提示: 模型文件不完整，请运行 ./step3_download_models.sh"
    fi
else
    echo "✗ 模型目录不存在"
    echo "提示: 请运行 ./step3_download_models.sh 下载模型"
fi

# 检查数据集
echo ""
echo "5. 检查数据集："
DATASET_DIR="$PROJECT_ROOT/datasets"
if [ -d "$DATASET_DIR" ]; then
    echo "数据集目录: $DATASET_DIR"
    
    video_count=$(find "$DATASET_DIR/videos" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" \) 2>/dev/null | wc -l)
    image_count=$(find "$DATASET_DIR/images" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | wc -l)
    
    echo "  - 视频文件: $video_count 个"
    echo "  - 图片文件: $image_count 个"
    
    if [ "$video_count" -eq 0 ] && [ "$image_count" -eq 0 ]; then
        echo ""
        echo "提示: 数据集为空，请添加训练数据"
        echo "  1. 将视频文件放入: $DATASET_DIR/videos/"
        echo "  2. 将图片文件放入: $DATASET_DIR/images/"
        echo "  3. 每个文件需要对应的 .txt 文本描述"
    fi
else
    echo "✗ 数据集目录不存在"
fi

echo ""
echo "========================================="
echo "测试完成！"
echo "========================================="
TEST

chmod +x "$PROJECT_ROOT/2.2/scripts/test_setup.sh"

# 运行测试
echo ""
echo "运行环境测试..."
echo ""
"$PROJECT_ROOT/2.2/scripts/test_setup.sh"

echo ""
echo "========================================="
echo "Step 4 完成！训练脚本准备就绪"
echo "========================================="
echo ""
echo "创建的脚本："
echo "  - 训练脚本: 2.2/scripts/train.sh"
echo "  - 测试脚本: 2.2/scripts/test_setup.sh"
echo ""
echo "下一步："
echo "  1. 准备数据集（放入 datasets/ 目录）"
echo "  2. 运行 ./step5_start_training.sh 开始训练"
echo "========================================="