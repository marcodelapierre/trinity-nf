#!/bin/bash

. vars.sh

my_trinity=$(singularity exec -B ${iopath} ${sifpath}/trinityrnaseq_2.8.6.sif which Trinity)
my_trinity=${my_trinity%/Trinity}

singularity exec -B ${iopath} ${sifpath}/trinityrnaseq_2.8.6.sif bash -c " \
  find ${out_dir}/read_partitions/ -name '*inity.fasta' | \
    ${my_trinity}/util/support_scripts/partitioned_trinity_aggregator.pl \
    --token_prefix TRINITY_DN --output_prefix ${out_dir}/Trinity.tmp && \
  mv ${out_dir}/Trinity.tmp.fasta ${out_dir}/Trinity.fasta && \
  ${my_trinity}/util/support_scripts/get_Trinity_gene_to_trans_map.pl ${out_dir}/Trinity.fasta > ${out_dir}/Trinity.fasta.gene_trans_map \
" 2>&1 | tee out5
