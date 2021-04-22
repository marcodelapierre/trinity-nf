#!/usr/bin/env nextflow

nextflow.enable.dsl = 2


// params user should modify at runtime
params.reads = 'reads_{1,2}.fq.gz'


// internal parameters (typically do not need editing)
params.outprefix = './'
params.taskoutdir = 'trinity_out'
//
params.overoutdirprefix = 'overlays_'
params.overfileprefix = 'overlay_'


process overlay_one {
  tag "${dir}/${name}"
  storeDir "${dir}/${params.overoutdirprefix}${name}"

  container ''

  input:
  tuple val(dir), val(name), path(read1), path(read2)

  output:
  tuple val(dir), val(name), path("${params.overfileprefix}one")

  script:
  """
  singularity exec docker://ubuntu:18.04 bash -c ' \
  out_file=\"${params.overfileprefix}one\" && \
  mkdir -p overlay_tmp/upper overlay_tmp/work && \
  dd if=/dev/zero of=\${out_file} count=${params.overlay_size_mb_one} bs=1M && \
  mkfs.ext3 -d overlay_tmp \${out_file} && \
  rm -rf overlay_tmp \
  '
  """
}


process overlay_many {
  tag "${dir}/${name}"
  storeDir "${dir}/${params.overoutdirprefix}${name}"

  container ''

  input:
  tuple val(dir), val(name), path(reads_fa)

  output:
  tuple val(dir), val(name), val(label_fa), path("${params.overfileprefix}${label_fa}")

  script:
  label_fa = file(reads_fa).getSimpleName()
  """
  singularity exec docker://ubuntu:18.04 bash -c ' \
  out_file=\"${params.overfileprefix}${reads_fa.toString().minus('.tgz')}\" && \
  mkdir -p overlay_tmp/upper overlay_tmp/work && \
  dd if=/dev/zero of=\${out_file} count=${params.overlay_size_mb_many} bs=1M && \
  mkfs.ext3 -d overlay_tmp \${out_file} && \
  rm -rf overlay_tmp \
  '
  """
}


process jellyfish {
  tag "${dir}/${name}"
  stageInMode { params.copyinput ? 'copy' : 'symlink' }

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.overtaskfile}")

  output:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.taskoutdir}"), path("${params.overtaskfile}")

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
    --output ${params.taskoutdir} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --no_run_inchworm
  """
}


process inchworm {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.taskoutdir}"), path("${params.overtaskfile}")

  output:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.taskoutdir}"), path("${params.overtaskfile}")

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
    --output ${params.taskoutdir} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --inchworm_cpu ${task.cpus} \
    --no_run_chrysalis
  """
}


