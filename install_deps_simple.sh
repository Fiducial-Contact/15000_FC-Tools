#!/bin/bash

# 简化的依赖安装脚本 - 用于解决镜像源哈希值问题
# 如果 step1_setup_environment.sh 失败，可以使用这个脚本

echo "========================================="
echo "简化依赖安装脚本"
echo "========================================="
echo ""
echo "这个脚本会使用官方源安装依赖，可能较慢但更可靠"
echo ""

# 清理缓存
echo "清理 pip 缓存..."
pip cache purge 2>/dev/null || true

# 使用官方源
echo "配置使用官方 PyPI 源..."
pip config unset global.index-url 2>/dev/null || true
pip config unset global.trusted-host 2>/dev/null || true

# 升级 pip
echo "升级 pip..."
python -m pip install --upgrade pip

# 安装 PyTorch（使用官方 CUDA 11.8 版本）
echo ""
echo "安装 PyTorch..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# 安装 DeepSpeed
echo ""
echo "安装 DeepSpeed..."
DS_BUILD_OPS=0 pip install deepspeed==0.17.0

# 批量安装其他依赖
echo ""
echo "安装其他依赖..."
cat > temp_requirements.txt << 'EOF'
transformers>=4.35.0
accelerate>=0.24.0
safetensors>=0.4.0
einops>=0.7.0
pillow>=10.0.0
imageio>=2.31.0
imageio-ffmpeg
opencv-python-headless>=4.8.0
av>=10.0.0
tensorboard>=2.14.0
wandb>=0.15.0
toml>=0.10.2
tqdm>=4.65.0
sentencepiece>=0.1.99
protobuf>=4.24.0
peft>=0.7.0
packaging>=23.1
huggingface_hub>=0.19.0
EOF

# 逐行安装，忽略单个失败
while IFS= read -r package; do
    if [ ! -z "$package" ]; then
        echo "安装: $package"
        pip install "$package" || echo "警告: $package 安装失败，继续..."
    fi
done < temp_requirements.txt

rm -f temp_requirements.txt

# 尝试安装可选依赖
echo ""
echo "尝试安装可选依赖..."
pip install torch-optimi || echo "警告: torch-optimi 安装失败，将使用标准优化器"
pip install bitsandbytes || echo "警告: bitsandbytes 安装失败，但不影响训练"

# 验证安装
echo ""
echo "验证安装..."
python << 'EOF'
import sys
print(f"Python: {sys.version}")

required = {
    'torch': 'PyTorch',
    'transformers': 'Transformers',
    'deepspeed': 'DeepSpeed',
    'accelerate': 'Accelerate',
    'safetensors': 'Safetensors',
    'einops': 'Einops'
}

all_good = True
for module, name in required.items():
    try:
        pkg = __import__(module)
        version = getattr(pkg, '__version__', 'unknown')
        print(f"✓ {name}: {version}")
    except ImportError:
        print(f"✗ {name}: 未安装")
        all_good = False

if all_good:
    print("\n✓ 所有关键依赖已安装成功！")
else:
    print("\n⚠️  部分依赖未安装，请检查错误信息")
    sys.exit(1)
EOF

echo ""
echo "========================================="
echo "依赖安装完成！"
echo "========================================="