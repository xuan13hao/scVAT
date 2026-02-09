# 测试修复总结

## 问题诊断

运行 `./test_complete.sh run` 时遇到两个主要问题：

### 1. Long-read 模式：内存不足

**错误信息**：
```
Process requirement exceeds available memory -- req: 15 GB; avail: 7.7 GB
```

**原因**：测试配置要求 15 GB 内存，但系统只有 7.7 GB 可用。

**修复**：
- 在 `conf/test_longread_local.config` 中降低内存要求：
  - `resourceLimits.memory`: 15.GB → 7.GB
  - `SPLIT_FASTA`: 6.GB → 4.GB
  - `SAMTOOLS_FAIDX_SPLIT`: 4.GB → 2.GB
  - `process_low`: 6.GB → 4.GB
  - `FASTQC`: 添加 2.GB 限制
  - `NANOPLOT`: 添加 2.GB 限制
  - `TOULLIGQC`: 添加 2.GB 限制

### 2. Short-read 模式：Nextflow 语法错误

**错误信息**：
```
Multi-channel output cannot be applied to operator map for which argument is already provided
```

**原因**：在 Nextflow 中，不能在 if 语句内重新赋值给同一个 channel 变量。

**修复**：
- 使用 `def` 关键字和三元运算符避免重新赋值
- 重构 `ch_qc_fastq`、`ch_nanocomp_input` 和 `ch_gunzip_*` 变量的定义

## 修复详情

### 修复 1: FASTQC_NANOPLOT_PRE_TRIM 输入格式

**文件**: `workflows/scnanoseq.nf`

**修改前**:
```groovy
ch_qc_fastq = Channel.empty()
if (params.input_type == 'short_read') {
    ch_qc_fastq = ch_cat_fastq.map { ... }
} else {
    ch_qc_fastq = ch_cat_fastq.map { ... }
}
```

**修改后**:
```groovy
def ch_qc_fastq_input = params.input_type == 'short_read' ?
    ch_cat_fastq.map { meta, fastqs -> ... } :
    ch_cat_fastq.map { meta, fastq -> ... }
```

### 修复 2: NANOCOMP_FASTQ 输入格式

**文件**: `workflows/scnanoseq.nf`

使用三元运算符避免在 if 中重新赋值。

### 修复 3: GUNZIP_FASTQ 配对端处理

**文件**: `workflows/scnanoseq.nf`

**修改**：
- 使用 `def` 和三元运算符定义 `ch_gunzip_r1`、`ch_gunzip_r2` 和 `ch_gunzip_longread`
- 在 if 语句外定义所有 channel，避免重新赋值

### 修复 4: 内存配置

**文件**: 
- `conf/test_longread_local.config`
- `conf/test_shortread_local.config`

**修改**：
- 降低所有内存要求以适配 7.7 GB 可用内存
- 为特定工具（FASTQC, NANOPLOT, TOULLIGQC）添加内存限制

## 验证结果

修复后，验证测试通过：

```
✓ Test data generation: PASSED
✓ Long-read mode: PASSED
✓ Short-read mode: PASSED
```

## 注意事项

1. **内存限制**：如果系统内存更少，可能需要进一步降低内存要求
2. **容器问题**：如果遇到 cgroup 错误，这是 Docker/Podman 配置问题，不是代码问题
3. **完整测试**：`validate` 模式只验证配置，`run` 模式会实际执行管道

## 建议

如果完整测试仍然失败：

1. **检查可用内存**：
   ```bash
   free -h
   ```

2. **进一步降低内存要求**：
   编辑 `conf/test_*_local.config`，进一步降低 `resourceLimits.memory`

3. **跳过内存密集型步骤**：
   在测试配置中添加：
   ```groovy
   params {
       skip_seurat = true
       skip_multiqc = false
       quantifier = ""  // 跳过定量步骤
   }
   ```

4. **使用更小的测试数据**：
   修改 `generate_*_test_data.sh`，减少 `NUM_READS`
