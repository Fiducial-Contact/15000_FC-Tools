#!/bin/bash

# Wan2.2 5B 简化部署脚本 - 适用于云端自动化部署
# 支持在任何目录运行，自动处理路径

set -e  # 遇到错误立即退出

echo "========================================="
echo "Wan2.2 5B 云端自动化部署脚本"
echo "========================================="
echo ""

# 获取脚本所在目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 设置项目相关路径
PROJECT_ROOT="$SCRIPT_DIR"
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"
OUTPUT_DIR="$PROJECT_ROOT/training_outputs"
DATASET_DIR="$PROJECT_ROOT/datasets"

echo "项目根目录: $PROJECT_ROOT"

# 检测当前环境
echo ""
echo "检测当前环境..."
python --version || { echo "错误: 未找到 Python"; exit 1; }
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || echo "警告: 未检测到 GPU"

# 步骤 1: 安装 aria2（如果需要）
echo ""
echo "步骤 1: 检查并安装必要工具..."
if ! command -v aria2c &> /dev/null; then
    echo "安装 aria2..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y aria2 || { echo "错误: 安装 aria2 失败"; exit 1; }
    elif command -v yum &> /dev/null; then
        yum install -y aria2 || { echo "错误: 安装 aria2 失败"; exit 1; }
    else
        echo "错误: 无法自动安装 aria2，请手动安装"
        exit 1
    fi
else
    echo "aria2 已安装"
fi

# 步骤 2: 创建 Python 依赖文件
echo ""
echo "步骤 2: 创建依赖文件..."
cat > requirements_wan22.txt << 'EOF'
# DeepSpeed - 跳过编译加速安装
deepspeed==0.17.0

# 核心依赖
torch>=2.0.0
transformers>=4.35.0
accelerate>=0.24.0
safetensors>=0.4.0
einops>=0.7.0

# 数据处理
pillow>=10.0.0
imageio[ffmpeg]>=2.31.0
opencv-python-headless>=4.8.0
av>=10.0.0

# 训练工具
tensorboard>=2.14.0
wandb>=0.15.0
toml>=0.10.2
tqdm>=4.65.0

# 优化器
torch-optimi>=0.2.0
bitsandbytes>=0.41.0

# 其他
packaging>=23.1
huggingface_hub[cli]>=0.19.0
sentencepiece>=0.1.99
protobuf>=4.24.0
peft>=0.7.0
EOF

# 安装 Python 依赖
echo ""
echo "安装 Python 依赖..."

# 检查是否在中国，使用镜像源
if ping -c 1 -W 1 pypi.tuna.tsinghua.edu.cn &> /dev/null; then
    echo "使用清华镜像源..."
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
fi

# 安装 DeepSpeed（跳过编译）
echo "安装 DeepSpeed..."
DS_BUILD_OPS=0 pip install deepspeed==0.17.0 || { echo "错误: DeepSpeed 安装失败"; exit 1; }

# 安装其他依赖
echo "安装其他依赖..."
pip install -r requirements_wan22.txt || { echo "错误: 依赖安装失败"; exit 1; }

# 步骤 3: 创建项目结构
echo ""
echo "步骤 3: 创建项目结构..."
mkdir -p "$PROJECT_ROOT"/{2.2/{configs,scripts,downloads},models,training_outputs,datasets/{videos,images}}

# 步骤 4: 创建模型下载脚本
echo ""
echo "步骤 4: 创建模型下载脚本..."
cat > "$PROJECT_ROOT/2.2/downloads/download_models.sh" << 'DOWNLOAD'
#!/bin/bash

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"

mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

echo "========================================="
echo "下载 Wan2.2-TI2V-5B 模型"
echo "模型目录: $MODEL_DIR"
echo "========================================="

