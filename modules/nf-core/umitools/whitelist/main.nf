process UMITOOLS_WHITELIST {
    tag "$meta.id"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
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
    def bc_len = barcode_length ? "--bc-pattern=NNN${barcode_length}" : "--bc-pattern=NNN16"
    def umi_len = umi_length ? "--bc-pattern=NNN${barcode_length}NNN${umi_length}" : "--bc-pattern=NNN16NNN12"

    """
    PYTHONHASHSEED=0 umi_tools \\
        whitelist \\
        --stdin $fastq_r1 \\
        --stdout ${prefix}.whitelist.txt \\
        --log2stderr \\
        --log ${prefix}.log \\
        $bc_len \\
        $args

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
