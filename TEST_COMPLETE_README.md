# scVAT 完整测试脚本使用指南

## 概述

`test_complete.sh` 是一个综合测试脚本，可以：
1. 自动生成 long-read 和 short-read 测试数据
2. 验证测试数据
3. 测试框架配置
4. （可选）运行完整的管道测试

## 快速开始

### 快速验证（推荐）

生成测试数据并验证配置（不运行管道）：

```bash
./test_complete.sh validate
```

这会：
- ✓ 检查前置条件（Nextflow, Python, VAT）
- ✓ 生成 long-read 测试数据
- ✓ 生成 short-read 测试数据
- ✓ 验证测试数据
- ✓ 验证工作流配置

### 完整测试（需要 Docker/Singularity）

生成测试数据并运行完整的管道测试：

```bash
./test_complete.sh run
```

或使用完整模式（包含所有检查）：

```bash
./test_complete.sh full
```

## 使用方法

```bash
./test_complete.sh [validate|run|full]
```

### 参数说明

- `validate` (默认): 仅生成数据和验证配置，不运行管道
  - 快速（几秒钟）
  - 不需要容器引擎
  - 适合 CI/CD 快速检查

- `run`: 生成数据并运行管道测试
  - 需要 Docker 或 Singularity
  - 会实际执行管道
  - 生成完整的测试输出

- `full`: 完整测试模式
  - 包含所有检查
  - 生成详细报告
  - 最全面的测试

## 测试流程

### 1. 前置条件检查

脚本会检查：
- ✓ Nextflow 安装
- ✓ Python 3 安装
- ✓ VAT 二进制文件
- ✓ Docker/Singularity（如果运行模式）

### 2. 生成测试数据

#### Long-Read 数据
- 位置: `test_data/longread/`
- 文件:
  - `test_longread.fastq.gz` - 模拟的长读段数据
  - `whitelist.txt` - 细胞 barcode 白名单
  - `samplesheet_longread.csv` - 样本表

#### Short-Read 数据
- 位置: `test_data/shortread/`
- 文件:
  - `test_R1.fastq.gz` - R1 文件（barcode/UMI）
  - `test_R2.fastq.gz` - R2 文件（转录本序列）
  - `whitelist.txt` - 细胞 barcode 白名单
  - `samplesheet_shortread.csv` - 样本表

### 3. 数据验证

验证生成的文件：
- 文件存在性
- 文件大小
- 样本表格式

### 4. 工作流测试

- 验证 long-read 配置
- 验证 short-read 配置
- （运行模式）执行管道

## 输出示例

### 验证模式输出

```
==========================================
scVAT Complete Test Suite
==========================================

✓ Nextflow: nextflow version 25.10.3.10983
✓ Python: Python 3.10.9
✓ VAT found at bin/VAT

✓ Long-read test data generated successfully
✓ Short-read test data generated successfully

✓ Long-read data: OK
✓ Short-read data: OK

✓ Long-read configuration valid
✓ Short-read configuration valid

✓ Test data generation: PASSED
✓ Long-read mode: PASSED
✓ Short-read mode: PASSED
```

### 运行模式输出

除了验证输出外，还会显示：
- 管道执行进度
- 输出目录位置
- 执行日志文件

## 测试数据详情

### Long-Read 测试数据
- **读取数**: 500 条
- **细胞数**: 10 个
- **Barcode 长度**: 16 bp
- **UMI 长度**: 12 bp
- **读段长度**: ~150 bp（模拟 Nanopore 长读段）

### Short-Read 测试数据
- **读取数**: 1000 条（配对）
- **细胞数**: 10 个
- **Barcode 长度**: 16 bp
- **UMI 长度**: 12 bp
- **R1 内容**: Barcode + UMI
- **R2 内容**: 转录本序列

## 测试输出位置

### 测试数据
- Long-read: `test_data/longread/`
- Short-read: `test_data/shortread/`

### 管道输出（运行模式）
- Long-read: `test_output/longread_YYYYMMDD_HHMMSS/`
- Short-read: `test_output/shortread_YYYYMMDD_HHMMSS/`

每个输出目录包含：
- `dag.html` - 工作流 DAG 图
- `report.html` - 执行报告
- `trace.txt` - 执行追踪
- `*.log` - 执行日志
- 管道生成的所有输出文件

## 故障排除

### 数据生成失败

**问题**: 脚本无法生成测试数据

**解决方案**:
1. 检查 Python 3 是否安装
2. 检查 `test_data/` 目录的写入权限
3. 查看错误消息中的具体问题

### VAT 未找到

**问题**: `⚠ VAT binary not found`

**解决方案**:
1. 下载 VAT 二进制文件
2. 放置在 `bin/VAT`
3. 或添加到系统 PATH

### 容器引擎未找到

**问题**: `⚠ Neither Docker nor Singularity found`

**解决方案**:
- 对于 `validate` 模式：可以忽略（不需要容器）
- 对于 `run` 模式：需要安装 Docker 或 Singularity

### 管道执行失败

**问题**: 管道执行时出错

**解决方案**:
1. 检查日志文件：`test_output/*.log`
2. 验证所有前置条件
3. 检查容器引擎是否正常工作
4. 查看 Nextflow 日志：`.nextflow.log`

## 最佳实践

1. **首次使用**: 先运行 `validate` 模式确保一切正常
2. **定期测试**: 在修改代码后运行测试
3. **CI/CD**: 使用 `validate` 模式进行快速检查
4. **完整验证**: 定期运行 `full` 模式进行全面测试
5. **清理**: 定期清理 `test_output/` 目录

## 与其他测试脚本的区别

| 脚本 | 功能 | 数据生成 | 执行管道 |
|------|------|----------|----------|
| `test_complete.sh` | 完整测试套件 | ✓ 自动 | ✓ 可选 |
| `test_framework.sh` | 框架测试 | ✗ 手动 | ✓ 可选 |
| `test_longread_local.sh` | Long-read 测试 | ✓ 自动 | ✓ 是 |
| `test_shortread_local.sh` | Short-read 测试 | ✓ 自动 | ✓ 是 |

## 示例工作流

### 开发新功能后测试

```bash
# 1. 快速验证
./test_complete.sh validate

# 2. 如果验证通过，运行完整测试
./test_complete.sh full
```

### CI/CD 集成

```bash
# 在 CI 中使用验证模式
if ./test_complete.sh validate; then
    echo "Tests passed"
    exit 0
else
    echo "Tests failed"
    exit 1
fi
```

## 更多信息

- 详细测试文档: `docs/TESTING.md`
- 快速开始指南: `TEST_QUICK_START.md`
- 架构文档: `docs/ARCHITECTURE.md`