# 模型文件列表
declare -A MODEL_FILES=(
    ["config.json"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/config.json"
    ["model.safetensors.index.json"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model.safetensors.index.json"
    ["model-00001-of-00003.safetensors"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00001-of-00003.safetensors"
    ["model-00002-of-00003.safetensors"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00002-of-00003.safetensors"
    ["model-00003-of-00003.safetensors"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00003-of-00003.safetensors"
    ["README.md"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/README.md"
    ["Wan2.2_VAE.pth"]="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/Wan2.2_VAE.pth"
)

# 检查并下载文件
for file in "${!MODEL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "文件已存在，跳过: $file"
    else
        echo "下载: $file"
        url="${MODEL_FILES[$file]}"
        
        # 尝试下载，最多重试3次
        for i in {1..3}; do
            if aria2c -x 16 -s 16 -c \
                --auto-file-renaming=false \
                --file-allocation=none \
                --check-certificate=false \
                --console-log-level=error \
                --summary-interval=10 \
                -o "$file" "$url"; then
                echo "下载成功: $file"
                break
            else
                echo "下载失败，重试 $i/3: $file"
                if [ $i -eq 3 ]; then
                    echo "错误: 无法下载 $file"
                    exit 1
                fi
                sleep 5
            fi
        done
    fi
done

# 验证关键文件
echo ""
echo "验证模型文件..."
if [ ! -f "config.json" ] || [ ! -f "model.safetensors.index.json" ]; then
    echo "错误: 关键模型文件缺失！"
    exit 1
fi

echo ""
echo "模型下载完成！"
echo "文件列表:"
ls -lah "$MODEL_DIR"
DOWNLOAD

chmod +x "$PROJECT_ROOT/2.2/downloads/download_models.sh"

# 步骤 5: 创建训练配置
echo ""
echo "步骤 5: 创建训练配置..."
cat > "$PROJECT_ROOT/2.2/configs/wan2.2_5b_lora.toml" << EOF
# Wan2.2 5B LoRA 训练配置 - 云端优化版
output_dir = '$OUTPUT_DIR'
dataset = '2.2/configs/dataset_video.toml'

# 训练参数
epochs = 100
micro_batch_size_per_gpu = 1
pipeline_stages = 1
gradient_accumulation_steps = 4
gradient_clipping = 1.0
warmup_steps = 100

# 内存优化
blocks_to_swap = 20
activation_checkpointing = 'unsloth'

# 评估和保存
eval_every_n_epochs = 5
eval_before_first_step = true
save_every_n_epochs = 10
checkpoint_every_n_minutes = 120
save_dtype = 'bfloat16'
steps_per_print = 1

[model]
type = 'wan'
ckpt_path = '$MODEL_DIR'
dtype = 'bfloat16'
transformer_dtype = 'float8'
timestep_sample_method = 'logit_normal'

[adapter]
type = 'lora'
rank = 32
alpha = 32
dropout = 0.1
dtype = 'bfloat16'

[optimizer]
type = 'adamw_optimi'
lr = 2e-5
betas = [0.9, 0.99]
weight_decay = 0.01
eps = 1e-8

[lr_scheduler]
type = 'cosine'
num_warmup_steps = 100
min_lr = 1e-6
EOF

cat > "$PROJECT_ROOT/2.2/configs/dataset_video.toml" << EOF
# 数据集配置
resolutions = [768]
enable_ar_bucket = true
min_ar = 0.5
max_ar = 2.0
num_ar_buckets = 7
frame_buckets = [1, 49, 97, 121]

[[directory]]
path = '$DATASET_DIR/videos'
num_repeats = 1

[[directory]]
path = '$DATASET_DIR/images'
num_repeats = 2
frame_buckets = [1]
EOF

# 步骤 6: 创建训练脚本
echo ""
echo "步骤 6: 创建训练脚本..."
cat > "$PROJECT_ROOT/2.2/scripts/train.sh" << 'TRAIN'
#!/bin/bash

set -e

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
    echo "请先运行: ./2.2/downloads/download_models.sh"
    exit 1
fi

# 检查数据集
DATASET_DIR="$PROJECT_ROOT/datasets"
if [ ! -d "$DATASET_DIR/videos" ] && [ ! -d "$DATASET_DIR/images" ]; then
    echo ""
    echo "警告: 数据集目录为空"
    echo "请添加训练数据到:"
    echo "  - $DATASET_DIR/videos/"
    echo "  - $DATASET_DIR/images/"
fi

# 启动训练
echo ""
echo "开始训练..."
echo "配置文件: 2.2/configs/wan2.2_5b_lora.toml"
echo ""

deepspeed --num_gpus=1 train.py --deepspeed --config 2.2/configs/wan2.2_5b_lora.toml "$@"
TRAIN

chmod +x "$PROJECT_ROOT/2.2/scripts/train.sh"

# 创建快速测试脚本
cat > "$PROJECT_ROOT/2.2/scripts/test_setup.sh" << 'TEST'
#!/bin/bash

echo "========================================="
echo "测试环境设置"
echo "========================================="

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
except ImportError:
    print('PyTorch 未安装')
"

# 测试依赖
echo ""
echo "2. 检查关键依赖："
python -c "
packages = ['deepspeed', 'transformers', 'accelerate', 'einops', 'safetensors']
for pkg in packages:
    try:
        module = __import__(pkg)
        version = getattr(module, '__version__', 'unknown')
        print(f'{pkg}: {version}')
    except ImportError:
        print(f'{pkg}: 未安装')
"

# 检查项目文件
echo ""
echo "3. 检查项目文件："
echo "项目根目录: $PROJECT_ROOT"

if [ -f "$PROJECT_ROOT/train.py" ]; then
    echo "✓ train.py 存在"
else
    echo "✗ train.py 不存在"
fi

if [ -d "$PROJECT_ROOT/models/Wan2.2-TI2V-5B" ]; then
    echo "✓ 模型目录存在"
    if [ -f "$PROJECT_ROOT/models/Wan2.2-TI2V-5B/config.json" ]; then
        echo "  ✓ config.json 存在"
    else
        echo "  ✗ config.json 不存在"
    fi
else
    echo "✗ 模型目录不存在"
fi

echo ""
echo "测试完成！"
TEST

chmod +x "$PROJECT_ROOT/2.2/scripts/test_setup.sh"

# 创建简单的 README
cat > "$PROJECT_ROOT/README_SETUP.md" << 'README'
# Wan2.2 5B 云端快速部署指南

## 一键部署

```bash
# 1. 克隆仓库
git clone https://github.com/Fiducial-Contact/15000_FC-Tools.git
cd 15000_FC-Tools/diffusion-pipe-main

# 2. 运行部署脚本
chmod +x wan22_simplified_setup.sh
./wan22_simplified_setup.sh

# 3. 下载模型
./2.2/downloads/download_models.sh

# 4. 准备数据（将数据放入 datasets/ 目录）

# 5. 开始训练
./2.2/scripts/train.sh
```

## 测试环境

```bash
./2.2/scripts/test_setup.sh
```

## 注意事项

- 需要 24GB+ 显存的 GPU
- Python 3.8+
- CUDA 11.7+
README

echo ""
echo "========================================="
echo "部署脚本优化完成！"
echo "========================================="
echo ""
echo "下一步操作："
echo ""
echo "1. 测试环境:"
echo "   ./2.2/scripts/test_setup.sh"
echo ""
echo "2. 下载模型:"
echo "   ./2.2/downloads/download_models.sh"
echo ""
echo "3. 准备数据集到:"
echo "   $DATASET_DIR/videos/"
echo "   $DATASET_DIR/images/"
echo ""
echo "4. 开始训练:"
echo "   ./2.2/scripts/train.sh"
echo ""
echo "所有路径已自动适配当前目录，可在任何位置运行"
echo "========================================="