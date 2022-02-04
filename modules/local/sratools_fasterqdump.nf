
process SRATOOLS_FASTERQDUMP {
    tag "$meta.id"
    label 'process_medium'
    label 'error_retry_ignore'

    conda (params.enable_conda ? 'bioconda::sra-tools=2.11.0 conda-forge::pigz=2.6' : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0' :
        'quay.io/biocontainers/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0' }"

    input:
    tuple val(meta), path(sra)

    output:
    tuple val(meta), path(fastq_output), emit: reads
    tuple val(meta), path(md5_output)  , emit: md5
    path "versions.yml"                , emit: versions

    script:
    def args = task.ext.args  ?: ''
    def args2 = task.ext.args2 ?: ''
    def config = "/LIBS/GUID = \"${UUID.randomUUID().toString()}\"\\n/libs/cloud/report_instance_identity = \"true\"\\n"
    // Paired-end data extracted by fasterq-dump (--split-3 the default) always creates
    // *_1.fastq *_2.fastq files but sometimes also an additional *.fastq file
    // for unpaired reads which we ignore here.
    uncompressed_fastqs = meta.single_end ? '*.fastq' : '*_{1,2}.fastq'
    uncompressed_fastq_regex =  meta.single_end ? '.*\\.fastq' : '.*_[12]\\.fastq'
    fastq_output = meta.single_end ? '*.fastq.gz' : '*_{1,2}.fastq.gz'
    md5_output = meta.single_end ? '*.fastq.gz.md5' : '*_{1,2}.fastq.gz.md5'
    """
    eval "\$(vdb-config -o n NCBI_SETTINGS | sed 's/[" ]//g')"
    if [[ ! -f "\${NCBI_SETTINGS}" ]]; then
        mkdir -p "\$(dirname "\${NCBI_SETTINGS}")"
        printf '${config}' > "\${NCBI_SETTINGS}"
    fi

    fasterq-dump \\
        $args \\
        --threads $task.cpus \\
        ${sra.name}

    ## delete *.fastq if paired-end read data since this contains unpaired reads
    if [[ -f ${sra.name}.fastq  && ! ${sra.name}.fastq =~ ${uncompressed_fastq_regex} ]]; then
        rm ${sra.name}.fastq
    fi

    pigz \\
        $args2 \\
        --no-name \\
        --processes $task.cpus \\
        ${uncompressed_fastqs}

    ## Rename FastQ files by meta.id
    if [ -f  ${sra.name}.fastq.gz ]; then
        mv ${sra.name}.fastq.gz ${meta.id}.fastq.gz
        md5sum ${meta.id}.fastq.gz > ${meta.id}.fastq.gz.md5
    fi
    if [ -f  ${sra.name}_1.fastq.gz ]; then
        mv ${sra.name}_1.fastq.gz ${meta.id}_1.fastq.gz
        md5sum ${meta.id}_1.fastq.gz > ${meta.id}_1.fastq.gz.md5
    fi

    if [ -f  ${sra.name}_2.fastq.gz ]; then
        mv ${sra.name}_2.fastq.gz ${meta.id}_2.fastq.gz
        md5sum ${meta.id}_2.fastq.gz > ${meta.id}_2.fastq.gz.md5
    fi

    ## remove .sra file
    rm \$(readlink ${sra.name})/${sra.name}.sra

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sratools: \$(fasterq-dump --version 2>&1 | grep -Eo '[0-9.]+')
        pigz: \$( pigz --version 2>&1 | sed 's/pigz //g' )
    END_VERSIONS
    """
}
