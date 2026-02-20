process UMITOOLS_COUNT {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::umi_tools=1.1.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umi_tools:1.1.5--py39hf95cd2a_0' :
        'biocontainers/umi_tools:1.1.5--py39hf95cd2a_0' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${prefix}_counts.tsv.gz")  , emit: counts
    tuple val(meta), path("${prefix}_mtx/")           , emit: mtx_dir
    tuple val(meta), path("${prefix}.log")            , emit: log
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    PYTHONHASHSEED=0 umi_tools \\
        count \\
        --per-gene \\
        --gene-tag=XT \\
        --per-cell \\
        -I ${bam} \\
        -S ${prefix}_counts.tsv.gz \\
        -L ${prefix}.log \\
        ${args}

    # Convert long-format TSV to MEX (Matrix Market) format for compatibility
    # with Seurat / scanpy / 10x Genomics loaders
    python3 << 'PYEOF'
import gzip, os, sys
from collections import defaultdict

out_dir = "${prefix}_mtx"
os.makedirs(out_dir, exist_ok=True)

counts = defaultdict(dict)
genes = []
cells = []
gene_set = set()
cell_set = set()

with gzip.open("${prefix}_counts.tsv.gz", "rt") as fh:
    header = next(fh)  # skip header: gene\tcell\tcount
    for line in fh:
        parts = line.rstrip("\\n").split("\\t")
        if len(parts) < 3:
            continue
        gene, cell, n = parts[0], parts[1], int(parts[2])
        if gene not in gene_set:
            genes.append(gene)
            gene_set.add(gene)
        if cell not in cell_set:
            cells.append(cell)
            cell_set.add(cell)
        counts[gene][cell] = n

genes.sort()
cells.sort()
gene_idx = {g: i + 1 for i, g in enumerate(genes)}
cell_idx = {c: i + 1 for i, c in enumerate(cells)}

with open(os.path.join(out_dir, "barcodes.tsv"), "w") as fh:
    for c in cells:
        fh.write(c + "\\n")

with open(os.path.join(out_dir, "features.tsv"), "w") as fh:
    for g in genes:
        fh.write(g + "\\t" + g + "\\tGene Expression\\n")

nnz = sum(len(v) for v in counts.values())
with open(os.path.join(out_dir, "matrix.mtx"), "w") as fh:
    fh.write("%%MatrixMarket matrix coordinate integer general\\n")
    fh.write("%%\\n")
    fh.write(str(len(genes)) + " " + str(len(cells)) + " " + str(nnz) + "\\n")
    for gene in genes:
        gi = gene_idx[gene]
        for cell in sorted(counts.get(gene, {}).keys()):
            ci = cell_idx[cell]
            fh.write(str(gi) + " " + str(ci) + " " + str(counts[gene][cell]) + "\\n")

sys.stdout.write(
    "MTX written: " + str(len(genes)) + " genes, " +
    str(len(cells)) + " cells, " + str(nnz) + " non-zero entries\\n"
)
PYEOF

    ver=\$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    echo '"${task.process}":' > versions.yml
    printf '    umitools: %s\n' "\${ver}" >> versions.yml
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_counts.tsv.gz
    mkdir -p ${prefix}_mtx
    touch ${prefix}_mtx/matrix.mtx
    touch ${prefix}_mtx/barcodes.tsv
    touch ${prefix}_mtx/features.tsv
    touch ${prefix}.log

    ver=\$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    echo '"${task.process}":' > versions.yml
    printf '    umitools: %s\n' "\${ver}" >> versions.yml
    """
}
