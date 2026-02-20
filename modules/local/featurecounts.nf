process FEATURECOUNTS {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::subread=2.0.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/subread:2.0.6--he4a0461_2' :
        'biocontainers/subread:2.0.6--he4a0461_2' }"

    input:
    tuple val(meta), path(bam)
    path gtf

    output:
    tuple val(meta), path("${prefix}.featurecounts.bam")         , emit: bam
    tuple val(meta), path("${prefix}.featurecounts.txt")         , emit: counts
    tuple val(meta), path("${prefix}.featurecounts.txt.summary") , emit: summary
    path "versions.yml"                                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    featureCounts \\
        -a ${gtf} \\
        -o ${prefix}.featurecounts.txt \\
        -T ${task.cpus} \\
        -R BAM \\
        --tmpDir ./ \\
        ${args} \\
        ${bam}

    # featureCounts names the annotated BAM as <input_bam>.featureCounts.bam
    mv ${bam}.featureCounts.bam ${prefix}.featurecounts.bam

    # Fail fast if zero reads were assigned (likely missing CB/UB tags or bad GTF)
    assigned=\$(grep -m1 "^Assigned" ${prefix}.featurecounts.txt.summary | awk '{print \$NF}')
    total=\$(grep -m1 "^Assigned\\|^Unassigned" ${prefix}.featurecounts.txt.summary | awk '{sum+=\$NF} END{print sum}')
    if [ "\${total:-0}" -gt 0 ] && [ "\${assigned:-0}" -eq 0 ]; then
        echo "WARNING: featureCounts assigned 0 reads in ${meta.id}." >&2
        echo "Check that BAM has CB/UB tags (TAG_BARCODES ran) and GTF matches the genome." >&2
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        subread: \$( featureCounts -v 2>&1 | grep -oP "(?<=v)\\S+" | head -1 )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.featurecounts.bam
    touch ${prefix}.featurecounts.txt
    touch ${prefix}.featurecounts.txt.summary

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        subread: "2.0.6"
    END_VERSIONS
    """
}
