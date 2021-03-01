## Trinity assembly pipeline from USydney Informatics Hub
  
The pipeline requires [Nextflow](https://github.com/nextflow-io/nextflow) to run.
DSL2 syntax is used, so that Nextflow version `20.07.1` or higher is recommended.


### Pipeline and requirements

This pipeline is based on [SIH-Raijin-Trinity](https://github.com/Sydney-Informatics-Hub/SIH-Raijin-Trinity):

Jellyfish -> Inchworm -> Chrysalis -> Butterfly mini-assemblies -> Aggregate

The main software requirement is an installation of [Trinity](https://github.com/trinityrnaseq/trinityrnaseq).  
Tests have been run with Trinity version `2.8.6`.  


### Basic usage

```
nextflow run marcodelapierre/trinity-nf \
  --reads='reads_{1,2}.fq.gz' \
  -profile zeus --slurm_account='pawsey0001'
```

The flag `--reads` is required to specify the name of the pair of input read files.  
Note some syntax requirements: 
- encapsulate the file name specification between single quotes;
- within a file pair, use names that differ only by a character, which distinguishes the two files, in this case `1` or `2`;
- use curly brackets to specify the wild character within the file pair, *e.g.* `{1,2}`;
- the prefix to the wild character serves as the sample ID, *e.g.* `reads_`.

The flag `-profile` allows to select the appropriate profile for the machine in use, Zeus in this case.  On Zeus, use the flag `--slurm_account` to set your Pawsey account.

The pipeline will output two files prefixed by the sample ID, in this case: `reads_Trinity.fasta` and `reads_Trinity.fasta.gene_trans_map`.  By default, they are saved in the same directory as the input read files.


### Multiple inputs at once

The pipeline allows to feed in multiple datasets at once.  You can use input file name patterns to this end:

1. multiple input read pairs in the same directory, *e.g.* `sample1_R{1,2}.fq`, `sample2_R{1,2}.fq` and so on, use: `--reads='sample*{1,2}.fq'`;

2. multiple read pairs in distinct directories, *e.g.* `sample1/R{1,2}.fq`, `sample2/R{1,2}.fq` and so on, use: `--reads='sample*/R{1,2}.fq'`.


### Usage on different systems

The main pipeline file, `main.nf`, contains the pipeline logic and its almost completely machine independent.  
All system specific information is contained in configuration files under the `config` directory, whose information is included in `nextflow.config`.  

Examples are provided for Zeus and Nimbus at Pawsey;  you can use them as templates for other systems.  
Typical information to be specified includes scheduler configuration, software availability (containers, conda, modules, ..), and eventually other specificities such as location of the work directory for runtime and filesystem options (*e.g.* set cache mode to *lenient* when using parallel filesystems).  


### Additional resources

The `extra` directory contains an example Slurm script, `job.sh`, to run on Zeus.  There is also a sample script `log.sh` that takes a run name as input and displays formatted runtime information.

The `test` directory contains a small input dataset and a launching script for quick testing of the pipeline, with total runtime of a few minutes.
