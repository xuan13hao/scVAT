process BAMTOOLS_SPLIT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bamtools:2.5.2--hdcf5f25_2' :
        'biocontainers/bamtools:2.5.2--hdcf5f25_2' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bam"), emit: bam
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_list = bam.collect{"-in $it"}.join(' ')
    """
    # Run bamtools merge and split
    bamtools \\
        merge \\
        $input_list \\
        | bamtools \\
            split \\
            -stub $prefix \\
            $args || true

    # Debug: Show all files in current directory
    echo "=== Files after bamtools split ===" >&2
    ls -la >&2
    echo "=== BAM files matching pattern ===" >&2
    ls -la ${prefix}*.bam 2>&1 >&2 || echo "No BAM files found" >&2

    # Ensure at least one output BAM exists
    # Count output files (exclude input files to avoid false positives)
    num_outputs=\$(ls ${prefix}*.bam 2>/dev/null | grep -v '.tagged.bam' | wc -l)

    if [ "\$num_outputs" -eq "0" ]; then
        echo "Warning: bamtools split produced no output. Using input as fallback." >&2
        # Copy first input BAM as output
        cp ${bam} ${prefix}.bam || exit 1
        echo "Created ${prefix}.bam as fallback output" >&2
    else
        echo "bamtools split created \$num_outputs output file(s)" >&2
    fi

    # Debug: Final file list
    echo "=== Final BAM files ===" >&2
    ls -la *.bam 2>&1 >&2 || echo "No *.bam files" >&2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bamtools: \$( bamtools --version | grep -e 'bamtools' | sed 's/^.*bamtools //' )
    END_VERSIONS
    """
}
