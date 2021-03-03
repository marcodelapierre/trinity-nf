#!/usr/bin/env nextflow

nextflow.enable.dsl=2


// params user should modify at runtime
params.reads='reads_{1,2}.fq.gz'


// internal parameters (typically do not need editing)
params.outprefix='./'
params.procoutdir='trinity_out'


process jellyfish {
  tag "${dir}/${name}"
  stageInMode ( params.copyinput ? 'copy' : 'symlink' )

  input:
  tuple val(dir), val(name), path(read1), path(read2)

  output:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procoutdir}")

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
    --output ${params.procoutdir} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --no_run_inchworm
  """
}


process inchworm {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procoutdir}")

  output:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procoutdir}")

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
    --output ${params.procoutdir} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --inchworm_cpu ${task.cpus} \
    --no_run_chrysalis
  """
}


process chrysalis {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.procoutdir}")

  output:
  tuple val(dir), val(name), path("${params.procoutdir}/read_partitions/**inity.reads.fa")

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
    --output ${params.procoutdir} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --no_distributed_trinity_exec
  """
}


process butterfly {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(reads_fa)

  output:
  tuple val(dir), val(name), path("*inity.fasta") optional true

// this one has been reworded compared to SIH original, and checked against Trinity code
  script:
  """
  mem='${params.bf_mem}'
  mem=\${mem%B}
  export mem=\${mem// /}

  cat << "EOF" >trinity.sh
Trinity \
  --single \${1} \
  --run_as_paired \
  --seqType fa \
  --verbose \
  --no_version_check \
  --workdir trinity_workdir \
  --output \${1}.out \
  --max_memory \${mem} \
  --CPU ${params.bf_cpus} \
  --trinity_complete \
  --full_cleanup \
  --no_distributed_trinity_exec
EOF
  chmod +x trinity.sh

  ls ${reads_fa} | parallel -j ${task.cpus} ./trinity.sh {}
  """
}


process aggregate {
  tag "${dir}/${name}"
  publishDir "${dir}/${params.outprefix}", mode: 'copy', saveAs: { filename -> "${name}_"+filename }

  input:
  tuple val(dir), val(name), path(reads_fasta)

  output:
  tuple val(dir), val(name), path("Trinity.fasta"), path("Trinity.fasta.gene_trans_map")

  script:
  """
  my_trinity=\$(which Trinity)
  my_trinity=\$(dirname \$my_trinity)

  ls ${reads_fasta} | \
    \${my_trinity}/util/support_scripts/partitioned_trinity_aggregator.pl \
    --token_prefix TRINITY_DN --output_prefix Trinity.tmp

  mv Trinity.tmp.fasta Trinity.fasta

  \${my_trinity}/util/support_scripts/get_Trinity_gene_to_trans_map.pl Trinity.fasta > Trinity.fasta.gene_trans_map
  """
}



workflow {

// inputs
  read_ch = channel.fromFilePairs( params.reads )
                   .map{ it -> [ it[1][0].parent, it[0], it[1][0], it[1][1] ] }

//
// tasks
//
  jellyfish(read_ch)

  inchworm(jellyfish.out)

  chrysalis(inchworm.out)

  butterfly( chrysalis.out
    .map{ zit -> [ zit[0], zit[1], zit[2].collate( params.bf_collate ) ] }
    .transpose() )

  aggregate( butterfly.out
    .groupTuple(by: [0,1])
    .map{ yit -> [ yit[0], yit[1], yit[2].flatten() ] } )

}
