#!/usr/bin/env nextflow

nextflow.enable.dsl=2


// params user should modify at runtime
params.reads='reads_{1,2}.fq.gz'


// internal parameters (typically do not need editing)
params.outprefix='./'
params.procout='trinity_out'


process jellyfish {
  tag "${dir}/${name}"
  stageInMode ( params.copyinput ? 'copy' : 'symlink' )

  input:
  tuple val(dir), val(name), path(read1), path(read2)

  output:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procout}")

  script:
  """
  mem='${task.memory}'
  mem=\${mem%B}
  mem=\${mem// /}

  Trinity \
    --left $read1 \
    --right $read2 \
    --seqType fq \
    --no_normalize_reads \
    --verbose \
    --no_version_check \
    --output ${params.procout} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --no_run_inchworm
  """
}


process inchworm {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procout}")

  output:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procout}")

  script:
  """
  mem='${task.memory}'
  mem=\${mem%B}
  mem=\${mem// /}

  Trinity \
    --left $read1 \
    --right $read2 \
    --seqType fq \
    --no_normalize_reads \
    --verbose \
    --no_version_check \
    --output ${params.procout} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --inchworm_cpu ${task.cpus} \
    --no_run_chrysalis
  """
}


process chrysalis {
  tag "${dir}/${name}"
//  publishDir "${dir}", mode: 'symlink', saveAs: { filename -> "${params.outprefix}${name}" } // test only

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procout}")

  output:
  tuple val("${dir}/${name}"), val(dir), val(name), path("${params.procout}"), emit: dir
  tuple val("${dir}/${name}"), val(dir), val(name), path('fasta_list'), emit: list
//  tuple val(dir), val(name), path("${params.procout}") // test only

  script:
  """
  mem='${task.memory}'
  mem=\${mem%B}
  mem=\${mem// /}

  Trinity \
    --left $read1 \
    --right $read2 \
    --seqType fq \
    --no_normalize_reads \
    --verbose \
    --no_version_check \
    --output ${params.procout} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --no_distributed_trinity_exec

  find ${params.procout}/read_partitions -name '*inity.reads.fa' >fasta_list
  """
}


process butterfly {
  tag "${dir}/${name}/${read}"

  input:
  tuple val(dir), val(name), val(read), path(directory)

  output:
  tuple val(dir), val(name), path("${params.procout}")

// this one has been reworded compared to SIH original, and checked against Trinity code
  script:
// #for f in \$(find ${params.procout}/read_partitions -name '*inity.reads.fa') ; do
  """
  mem='${task.memory}'
  mem=\${mem%B}
  mem=\${mem// /}

  Trinity \
    --single $read \
    --run_as_paired \
    --seqType fa \
    --verbose \
    --no_version_check \
    --workdir trinity_workdir \
    --output ${read}.out \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --trinity_complete \
    --full_cleanup \
    --no_distributed_trinity_exec
  """
}


process aggregate {
  tag "${dir}/${name}"
  publishDir "${dir}/${params.outprefix}", mode: 'copy', saveAs: { filename -> "${name}_"+filename }

  input:
  tuple val(dir), val(name), path("${params.procout}")

  output:
  tuple val(dir), val(name), path("Trinity.fasta"), path("Trinity.fasta.gene_trans_map")

  script:
  """
  my_trinity=\$(which Trinity)
  my_trinity=\$(dirname \$my_trinity)

  find ${params.procout}/read_partitions/ -name '*inity.fasta' | \
    \${my_trinity}/util/support_scripts/partitioned_trinity_aggregator.pl \
    --token_prefix TRINITY_DN --output_prefix ${params.procout}/Trinity.tmp

  mv ${params.procout}/Trinity.tmp.fasta Trinity.fasta

  \${my_trinity}/util/support_scripts/get_Trinity_gene_to_trans_map.pl Trinity.fasta > Trinity.fasta.gene_trans_map
  """
}



workflow {

// inputs
  read_ch = channel.fromFilePairs( params.reads )
                   .map{ it -> [ it[1][0].parent, it[0], it[1][0], it[1][1] ] }

// tasks
  jellyfish(read_ch)

  inchworm(jellyfish.out)

  chrysalis(inchworm.out)
// test 1
//  chrysalis.out
//    .transpose()
//    .view()
// test 2

  butterfly( chrysalis.out.dir
    .cross(chrysalis.out.list.splitText(by: 1, elem: 3, file: false))
    .map{ zit -> [ zit[0][1], zit[0][2], zit[1][3].replaceAll(/\s*$/, '') , zit[0][3] ] } )

  aggregate(butterfly.out.last())

}
