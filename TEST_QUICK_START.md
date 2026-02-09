# scVAT 快速测试指南

## 快速验证（推荐第一步）

验证工作流语法和配置（不执行管道）：

```bash
./test_framework.sh both validate
```

这会检查：
- ✓ Nextflow 安装
- ✓ VAT 二进制文件
- ✓ 工作流语法
- ✓ 配置文件

## 完整测试

### 测试 Long-Read 模式

```bash
# 生成测试数据并运行
./test_framework.sh long_read full

# 或使用专用脚本
./test_longread_local.sh
```

### 测试 Short-Read 模式

```bash
# 生成测试数据并运行
./test_framework.sh short_read full

# 或使用专用脚本
./test_shortread_local.sh
```

### 测试两种模式

```bash
./test_framework.sh both full
```

## 测试框架选项

### 模式 (Mode)
- `long_read`: 仅测试 long-read 模式
- `short_read`: 仅测试 short-read 模式
- `both`: 测试两种模式（默认）

### 操作 (Action)
- `validate`: 仅验证语法和配置（快速，默认）
- `run`: 运行管道（需要测试数据已存在）
- `full`: 生成测试数据、验证并运行（完整测试）

## 示例

```bash
# 快速验证两种模式
./test_framework.sh both validate

# 完整测试 long-read 模式
./test_framework.sh long_read full

# 仅运行 short-read（假设数据已存在）
./test_framework.sh short_read run
```

## 测试数据

测试数据会自动生成在：
- Long-read: `test_data/longread/`
- Short-read: `test_data/shortread/`

## 测试输出

测试结果保存在：
- `test_output/longread_YYYYMMDD_HHMMSS/`
- `test_output/shortread_YYYYMMDD_HHMMSS/`

## 更多信息

详细文档请参考：`docs/TESTING.md`
