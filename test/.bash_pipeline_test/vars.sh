#!/bin/bash
sifpath=".."
iopath="$(pwd)/.."

seqtype="fq"
first="${iopath}/reads_1.fq.gz"
second="${iopath}/reads_2.fq.gz"

out_dir="trinity_results"
work_dir="trinity_workdir"

cpus="1"
mem="8G"
