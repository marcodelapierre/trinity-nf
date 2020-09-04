**NOTE**: development of this pipeline is currently paused.  I will resume it when/if relevant.


## Trinity assembly pipeline for USyd
  
The pipeline requires [Nextflow](https://github.com/nextflow-io/nextflow) to run.
Tests have been done with Nextflow version `19.10.0`.


### Pipeline and requirements

Jellyfish -> Inchworm -> Chrysalis -> Mini-assemblies -> Gene-to-Trans

The main software requirement is an installation of [Trinity](https://github.com/trinityrnaseq/trinityrnaseq). 
Tests have been run with Trinity version `2.8.6`.  
Usage of a Singularity container runtime is recommended, especially where I/O performance are critical.


### Basic usage


### Usage on different systems


### Optional parameters


### Multiple inputs at once


### Ackwnowledgements

This pipeline is based on [SIH-Raijin-Trinity](https://github.com/Sydney-Informatics-Hub/SIH-Raijin-Trinity).
