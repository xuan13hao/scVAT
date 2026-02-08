# VAT Aligner 集成说明

本项目已集成 VAT (Versatile Alignment Tool) 作为 minimap2 的替代比对工具。

## 安装 VAT 二进制文件

### 方法 1: 将 VAT 二进制文件放在 bin/ 目录（推荐）

1. 将 VAT 二进制文件复制到项目的 `bin/` 目录：
   ```bash
   cp /path/to/VAT /path/to/scnanoseq/bin/VAT
   ```

2. 确保二进制文件有执行权限：
   ```bash
   chmod +x /path/to/scnanoseq/bin/VAT
   ```

3. 验证 VAT 是否可用：
   ```bash
   /path/to/scnanoseq/bin/VAT --version
   ```

### 方法 2: 将 VAT 添加到系统 PATH

如果 VAT 已经安装在系统中并位于 PATH 中，模块会自动使用系统版本的 VAT。

## 验证安装

运行以下命令验证 VAT 是否正确配置：

```bash
# 检查 bin 目录下的 VAT
ls -lh bin/VAT

# 测试 VAT 命令
bin/VAT --version
```

## 使用 VAT 运行流程

流程会自动使用 VAT 进行比对，无需额外配置。运行方式与使用 minimap2 时相同：

```bash
nextflow run nf-core/scnanoseq \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

## VAT 模块配置

### VAT_INDEX 模块
- 位置: `modules/local/vat_index.nf`
- 功能: 构建 VAT 数据库索引（.vatf 文件）
- 命令: `VAT makevatdb --in <input.fa> --dbtype nucl`

### VAT_ALIGN 模块
- 位置: `modules/local/vat_align.nf`
- 功能: 执行序列比对
- 支持的比对模式:
  - `--splice`: 用于基因组比对（splice-aware）
  - `--wgs`: 用于转录组比对
  - `--long`: 长读长模式（Oxford Nanopore）

## 配置参数

在 `conf/modules.config` 中可以配置 VAT 的参数：

- `params.kmer_size`: 映射到 VAT 的 `-S` 参数（seed length）
- `params.save_genome_secondary_alignment`: 控制是否保存次要比对

## 故障排除

### 问题: VAT 命令未找到

**解决方案:**
1. 确保 VAT 二进制文件在 `bin/` 目录下
2. 检查文件权限: `chmod +x bin/VAT`
3. 验证 PATH 配置: 检查 `nextflow.config` 中的 PATH 设置

### 问题: VAT 版本信息无法获取

如果 VAT 不支持 `--version` 参数，版本信息会显示为 "version unknown"，这不影响功能使用。

## 与 minimap2 的差异

- **索引文件**: VAT 使用 `.vatf` 格式，而 minimap2 使用 `.mmi` 格式
- **参数映射**: 某些 minimap2 参数在 VAT 中可能有不同的名称
- **输出格式**: 两者都支持 SAM/BAM 格式输出

## 更多信息

- VAT 项目: https://github.com/xuan13hao/VAT
- VAT 文档: https://github.com/xuan13hao/VAT/blob/main/src/README.md
