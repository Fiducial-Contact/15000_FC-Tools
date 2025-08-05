#!/bin/bash

# Step 2: 创建项目结构和配置文件
# 这是第二步：创建所有必要的目录和配置文件

set -e  # 遇到错误立即退出

echo "========================================="
echo "Step 2: 创建项目结构和配置文件"
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

# 创建项目结构
echo "创建目录结构..."
mkdir -p "$PROJECT_ROOT/2.2/configs"
mkdir -p "$PROJECT_ROOT/2.2/scripts"
mkdir -p "$PROJECT_ROOT/2.2/downloads"
mkdir -p "$MODEL_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$DATASET_DIR/videos"
mkdir -p "$DATASET_DIR/images"

# 创建训练配置文件
echo ""
echo "创建训练配置文件..."
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

# 创建数据集配置文件
echo "创建数据集配置文件..."
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

echo ""
echo "========================================="
echo "Step 2 完成！项目结构创建成功"
echo "========================================="
echo ""
echo "创建的目录："
echo "  - 配置文件: 2.2/configs/"
echo "  - 脚本目录: 2.2/scripts/"
echo "  - 模型目录: $MODEL_DIR"
echo "  - 输出目录: $OUTPUT_DIR"
echo "  - 数据集目录: $DATASET_DIR"
echo ""
echo "下一步：运行 ./step3_download_models.sh"
echo "========================================="