process chrysalis {
  tag "${dir}/${name}"

  input:
  tuple val(dir), val(name), path(read1), path(read2), path("${params.taskoutdir}"), path("${params.overtaskfile}")

  output:
  tuple val(dir), val(name), path{ params.localdisk ? "chunk*.tgz" : "${params.taskoutdir}/read_partitions/**inity.reads.fa" }

  script:
  """
  if [ "${params.localdisk}" == "true" ] ; then
    here=\$PWD
    rm -rf ${params.localdir}
    mkdir ${params.localdir}
    cp -r \$( readlink $read1 ) ${params.localdir}/
    cp -r \$( readlink $read2 ) ${params.localdir}/
    cp -r \$( readlink ${params.taskoutdir} ) ${params.localdir}/
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
    --output ${params.taskoutdir} \
    --max_memory \${mem} \
    --CPU ${task.cpus} \
    --no_distributed_trinity_exec

  if [ "${params.localdisk}" == "true" ] ; then
    find ${params.taskoutdir}/read_partitions -name "*inity.reads.fa" >output_list
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
  tuple val(dir), val(name), path(reads_fa), path("${params.overtaskfile}")

  output:
  tuple val(dir), val(name), path{ params.localdisk ? "out_${reads_fa}" : "*inity.fasta" }, optional: true

// this one has been reworded compared to SIH original, and checked against Trinity code
  script:
  """
  if [ "${params.localdisk}" == "true" ] ; then
    here=\$PWD
    rm -rf ${params.localdir}
    mkdir ${params.localdir}
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
    find ${params.taskoutdir}/read_partitions -name "*inity.reads.fa" | parallel -j ${task.cpus} ./trinity.sh {}
    find ${params.taskoutdir}/read_partitions -name "*inity.fasta" | tar -cz -h -f out_${reads_fa} -T -
    cd \$here
    cp ${params.localdir}/out_chunk*.tgz .
    rm -r ${params.localdir}
  else
    ls *inity.reads.fa | parallel -j ${task.cpus} ./trinity.sh {}
  fi
  """
}


process aggregate {
  tag "${dir}/${name}"
  publishDir "${dir}/${params.outprefix}", mode: 'copy', saveAs: { filename -> "${name}_"+filename }

  input:
  tuple val(dir), val(name), path(reads_fasta), path("${params.overtaskfile}")

  output:
  tuple val(dir), val(name), path("Trinity.fasta"), path("Trinity.fasta.gene_trans_map")

  script:
  """
  my_trinity=\$(which Trinity)
  my_trinity=\$(dirname \$my_trinity)

  if [ "${params.localdisk}" == "true" ] ; then
    here=\$PWD
    rm -rf ${params.localdir}
    mkdir ${params.localdir}
    cd ${params.localdir}
    for f in ${reads_fasta} ; do
      cp \$( readlink \$here/\$f ) .
      tar xzf \${f}
    done
    find ${params.taskoutdir}/read_partitions -name "*inity.fasta" >input_list
  else
    ls *inity.fasta >input_list
  fi

  cat input_list | \${my_trinity}/util/support_scripts/partitioned_trinity_aggregator.pl \
    --token_prefix TRINITY_DN --output_prefix Trinity.tmp
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
  if ( params.overlay ) {
    read_ch = channel.fromFilePairs( params.reads )
                .map{ it -> [ it[1][0].parent, it[0], it[1][0], it[1][1] ] }
  } else {
    dummy_ov = file('dummy_overlay')
    dummy_ov.text = 'dummy_overlay\n'
    read_ch = channel.fromFilePairs( params.reads )
                .map{ it -> [ it[1][0].parent, it[0], it[1][0], it[1][1], dummy_ov ] }
  }

//
// tasks
//
  if ( params.overlay ) {
    overlay_one(read_ch)
    jellyfish( read_ch.join(overlay_one.out, by: [0,1]) )
  } else {
    jellyfish(read_ch)
  }

  inchworm(jellyfish.out)

  chrysalis(inchworm.out)

  if ( params.overlay ) {
    overlay_many( chrysalis.out.transpose() )
    butterfly( chrysalis.out
      .transpose().map{ xit -> [ xit[0], xit[1], file(xit[2]).getSimpleName(), xit[2] ] }
      .join(overlay_many.out, by: [0,1,2])
      .map{ wit -> [ wit[0], wit[1], wit[3], wit[4] ] } )
  } else if ( params.localdisk ) {
    butterfly( chrysalis.out
      .transpose()
      .map{ xit -> ( xit << dummy_ov) } )
  } else {
    butterfly( chrysalis.out
      .map{ zit -> [ zit[0], zit[1], zit[2].collate( params.bf_collate ) ] }
      .transpose()
      .map{ xit -> ( xit << dummy_ov) } )
  }

  if ( params.overlay ) {
    aggregate( butterfly.out
      .groupTuple(by: [0,1])
      .map{ yit -> [ yit[0], yit[1], yit[2].flatten() ] }
      .join(overlay_one.out, by: [0,1]) )
  } else {
    aggregate( butterfly.out
      .groupTuple(by: [0,1])
      .map{ yit -> [ yit[0], yit[1], yit[2].flatten(), dummy_ov ] } )
  }

}
