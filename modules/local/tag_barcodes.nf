process TAG_BARCODES {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::pysam=0.19.1"
    container "${ workflow.containerEngine == 'singularity' ?
        'https://depot.galaxyproject.org/singularity/pysam:0.19.1--py310hff46b53_1' :
        'biocontainers/pysam:0.19.1--py310hff46b53_1' }"

    input:
    tuple val(meta), path(bam), path(bai)
    path corrected_bc_info_or_whitelist  // Can be bc_info TSV (long-read) or whitelist (short-read)
    val extract_from_readid               // boolean: extract from Read ID (short-read mode)

    output:
    tuple val(meta), path("*.tagged.bam"), emit: tagged_bam
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extract_flag = extract_from_readid ? "--extract_from_readid" : ""
    def whitelist_flag = extract_from_readid ? "--whitelist ${corrected_bc_info_or_whitelist}" : ""
    def bc_info_flag = extract_from_readid ? "" : "-i ${corrected_bc_info_or_whitelist}"

    """
    tag_barcodes.py \\
        -b ${bam} \\
        $bc_info_flag \\
        $extract_flag \\
        $whitelist_flag \\
        -o ${prefix}.tagged.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tagged.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
