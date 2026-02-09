process BLAZE {
    tag "$meta.id"
    label 'process_medium'
    label 'process_long'

    conda "biconda::blaze2=2.5.1"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/blaze2:2.5.1--pyhdfd78af_0' :
        'biocontainers/blaze2:2.5.1--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(reads)
    path in_whitelist

    output:
    tuple val(meta), path("*.putative_bc.no_header.csv") , emit: putative_bc
    tuple val(meta), path("*.whitelist.csv")             , emit: whitelist
    tuple val(meta), path("*.bc_count.txt")              , emit: bc_count
    tuple val(meta), path("*.knee_plot.png")             , emit: knee_plot
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args       = task.ext.args ?: ''
    def prefix     = task.ext.prefix ?: "${meta.id}"
    // WARN: Version information not provided by tool on CLI. Please update this string when upgrading BLAZE code
    def VERSION    = '2.5.1'
    // Handle cell_count: BLAZE requires one of: --expect-cells, --count-threshold, --no-whitelisting, or --force-cells
    def cell_count = meta.cell_count
    def cell_param = ''
    if (cell_count != null) {
        def cell_count_str = cell_count.toString().trim()
        if (cell_count_str != '' && cell_count_str != 'null' && cell_count_str.isNumber()) {
            cell_param = "--expect-cells ${cell_count_str.toInteger()}"
        } else {
            // Fallback: use count-threshold if cell_count is invalid
            cell_param = '--count-threshold 1'
        }
    } else {
        // Fallback: use count-threshold if cell_count is null
        cell_param = '--count-threshold 1'
    }

    """
    blaze \\
        ${cell_param} \\
        --full-bc-whitelist ${in_whitelist} \\
        --output-prefix ${prefix}. \\
        --threads $task.cpus \\
        ${args} \\
        \$(pwd)


    tail -n +2 ${prefix}.putative_bc.csv > ${prefix}.putative_bc.no_header.csv

    cat ${prefix}.putative_bc.no_header.csv | \\
        cut -f2 -d',' | \\
        sort -T \$(pwd) | \\
        uniq -c | \\
        awk '{print \$2","\$1}'> ${prefix}.bc_count.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blaze: $VERSION
    END_VERSIONS
    """

    stub:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def VERSION = '2.5.1'
    """
    touch ${prefix}.putative_bc.no_header.csv
    touch ${prefix}.whitelist.csv
    touch ${prefix}.bc_count.txt
    touch ${prefix}.knee_plot.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blaze: $VERSION
    END_VERSIONS
    """
}
