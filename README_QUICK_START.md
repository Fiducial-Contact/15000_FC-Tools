# 🚀 Wan2.2 5B 快速开始指南

本项目提供了一套自动化脚本，让您能够在云端快速部署和训练 Wan2.2-TI2V-5B 模型。

## 📋 系统要求

- **GPU**: 24GB+ 显存 (RTX 3090/4090 或更高)
- **系统**: Ubuntu 20.04+ 或 CentOS 7+
- **Python**: 3.8 - 3.10
- **CUDA**: 11.7+
- **磁盘空间**: 至少 50GB (用于存储模型和数据)

## 🎯 快速开始

### 方式一：一键执行所有步骤（推荐）

```bash
# 克隆仓库
git clone https://github.com/Fiducial-Contact/15000_FC-Tools.git
cd 15000_FC-Tools

# 给所有脚本添加执行权限
chmod +x step*.sh

# 一键执行所有步骤（需要交互确认）
./step1_setup_environment.sh && \
./step2_create_structure.sh && \
./step3_download_models.sh && \
./step4_prepare_training.sh
```

### 方式二：分步执行（更可控）

## 📝 执行步骤详解

### Step 1: 环境设置和依赖安装
```bash
./step1_setup_environment.sh
```
**功能**：
- 检测系统环境（Python、GPU）
- 安装必要的系统工具（aria2、wget、curl）
- 配置 pip 镜像源（自动检测地区）
- 安装所有 Python 依赖包

**耗时**：5-10 分钟

---

### Step 2: 创建项目结构和配置文件
```bash
./step2_create_structure.sh
```
**功能**：
- 创建项目目录结构
- 生成训练配置文件（LoRA 配置）
- 生成数据集配置文件
- 设置输出路径

**耗时**：< 1 分钟

---

### Step 3: 下载预训练模型
```bash
./step3_download_models.sh
```
**功能**：
- 从 HuggingFace 镜像下载 Wan2.2-TI2V-5B 模型
- 自动重试失败的下载
- 验证文件完整性
- 支持断点续传

**耗时**：30-60 分钟（取决于网速）
**模型大小**：约 15GB

---

### Step 4: 准备训练脚本和测试环境
```bash
./step4_prepare_training.sh
```
**功能**：
- 创建训练启动脚本
- 创建环境测试脚本
- 自动运行环境测试
- 检查所有依赖和文件

**耗时**：< 1 分钟

---

### Step 5: 准备数据并开始训练
```bash
# 首先准备数据集
# 将视频文件放入: datasets/videos/
# 将图片文件放入: datasets/images/
# 每个文件需要对应的 .txt 描述文件

# 开始训练
./step5_start_training.sh
```
**功能**：
- 检查所有前置条件
- 显示数据集统计
- 启动 LoRA 训练
- 自动保存检查点

---

## 📁 项目结构

```
15000_FC-Tools/
├── step1_setup_environment.sh    # 环境设置脚本
├── step2_create_structure.sh     # 创建结构脚本
├── step3_download_models.sh      # 下载模型脚本
├── step4_prepare_training.sh     # 准备训练脚本
├── step5_start_training.sh       # 开始训练脚本
├── 2.2/
│   ├── configs/                  # 配置文件目录
│   │   ├── wan2.2_5b_lora.toml # LoRA训练配置
│   │   └── dataset_video.toml   # 数据集配置
│   └── scripts/                  # 脚本目录
│       ├── train.sh             # 训练执行脚本
│       └── test_setup.sh        # 环境测试脚本
├── models/
│   └── Wan2.2-TI2V-5B/         # 模型文件目录
├── datasets/
│   ├── videos/                  # 视频数据集
│   └── images/                  # 图片数据集
└── training_outputs/            # 训练输出目录
```

## 🔧 常用命令

### 测试环境
```bash
./2.2/scripts/test_setup.sh
```

### 恢复训练
```bash
./step5_start_training.sh --resume_from_checkpoint
```

### 调整训练参数
编辑 `2.2/configs/wan2.2_5b_lora.toml` 文件

## ❓ 常见问题

### 1. 依赖安装失败
- 检查网络连接
- 手动安装失败的包：`pip install 包名`

### 2. 模型下载失败
- 检查磁盘空间
- 重新运行 `./step3_download_models.sh`（支持断点续传）

### 3. CUDA 内存不足
- 编辑配置文件，增加 `blocks_to_swap` 的值
- 减小 `micro_batch_size_per_gpu`

### 4. 找不到数据集
- 确保数据文件有对应的 .txt 描述文件
- 检查文件格式是否正确

## 📊 训练监控

训练日志和检查点保存在 `training_outputs/` 目录：
- 使用 TensorBoard 查看训练曲线
- 检查点每 120 分钟自动保存
- 模型每 10 个 epoch 保存一次

## 🎉 完成！

按照以上步骤，您就可以在云端成功部署并训练 Wan2.2 5B 模型了！

如有问题，请查看详细日志或提交 Issue。