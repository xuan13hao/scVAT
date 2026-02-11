process UMITOOLS_EXTRACT {
    tag "$meta.id"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' ?
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
    // For reads with 3bp random prefix + barcode + UMI:
    // Use regex to skip the random prefix (3bp), then capture barcode (C) and UMI (N)
    // The .{3} skips any 3 bases at the start
    def bc_pattern_str = "(?P<discard_1>.{3})(?P<cell_1>.{${bc_len}})(?P<umi_1>.{${umi_len}})"
    def extract_method = "--extract-method=regex"

    """
    # UMI-tools extract: Extract barcode/UMI from R1 and add to Read ID of R2
    # R1 contains barcode/UMI, R2 contains transcript
    # --stdin: R1 (barcode/UMI read - where bc-pattern is applied)
    # --read2-out: Output R2 (transcript) with modified read IDs
    # --bc-pattern: pattern in R1 to extract barcode and UMI
    PYTHONHASHSEED=0 umi_tools \\
        extract \\
        --stdin $fastq_r1 \\
        --bc-pattern '${bc_pattern_str}' \\
        $extract_method \\
        --read2-in $fastq_r2 \\
        --read2-stdout \\
        --stdout ${prefix}.extracted.fastq.gz \\
        --log2stderr \\
        --log ${prefix}.log \\
        --whitelist $whitelist \\
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
