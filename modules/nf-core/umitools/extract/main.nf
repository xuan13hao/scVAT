process UMITOOLS_EXTRACT {
    tag "$meta.id"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umi_tools:1.1.5--py39hf95cd2a_0' :
        'biocontainers/umi_tools:1.1.5--py39hf95cd2a_0' }"

    input:
    tuple val(meta), path(fastq_r1), path(fastq_r2)
    path whitelist
    val barcode_length
    val umi_length

    output:
    tuple val(meta), path("${prefix}.extracted.fastq.gz"), emit: extracted_fastq
    tuple val(meta), path("${prefix}.log")              , emit: log
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def bc_len = barcode_length ?: 16
    def umi_len = umi_length ?: 12
    // Pattern: NNN for random positions, then barcode (C), then UMI (N)
    // For 10X: --bc-pattern=NNNCCCCCCCCCCCCCCNNNNNNNNNNNN (16bp barcode, 12bp UMI)
    // Build pattern string: NNN + C repeated bc_len times + N repeated umi_len times
    def bc_pattern_str = "NNN" + ("C" * bc_len) + ("N" * umi_len)

    """
    # UMI-tools extract: Extract barcode/UMI from R1 and add to Read ID of R2
    # R1 contains barcode/UMI, R2 contains transcript
    # --stdin: R2 (transcript read)
    # --read2-in: R1 (barcode/UMI read)
    # --bc-pattern: pattern in R1 to extract barcode and UMI
    PYTHONHASHSEED=0 umi_tools \\
        extract \\
        --stdin $fastq_r2 \\
        --bc-pattern ${bc_pattern_str} \\
        --read2-in $fastq_r1 \\
        --stdout ${prefix}.extracted.fastq.gz \\
        --log2stderr \\
        --log ${prefix}.log \\
        --whitelist $whitelist \\
        --error-correct-cell \\
        --filter-cell-barcode \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.extracted.fastq.gz
    touch ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    END_VERSIONS
    """
}
