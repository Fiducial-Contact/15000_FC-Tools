#!/bin/bash

# Step 0: 一键执行所有步骤
# 这个脚本会按顺序执行所有设置步骤

set -e

echo "========================================="
echo "Wan2.2 5B 一键部署脚本"
echo "========================================="
echo ""
echo "这个脚本将按顺序执行以下步骤："
echo "  1. 设置环境和安装依赖"
echo "  2. 创建项目结构"
echo "  3. 下载模型文件（约15GB）"
echo "  4. 准备训练脚本"
echo ""
echo "预计总耗时：40-70分钟"
echo ""
read -p "是否继续？(Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "已取消"
    exit 1
fi

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查所有步骤脚本是否存在
for i in {1..4}; do
    if [ ! -f "step${i}_*.sh" ]; then
        echo "错误: 找不到 step${i} 脚本"
        echo "请确保所有脚本都在当前目录"
        exit 1
    fi
done

# 给所有脚本添加执行权限
echo "设置脚本执行权限..."
chmod +x step*.sh

# 执行步骤 1
echo ""
echo "========================================="
echo "执行 Step 1: 设置环境..."
echo "========================================="
./step1_setup_environment.sh
if [ $? -ne 0 ]; then
    echo "Step 1 失败！"
    exit 1
fi

# 执行步骤 2
echo ""
echo "========================================="
echo "执行 Step 2: 创建项目结构..."
echo "========================================="
./step2_create_structure.sh
if [ $? -ne 0 ]; then
    echo "Step 2 失败！"
    exit 1
fi

# 执行步骤 3
echo ""
echo "========================================="
echo "执行 Step 3: 下载模型..."
echo "========================================="
echo "提示: 这一步需要下载约15GB的模型文件，请耐心等待"
./step3_download_models.sh
if [ $? -ne 0 ]; then
    echo "Step 3 失败！"
    echo "提示: 可以重新运行 ./step3_download_models.sh 继续下载"
    exit 1
fi

# 执行步骤 4
echo ""
echo "========================================="
echo "执行 Step 4: 准备训练脚本..."
echo "========================================="
./step4_prepare_training.sh
if [ $? -ne 0 ]; then
    echo "Step 4 失败！"
    exit 1
fi

# 完成
echo ""
echo "========================================="
echo "🎉 恭喜！所有步骤执行成功！"
echo "========================================="
echo ""
echo "接下来："
echo ""
echo "1. 准备训练数据："
echo "   - 将视频文件放入: datasets/videos/"
echo "   - 将图片文件放入: datasets/images/"
echo "   - 每个文件需要对应的 .txt 描述文件"
echo ""
echo "2. 开始训练："
echo "   ./step5_start_training.sh"
echo ""
echo "3. 查看帮助："
echo "   cat README_QUICK_START.md"
echo ""
echo "========================================="