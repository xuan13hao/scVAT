process UMITOOLS_WHITELIST {
    tag "$meta.id"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' ?
        'https://depot.galaxyproject.org/singularity/umi_tools:1.1.5--py39hf95cd2a_0' :
        'biocontainers/umi_tools:1.1.5--py39hf95cd2a_0' }"

    input:
    tuple val(meta), path(fastq_r1)
    val barcode_length
    val umi_length

    output:
    tuple val(meta), path("${prefix}.whitelist.txt"), emit: whitelist
    tuple val(meta), path("${prefix}.log")         , emit: log
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    // Build bc-pattern: NNN (random) + C repeated bc_len times (barcode) + N repeated umi_len times (UMI)
    // For 10X: NNNCCCCCCCCCCCCCCNNNNNNNNNNNN (16bp barcode, 12bp UMI)
    def bc_len = barcode_length ?: 16
    def umi_len = umi_length ?: 12
    // For reads with 3bp random prefix + barcode + UMI:
    // Use regex to skip the random prefix (3bp), then capture barcode and UMI
    def bc_pattern_str = "(?P<discard_1>.{3})(?P<cell_1>.{${bc_len}})(?P<umi_1>.{${umi_len}})"
    def extract_method = "--extract-method=regex"

    """
    PYTHONHASHSEED=0 umi_tools \\
        whitelist \\
        --stdin $fastq_r1 \\
        --stdout ${prefix}.whitelist_raw.txt \\
        --log2stderr \\
        --log ${prefix}.log \\
        --bc-pattern '${bc_pattern_str}' \\
        $extract_method \\
        $args

    # UMI-tools whitelist outputs: barcode\\t\\tcount\\t
    # But UMI-tools extract expects just the barcode, so extract first column
    cut -f1 ${prefix}.whitelist_raw.txt > ${prefix}.whitelist.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.whitelist.txt
    touch ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umitools: \$( umi_tools --version | sed '/version:/!d; s/.*: //' )
    END_VERSIONS
    """
}
