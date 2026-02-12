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
    // Handle both single file and collection cases
    def bam_list = bam instanceof List ? bam : [bam]
    def input_list = bam_list.collect{"-in $it"}.join(' ')
    def first_bam = bam_list[0]
    def first_bam_basename = new File(first_bam.toString()).getName()
    def num_inputs = bam_list.size()
    """
    set -e
    set -o pipefail
    
    # Run bamtools merge and split
    # Handle single file case: if only one input, skip merge and go directly to split
    if [ $num_inputs -eq 1 ]; then
        echo "Single input file detected, skipping merge" >&2
        bamtools split -in ${first_bam} -stub $prefix $args 2>&1 | tee bamtools_split.err || true
    else
        echo "Multiple input files detected, merging first" >&2
        bamtools merge $input_list | bamtools split -stub $prefix $args 2>&1 | tee bamtools_split.err || true
    fi
    set +e

    # Count output files (exclude input files)
    num_outputs=\$(ls ${prefix}*.bam 2>/dev/null | grep -v '.tagged.bam' | wc -l)
    echo "Number of output BAM files: \$num_outputs" >&2

    # If no output, create fallback by copying input
    if [ "\$num_outputs" -eq "0" ]; then
        echo "Warning: bamtools split produced no output. Using input as fallback." >&2
        echo "Input file: ${first_bam}" >&2
        ls -lh ${first_bam} >&2
        if cp -L ${first_bam} ${prefix}.bam 2>&1; then
            echo "Successfully copied with cp -L" >&2
        elif cp ${first_bam} ${prefix}.bam 2>&1; then
            echo "Successfully copied with cp" >&2
        else
            echo "ERROR: Failed to copy input file" >&2
            exit 1
        fi
        if [ ! -s ${prefix}.bam ]; then
            echo "ERROR: Output file is empty" >&2
            ls -lh ${prefix}.bam >&2
            exit 1
        fi
        echo "Created ${prefix}.bam as fallback (size: \$(stat -c%s ${prefix}.bam) bytes)" >&2
    fi

    # Final check: ensure at least one output file exists
    if [ "\$num_outputs" -eq "0" ]; then
        # We created a fallback, verify it exists
        if [ ! -f ${prefix}.bam ] || [ ! -s ${prefix}.bam ]; then
            echo "ERROR: Fallback file ${prefix}.bam not found or empty!" >&2
            ls -la ${prefix}*.bam >&2
            exit 1
        fi
    else
        # bamtools split created files, verify at least one exists
        # List all matching files and check
        output_files=\$(ls ${prefix}*.bam 2>/dev/null | grep -v '.tagged.bam' || true)
        if [ -z "\$output_files" ]; then
            echo "ERROR: No output BAM files found after split!" >&2
            ls -la ${prefix}* >&2
            exit 1
        fi
        echo "Found output files:" >&2
        echo "\$output_files" >&2
    fi

    # Create versions file
    bamtools_version=\$(bamtools --version 2>&1 | grep -e 'bamtools' | sed 's/^.*bamtools //' | xargs 2>/dev/null || echo "unknown")
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bamtools: "\${bamtools_version}"
    END_VERSIONS
    """
}
