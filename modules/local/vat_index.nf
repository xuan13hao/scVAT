process VAT_INDEX {
    label 'process_medium'

    // VAT binary should be placed in bin/ directory or available in PATH
    // The module will try to use $projectDir/bin/VAT first, then fall back to system VAT

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.vatf"), emit: index
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def dbtype = task.ext.dbtype ?: 'nucl'
    
    """
    # Try to use VAT from bin directory first, then fall back to system PATH
    if [ -f "$projectDir/bin/VAT" ] && [ -x "$projectDir/bin/VAT" ]; then
        VAT_BIN="$projectDir/bin/VAT"
    elif command -v VAT >/dev/null 2>&1; then
        VAT_BIN=\$(command -v VAT)
    else
        echo "ERROR: VAT binary not found. Please place VAT in bin/ directory or ensure it's in PATH." >&2
        exit 1
    fi
    
    \$VAT_BIN makevatdb \\
        --in $fasta \\
        --dbtype $dbtype \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vat: \$(\$VAT_BIN --version 2>&1 || echo "version unknown")
    END_VERSIONS
    """

    stub:
    """
    touch ${fasta.baseName}.vatf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vat: "version unknown"
    END_VERSIONS
    """
}
