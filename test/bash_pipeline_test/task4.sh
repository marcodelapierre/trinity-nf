#!/bin/bash

. vars.sh

for f in $(find ${out_dir}/read_partitions -name '*inity.reads.fa') ; do 

  singularity exec -B ${iopath} ${sifpath}/trinityrnaseq_2.8.6.sif bash -c " \
    Trinity \
      --single ${f} \
      --run_as_paired \
      --seqType ${seqtype} \
      --verbose \
      --no_version_check \
      --workdir ${work_dir} \
      --output ${f}.out \
      --max_memory ${mem} \
      --CPU ${cpus} \
      --trinity_complete \
      --full_cleanup \
      --no_distributed_trinity_exec \
  "

done 2>&1 | tee out4
