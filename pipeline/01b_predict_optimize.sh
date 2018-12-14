#!/bin/bash
#SBATCH -p batch --time 2-0:00:00 --ntasks 16 --nodes 1 --mem 24G --out logs/predict.%a.log
module unload python
module unload perl
module unload perl
module load perl/5.24.0
module load miniconda2
module load funannotate/git-live
module switch mummer/4.0
module unload augustus
module load augustus/3.3
module load lp_solve
module load genemarkHMM
module load diamond
module unload rmblastn
module load ncbi-rmblast/2.6.0
export AUGUSTUS_CONFIG_PATH=/bigdata/stajichlab/shared/pkg/augustus/3.3/config
#TEMP=/scratch/$USER
#mkdir -p $TEMP
if [ -z $SLURM_JOB_ID ]; then
	SLURM_JOB_ID=$$
fi
CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=genomes
OUTDIR=annotate
BUSCO_DIR=/srv/projects/db/BUSCO/v9

SAMPFILE=genomes.csv
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=`wc -l $SAMPFILE | awk '{print $1}'`

if [ "$N" -gt "$MAX" ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi
IFS=,
tail -n +2 $SAMPFILE | sed -n ${N}p | while read Species Strain Phyla SubPhyla Prefix Transcripts BUSCO
do
 species=$(echo "$Species" | perl -p -e 'chomp; s/\s+/_/g')
 strain=$(echo "$Strain" | perl -p -e 'chomp; s/\s+/_/g')

 name=${species}_${strain}
 SEED_SPECIES="anidulans"
	if [[ $SubPhyla == "Mucoromycotina" ]]; then
		SEED_SPECIES="mucor_circinelloides_f._lusitanicus__nrrl_3629"
	elif [[ $SubPhyla == "Mortirellomycotina" ]]; then
		SEED_SPECIES="Mortierella_verticillata_CRF"
	elif [[ $SubPhyla == "Entomophthoromycotina" ]]; then
		SEED_SPECIES="Conidiobolus_coronatus"
	elif [[ $SubPhyla == "Kickxellomycotina" ]]; then
		SEED_SPECIES="coemansia_umbellata__bcrc_34882"
	fi
	if [ ! -f $INDIR/$name.masked.fasta ]; then
		echo "No genome for $INDIR/$name.masked.fasta yet - run 00_mash.sh $N"
		exit
	fi
	IN=$(realpath $INDIR/$name.masked.fasta)
	OUT=$(realpath $OUTDIR/$name)
	PEPFILE=$(realpath lib/informant_proteins.aa)
	
	if [ ! -z "$Transcripts" ]; then
		Transcripts=$(realpath lib/$Transcripts)
	fi
 	mkdir $name.predict.$SLURM_JOB_ID
 	pushd $name.predict.$SLURM_JOB_ID
	ln -s $BUSO_DIR/$BUSCO ./$BUSCO
	if [ ! -z "$Transcripts" ]; then
    		funannotate predict --cpus $CPU --keep_no_stops --SeqCenter UCR --busco_db $BUSCO --strain "$strain" \
      		-i $IN --name $Prefix --protein_evidence $PEPFILE --transcript_evidence $Transcripts \
      		-s "$Species"  -o $OUT --busco_seed_species $SEED_SPECIES --optimize_augustus
	else
               funannotate predict --cpus $CPU --keep_no_stops --SeqCenter UCR --busco_db $BUSCO --strain "$strain" \
                -i $IN --name $Prefix --protein_evidence $PEPFILE \
                -s "$Species"  -o $OUT --busco_seed_species $SEED_SPECIES --optimize_augustus
	fi
	rm fungi_odb9
	popd
 	rmdir $name.predict.$SLURM_JOB_ID
done
