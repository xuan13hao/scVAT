# 测试 Short-Read 模式

## 快速开始

### 方法 1: 使用自动化脚本（推荐）

```bash
# 这个脚本会自动生成测试数据并运行管道
./test_shortread_local.sh
```

### 方法 2: 手动步骤

#### 步骤 1: 生成测试数据

```bash
./generate_test_data.sh
```

这会生成：
- `test_data/shortread/test_R1.fastq.gz` - R1 文件（包含 barcode 和 UMI）
- `test_data/shortread/test_R2.fastq.gz` - R2 文件（包含转录本序列）
- `test_data/shortread/whitelist.txt` - 细胞 barcode 白名单
- `test_data/shortread/samplesheet_shortread.csv` - 样本表

#### 步骤 2: 运行管道

```bash
nextflow run . \
    -profile test_shortread_local,docker \
    --outdir test_output/shortread_test
```

## 生成的数据说明

### 数据参数
- **读取数**: 1000 条
- **细胞数**: 10 个
- **Barcode 长度**: 16 bp
- **UMI 长度**: 12 bp

### 文件格式

**R1 文件格式**:
```
@READ_000001
NNN[16bp_barcode][12bp_UMI]
+
FFFFFFFFFFFFFFFFFFFFFFFFFFFFF
```

**R2 文件格式**:
```
@READ_000001
[transcript_sequence]
+
[quality_scores]
```

### 样本表格式

```csv
sample,fastq_1,fastq_2,cell_count
TEST_SAMPLE,/path/to/test_R1.fastq.gz,/path/to/test_R2.fastq.gz,10
```

## 预期输出

运行成功后，你应该看到以下输出目录：

```
test_output/shortread_test/
├── umitools_whitelist/     # UMI-tools 生成的 barcode 白名单
├── umitools_extract/       # 提取后的 FASTQ（barcode/UMI 在 Read ID 中）
├── vat/                    # VAT 比对结果
├── barcode_tagged/         # 带 CB 和 UB 标签的 BAM 文件
├── dedup_umitools/         # 去重后的 BAM 文件
├── isoquant/               # 基因/转录本计数矩阵
└── multiqc/                # MultiQC 报告
```

## 验证检查点

### 1. 检查 UMI-tools whitelist
```bash
head test_output/shortread_test/umitools_whitelist/*.whitelist.txt
```
应该看到 10 个不同的 barcode。

### 2. 检查提取后的 FASTQ
```bash
zcat test_output/shortread_test/umitools_extract/*.extracted.fastq.gz | head -4
```
Read ID 应该包含 barcode 和 UMI，格式：`@READ_XXXXX_BC_UMI`

### 3. 检查 BAM 文件标签
```bash
samtools view test_output/shortread_test/barcode_tagged/*.tagged.bam | head -1 | cut -f12-20
```
应该看到 `CB:Z:` 和 `UB:Z:` 标签。

### 4. 检查去重结果
```bash
samtools view test_output/shortread_test/dedup_umitools/*.bam | wc -l
```
应该少于原始读取数（因为去重）。

## 常见问题

### 1. 数据生成失败
- 确保 Python3 已安装
- 检查是否有写入权限

### 2. 管道运行失败
- 检查 Docker 是否运行：`docker ps`
- 检查 VAT 二进制文件：`ls -lh bin/VAT`
- 查看详细日志：`nextflow log`

### 3. 内存不足
- 测试数据很小（~12KB），不应该有内存问题
- 如果遇到，可以减小 `NUM_READS` 参数

## 自定义测试数据

如果你想生成更多或更少的数据，可以修改 `generate_test_data.sh` 中的参数：

```bash
NUM_READS=5000    # 增加读取数
NUM_CELLS=50      # 增加细胞数
```

然后重新运行：
```bash
./generate_test_data.sh
```

## 下一步

测试成功后，你可以：
1. 使用自己的真实数据替换测试数据
2. 调整参数（barcode_length, umi_length 等）
3. 测试不同的量化工具（isoquant, oarfish）
