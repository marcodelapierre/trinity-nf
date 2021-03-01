#!/bin/bash

. vars.sh

singularity exec -B ${iopath} ${sifpath}/trinityrnaseq_2.8.6.sif bash -c " \
  Trinity \
    --left ${first} \
    --right ${second} \
    --seqType ${seqtype} \
    --no_normalize_reads \
    --verbose \
    --no_version_check \
    --output ${out_dir} \
    --max_memory ${mem} \
    --CPU ${cpus} \
    --no_run_inchworm \
" 2>&1 | tee out1
