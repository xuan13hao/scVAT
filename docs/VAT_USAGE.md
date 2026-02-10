# VAT (Versatile Alignment Tool) 使用说明

## 概述

VAT (Versatile Alignment Tool) 是 scVAT pipeline 的核心对齐工具，用于处理长读长（long-read）和短读长（short-read）单细胞 RNA-seq 数据。VAT 支持多种对齐模式，能够根据数据类型自动选择最优策略。

## VAT 模块架构

### 1. VAT_INDEX 模块
**位置**: `modules/local/vat_index.nf`

**功能**: 为参考基因组/转录组构建 VAT 索引文件（`.vatf`）

**使用方式**:
```bash
VAT makevatdb --in <fasta> --dbtype nucl
```

**输入**:
- `fasta`: 参考基因组/转录组 FASTA 文件

**输出**:
- `*.vatf`: VAT 索引文件
- `versions.yml`: 软件版本信息

**特点**:
- 索引构建是可选的（可通过 `skip_save_minimap2_index` 参数控制）
- 如果不构建索引，VAT 可以直接使用 FASTA 文件（但速度较慢）

---

### 2. VAT_ALIGN 模块
**位置**: `modules/local/vat_align.nf`

**功能**: 执行序列对齐，将 reads 比对到参考序列

**核心命令**:
```bash
VAT dna \
    -d <reference> \          # 参考序列（FASTA 或 .vatf）
    -q <query> \              # 查询序列（FASTQ）
    <mode_flag> \             # 对齐模式标志
    <long_flag> \             # 长读长标志（可选）
    -o <output> \             # 输出文件
    -f <format> \             # 输出格式（sam/bam/paf）
    -p <threads> \            # 线程数
    <additional_args>         # 额外参数
```

**输入**:
- `reads`: FASTQ 文件（长读长或短读长）
- `reference`: 参考序列（FASTA 或 .vatf 索引）
- `bam_format`: 是否输出 BAM 格式（true/false）
- `bam_index_extension`: BAM 索引扩展名（如 "bai"）
- `alignment_mode`: 对齐模式（'splice', 'wgs', 'circ', 'sr'）
- `long_read_mode`: 是否为长读长模式（true/false）

**输出**:
- `*.sam` 或 `*.bam`: 对齐结果
- `*.bai`: BAM 索引文件（如果输出 BAM）
- `versions.yml`: 软件版本信息

**对齐模式**:

| 模式 | 标志 | 用途 | 适用场景 |
|------|------|------|----------|
| `splice` | `--splice` | 剪接感知对齐 | 基因组对齐（长读长/短读长） |
| `wgs` | `--wgs` | 全基因组对齐 | 转录组对齐（长读长/短读长） |
| `circ` | `--circ` | 环状 RNA 对齐 | 环状 RNA 检测 |
| `sr` | `--sr` | 短读长优化 | 短读长数据（Illumina） |

**长读长标志**:
- `--long`: 启用长读长模式（用于 Oxford Nanopore/PacBio 数据）
- 仅在 `long_read_mode=true` 时使用

---

## 工作流集成

### Long-Read 模式

**子工作流**: `subworkflows/local/align_longreads.nf`

**调用流程**:
```
PROCESS_LONGREAD_SCRNA
  └─> ALIGN_LONGREADS
        ├─> VAT_INDEX (可选)
        └─> VAT_ALIGN
              ├─> alignment_mode: 'splice' (基因组) 或 'wgs' (转录组)
              └─> long_read_mode: true
```

**示例调用**:
```groovy
ALIGN_LONGREADS(
    fasta,                    // 参考基因组/转录组
    fai,                      // FASTA 索引
    gtf,                      // GTF 注释文件
    fastq,                    // 长读长 FASTQ
    rseqc_bed,                // RSeQC BED 文件
    skip_save_minimap2_index, // 是否跳过索引构建
    skip_qc,                  // 是否跳过 QC
    skip_rseqc,               // 是否跳过 RSeQC
    skip_bam_nanocomp,        // 是否跳过 NanoComp
    'splice',                  // 对齐模式：'splice' 或 'wgs'
    true                       // long_read_mode: true
)
```

**VAT 参数**:
- 基因组对齐: `VAT dna -d <ref> -q <fastq> --splice --long -o <output> -f sam -p <cpus>`
- 转录组对齐: `VAT dna -d <ref> -q <fastq> --wgs --long -o <output> -f sam -p <cpus>`

---

### Short-Read 模式

**子工作流**: `subworkflows/local/align_shortreads.nf`

