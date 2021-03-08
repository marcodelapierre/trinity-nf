#!/usr/bin/env nextflow

nextflow.enable.dsl=2


// params user should modify at runtime
params.reads='reads_{1,2}.fq.gz'
params.localdisk = false


// internal parameters (typically do not need editing)
params.outprefix='./'
params.procoutdir='trinity_out'


process jellyfish {
  tag "${dir}/${name}"
  stageInMode { params.copyinput ? 'copy' : 'symlink' }

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
  tuple val(dir), val(name), path{ params.localdisk ? "chunk*.tgz" : "${params.procoutdir}/read_partitions/**inity.reads.fa" }

  script:
  """
  if [ "${params.localdisk}" == "true" ] ; then
    here=\$PWD
    mkdir -p ${params.localdir}
    cp -r \$( readlink $read1 ) ${params.localdir}/
    cp -r \$( readlink $read2 ) ${params.localdir}/
    cp -r \$( readlink ${params.procoutdir} ) ${params.localdir}/
    cd ${params.localdir}
  fi

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

  if [ "${params.localdisk}" == "true" ] ; then
    find ${params.procoutdir}/read_partitions -name "*inity.reads.fa" >output_list
    split -l ${params.bf_collate} -a 4 output_list chunk
    for f in chunk* ; do
      tar -cz -h -f \${f}.tgz -T \${f}
    done
    cd \$here
    cp ${params.localdir}/chunk*.tgz .
    rm -r ${params.localdir}
  fi
  """
}


process butterfly {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(reads_fa)

  output:
  tuple val(dir), val(name), path{ params.localdisk ? "out_${reads_fa}" : "*inity.fasta" }, optional: true

// this one has been reworded compared to SIH original, and checked against Trinity code
  script:
  """
  if [ "${params.localdisk}" == "true" ] ; then
    here=\$PWD
    mkdir -p ${params.localdir}
    cp -r \$( readlink $reads_fa ) ${params.localdir}/
    cd ${params.localdir}
  fi

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

  if [ "${params.localdisk}" == "true" ] ; then
    tar xzf ${reads_fa}
    find ${params.procoutdir}/read_partitions -name "*inity.reads.fa" | parallel -j ${task.cpus} ./trinity.sh {}
    find ${params.procoutdir}/read_partitions -name "*inity.fasta" | tar -cz -h -f out_${reads_fa} -T -
    cd \$here
    cp ${params.localdir}/out_chunk*.tgz .
    rm -r ${params.localdir}
  else
    ls ${reads_fa} | parallel -j ${task.cpus} ./trinity.sh {}
  fi
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

  if [ "${params.localdisk}" == "true" ] ; then
    here=\$PWD
    mkdir -p ${params.localdir}
    cd ${params.localdir}
    for f in ${reads_fasta} ; do
      cp \$( readlink \$here/\$f ) .
      tar xzf \${f}
    done
    find ${params.procoutdir}/read_partitions -name "*inity.fasta" | \
      \${my_trinity}/util/support_scripts/partitioned_trinity_aggregator.pl \
      --token_prefix TRINITY_DN --output_prefix Trinity.tmp
  else
    ls ${reads_fasta} | \
      \${my_trinity}/util/support_scripts/partitioned_trinity_aggregator.pl \
      --token_prefix TRINITY_DN --output_prefix Trinity.tmp
  fi

  mv Trinity.tmp.fasta Trinity.fasta

  \${my_trinity}/util/support_scripts/get_Trinity_gene_to_trans_map.pl Trinity.fasta > Trinity.fasta.gene_trans_map

  if [ "${params.localdisk}" == "true" ] ; then
    cd \$here
    cp ${params.localdir}/Trinity.fasta* .
    rm -r ${params.localdir}
  fi
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

  if ( params.localdisk ) {
    butterfly( chrysalis.out.transpose() )
  } else {
    butterfly( chrysalis.out
      .map{ zit -> [ zit[0], zit[1], zit[2].collate( params.bf_collate ) ] }
      .transpose() )
  }

  aggregate( butterfly.out
    .groupTuple(by: [0,1])
    .map{ yit -> [ yit[0], yit[1], yit[2].flatten() ] } )

}
