#!/bin/bash
#SBATCH -p batch --time 2-0:00:00 --ntasks 8 --nodes 1 --mem 24G --out logs/mask.%a.%A.log

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi
if [ -z $SLURM_JOB_ID ]; then
	SLURM_JOB_ID=$$
fi

INDIR=genomes
OUTDIR=genomes
LIBRARY=lib/zygo_repeats.fasta
SAMPFILE=genomes.csv
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPFILE | awk '{print $1}')
if [ $N -gt $(expr $MAX - 1) ]; then
    MAXSMALL=$(expr $MAX - 1)
    echo "$N is too big, only $MAXSMALL lines in $SAMPFILE" 
    exit
fi

IFS=,
tail -n +2 $SAMPFILE | sed -n ${N}p | while read Species Strain Phyla Prefix BUSCO
do
 species=$(echo "$Species" | perl -p -e 'chomp; s/\s+/_/g')
 strain=$(echo "$Strain" | perl -p -e 'chomp; s/\s+/_/g')

 name=${species}_${strain}

 if [ ! -f $INDIR/${name}.fasta ]; then
     echo "Cannot find $name in $INDIR - may not have been run yet"
     exit
 fi

if [ ! -f $OUTDIR/${name}.masked.fasta ]; then

    module load funannotate/git-live
    module unload rmblastn
    module load ncbi-rmblast/2.6.0
    export AUGUSTUS_CONFIG_PATH=/bigdata/stajichlab/shared/pkg/augustus/3.3/config

    if [ -f repeat_library/${name}.repeatmodeler-library.fasta ]; then
	    # if this strain/pecies was already masked before w custom library
	    LIBRARY=repeat_library/${name}.repeatmodeler-library.fasta
    fi
    LIBRARY=$(realpath $LIBRARY)
    mkdir $name.mask.$SLURM_JOB_ID
    pushd $name.mask.$SLURM_JOB_ID
    funannotate mask --cpus $CPU -i ../$INDIR/${name}.fasta -o ../$OUTDIR/${name}.masked.fasta -l $LIBRARY
    mv funannotate-mask.log ../logs/${name}.funannotate-mask.log
    popd
    rmdir $name.mask.$SLURM_JOB_ID
else 
    echo "Skipping ${name} as masked already"
fi

done
