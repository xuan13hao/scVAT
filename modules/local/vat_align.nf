process VAT_ALIGN {
    tag "$meta.id"
    label 'process_high'

    // VAT binary should be placed in bin/ directory or available in PATH
    // The module will try to use $projectDir/bin/VAT first, then fall back to system VAT
    // Also need samtools for BAM conversion if output format is BAM

    conda "bioconda::samtools=1.19.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.19.2--h50ea8bc_0' :
        'biocontainers/samtools:1.19.2--h50ea8bc_0' }"

    input:
    tuple val(meta), path(reads)
    tuple val(meta2), path(reference)
    val bam_format
    val bam_index_extension
    val alignment_mode  // 'wgs', 'splice', 'circ', etc.
    val long_read_mode  // boolean: whether to use --long flag

    output:
    tuple val(meta), path("*.paf")                       , optional: true, emit: paf
    tuple val(meta), path("*.sam")                       , optional: true, emit: sam
    tuple val(meta), path("*.bam")                       , optional: true, emit: bam
    tuple val(meta), path("*.bam.${bam_index_extension}"), optional: true, emit: index
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args  = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Determine alignment mode based on input type
    // For short reads, use splice (genome) or wgs (transcriptome) mode
    // For long reads, use splice/wgs/circ as before, with --long flag
    def mode_flag = ''
    if (alignment_mode == 'splice') {
        mode_flag = '--splice'
    } else if (alignment_mode == 'circ') {
        mode_flag = '--circ'
    } else if (alignment_mode == 'wgs') {
        mode_flag = '--wgs'
    } else if (alignment_mode == 'sr' || alignment_mode == 'short_read') {
        mode_flag = ''  // Short-read preset for VAT
    }
    def long_flag = long_read_mode ? '--long' : ''
    def output_format = bam_format ? 'sam' : (task.ext.output_format ?: 'sam')
    def output_file = bam_format ? "${prefix}.sam" : "${prefix}.${output_format}"
    // For compatibility with older samtools versions, don't use --write-index
    def bam_output = "${prefix}.bam"
    
    // Handle BAM input conversion if needed
    def bam_input = "${reads.extension}".matches('sam|bam|cram')
    def samtools_reset_fastq = bam_input ? "samtools reset --threads ${task.cpus-1} $args2 $reads | samtools fastq --threads ${task.cpus-1} |" : ''
    def query = bam_input ? "-" : reads
    
    // VAT can use either fasta or .vatf index file
    // If reference is a .vatf file, use it directly; otherwise use the fasta
    def ref_db = reference

    """
    # Ensure libstdc++ and other C++ libs are found (needed for VAT binary)
    export LD_LIBRARY_PATH=/usr/local/lib:\${LD_LIBRARY_PATH:-}

    # Try to use VAT from bin directory first, then fall back to system PATH
    if [ -f "$projectDir/bin/VAT" ] && [ -x "$projectDir/bin/VAT" ]; then
        VAT_BIN="$projectDir/bin/VAT"
    elif command -v VAT >/dev/null 2>&1; then
        VAT_BIN=\$(command -v VAT)
    else
        echo 'ERROR: VAT binary not found. Please place VAT in bin/ directory or ensure it is in PATH.' >&2
        exit 1
    fi
    
    $samtools_reset_fastq \\
    \$VAT_BIN dna \\
        -d $ref_db \\
        -q $query \\
        $mode_flag \\
        $long_flag \\
        -o $output_file \\
        -f $output_format \\
        -p $task.cpus \\
        $args

    if [ "$bam_format" = "true" ]; then
        samtools sort -@ ${task.cpus-1} -o $bam_output ${prefix}.sam
        rm ${prefix}.sam
        # Create index separately for compatibility with older samtools versions
        # Note: Very old samtools versions don't support -@ for index command
        if [ "$bam_index_extension" = "bai" ]; then
            samtools index $bam_output
        elif [ "$bam_index_extension" = "csi" ]; then
            samtools index -c $bam_output
        fi
    fi

    # Get versions and write to versions.yml
    vat_ver=\$(\$VAT_BIN --version 2>&1 | head -1 | sed 's/Error.*//' | xargs 2>/dev/null || echo "version unknown")
    if echo "\$vat_ver" | grep -qiE "(unrecognised|error)"; then
        vat_ver="version unknown"
    fi
    # Ensure vat_ver is not empty
    if [ -z "\$vat_ver" ]; then
        vat_ver="version unknown"
    fi
    samtools_ver=\$(samtools --version 2>&1 | sed 's/^.*samtools //; s/Using.*\$//' | head -1 | xargs 2>/dev/null || echo "unknown")
    # Ensure samtools_ver is not empty
    if [ -z "\$samtools_ver" ]; then
        samtools_ver="unknown"
    fi
    
    # Write versions.yml - ensure values are on same line and properly quoted
    echo "${task.process}:" > versions.yml
    echo "    vat: \"\${vat_ver}\"" >> versions.yml
    echo "    samtools: \"\${samtools_ver}\"" >> versions.yml
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_file = bam_format ? "${prefix}.bam" : "${prefix}.paf"
    def bam_index = bam_index_extension ? "touch ${prefix}.bam.${bam_index_extension}" : ""
    
    """
    touch $output_file
    ${bam_index}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vat: "version unknown"
    END_VERSIONS
    """
}
