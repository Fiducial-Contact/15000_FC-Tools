#!/bin/bash

# 修复 NumPy 版本兼容性问题
# NumPy 2.x 与 DeepSpeed 0.17.0 不兼容

echo "========================================="
echo "修复 NumPy 版本兼容性问题"
echo "========================================="
echo ""

echo "当前 NumPy 版本："
python -c "import numpy; print(numpy.__version__)"

echo ""
echo "降级 NumPy 到 1.x 版本..."
pip uninstall -y numpy
pip install "numpy<2.0"

echo ""
echo "新的 NumPy 版本："
python -c "import numpy; print(numpy.__version__)"

echo ""
echo "测试 DeepSpeed..."
python -c "import deepspeed; print('DeepSpeed 导入成功！版本:', deepspeed.__version__)"

echo ""
echo "========================================="
echo "修复完成！"
echo "========================================="