**调用流程**:
```
PROCESS_SHORTREAD_SCRNA
  └─> ALIGN_SHORTREADS
        ├─> VAT_INDEX (可选)
        └─> VAT_ALIGN
              ├─> alignment_mode: 'splice' (基因组) 或 'wgs' (转录组)
              └─> long_read_mode: false
```

**示例调用**:
```groovy
ALIGN_SHORTREADS(
    fasta,                    // 参考基因组/转录组
    fai,                      // FASTA 索引
    gtf,                      // GTF 注释文件
    fastq_r2,                 // R2 FASTQ（转录序列）
    rseqc_bed,                // RSeQC BED 文件
    skip_save_minimap2_index, // 是否跳过索引构建
    skip_qc,                  // 是否跳过 QC
    skip_rseqc,               // 是否跳过 RSeQC
    skip_bam_nanocomp,        // 是否跳过 NanoComp
    'splice',                  // 对齐模式：'splice' 或 'wgs'
    false                      // long_read_mode: false
)
```

**VAT 参数**:
- 基因组对齐: `VAT dna -d <ref> -q <fastq_r2> --splice --sr -o <output> -f sam -p <cpus>`
- 转录组对齐: `VAT dna -d <ref> -q <fastq_r2> --wgs --sr -o <output> -f sam -p <cpus>`

**注意**: 短读长模式下，VAT 对齐的是 R2（转录序列），R1 包含 barcode/UMI，不参与对齐。

---

## VAT 二进制文件位置

VAT 模块会按以下顺序查找 VAT 二进制文件：

1. **项目目录**: `$projectDir/bin/VAT`（优先）
2. **系统 PATH**: `command -v VAT`

**配置方式**:
```bash
# 方式 1: 放置在项目 bin 目录
cp /path/to/VAT bin/
chmod +x bin/VAT

# 方式 2: 添加到系统 PATH
export PATH="/path/to/vat:$PATH"
```

**错误处理**:
如果 VAT 未找到，模块会输出错误信息并退出：
```
ERROR: VAT binary not found. Please place VAT in bin/ directory or ensure it's in PATH.
```

---

## 对齐后处理

VAT 对齐完成后，pipeline 会执行以下步骤：

1. **BAM 排序和索引**: 使用 SAMtools 对 SAM 输出进行排序并生成 BAM 和索引
2. **过滤未比对 reads**: 仅保留成功比对的 reads
3. **统计信息**: 生成 flagstat、stats、idxstats 等统计信息
4. **QC 分析**: RSeQC read distribution、NanoComp 等

---

## 配置参数

### Nextflow 配置示例

```nextflow
process {
    withName: '.*:VAT_ALIGN' {
        cpus = 8
        memory = '16.GB'
        time = '4.h'
    }
    
    withName: '.*:VAT_INDEX' {
        cpus = 4
        memory = '8.GB'
        time = '2.h'
    }
}
```

### 额外参数

可以通过 `task.ext.args` 传递额外的 VAT 参数：

```nextflow
process {
    withName: '.*:VAT_ALIGN' {
        ext.args = '--min-identity 0.8 --max-gap 1000'
    }
}
```

---

## 输出格式

### SAM 格式（默认）
- 输出文件: `*.sam`
- 需要后续转换为 BAM（使用 SAMtools）

### BAM 格式（推荐）
- 输出文件: `*.bam`
- 自动生成索引: `*.bai`
- 更节省空间，便于下游分析

---

## 性能优化

1. **使用索引文件**: 构建 `.vatf` 索引可以显著加速对齐（特别是重复运行时）
2. **线程数**: 根据可用 CPU 核心数设置 `cpus` 参数
3. **内存**: 长读长数据需要更多内存，建议至少 16GB
4. **对齐模式**: 选择合适的模式（splice/wgs）可以提高准确性和速度

---

## 故障排除

### 问题 1: VAT 二进制文件未找到
**解决方案**: 
- 确保 VAT 在 `bin/VAT` 或系统 PATH 中
- 检查文件权限：`chmod +x bin/VAT`

### 问题 2: 对齐速度慢
**解决方案**:
- 使用 `.vatf` 索引文件而不是 FASTA
- 增加线程数（`cpus`）
- 检查内存是否充足

### 问题 3: 对齐率低
**解决方案**:
- 检查参考序列是否正确
- 验证 FASTQ 文件质量
- 调整 VAT 参数（如 `--min-identity`）

---

## 相关文档

- [scVAT 架构文档](ARCHITECTURE.md)
- [scVAT 实现状态](IMPLEMENTATION_STATUS.md)
- [VAT GitHub 仓库](https://github.com/xuan13hao/VAT)
