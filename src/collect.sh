#!/bin/bash

if [ $# -ne 3 ]; then
    echo 1>&2 "Usage: $0 seed num_pair_end num_mate_pairs"
    exit 3
fi

RANDOM_SEED=$1
num_pair_end=$2
num_mate_pairs=$3

time {
    echo '> Creating symbolic links to sources...'
    {
        ln -s /usr/share/data-minor-bioinf/assembly/oil_R1.fastq
        ln -s /usr/share/data-minor-bioinf/assembly/oil_R2.fastq
        ln -s /usr/share/data-minor-bioinf/assembly/oilMP_S4_L001_R2_001.fastq
        ln -s /usr/share/data-minor-bioinf/assembly/oilMP_S4_L001_R1_001.fastq
    } &> /dev/null

    echo '> Creating random samples...'
    {
        seqtk sample -s$RANDOM_SEED oil_R1.fastq $num_pair_end > sub1.fastq
        seqtk sample -s$RANDOM_SEED oil_R2.fastq $num_pair_end > sub2.fastq
        seqtk sample -s$RANDOM_SEED oilMP_S4_L001_R1_001.fastq $num_mate_pairs > matepairs1.fastq
        seqtk sample -s$RANDOM_SEED oilMP_S4_L001_R2_001.fastq $num_mate_pairs > matepairs2.fastq
    } &> /dev/null

    echo '> Evaluating readings using fastQC and multiQC...'
    {
        rm -rf fastqc
        mkdir fastqc
        ls sub* matepairs* | xargs -tI{} fastqc -o fastqc {}
        rm -rf multiqc
        mkdir multiqc
        multiqc -o multiqc fastqc
    } &> /dev/null

    echo '> Trimming readings...'
    {
        platanus_trim sub*
        platanus_internal_trim matepair*
    } &> /dev/null

    echo '> Removing old readings'
    {
        rm sub1.fastq
        rm sub2.fastq
        rm matepairs1.fastq
        rm matepairs2.fastq
    } &> /dev/null

    echo '> Evaluating trimmed readings using fastQC and multiQC...'
    {
        rm -rf fastqc_trim
        mkdir fastqc_trim
        ls sub* matepairs*| xargs -tI{} fastqc -o fastqc_trim {}
        rm -rf multiqc_trim
        mkdir multiqc_trim
        multiqc -o multiqc_trim fastqc_trim
    } &> /dev/null

    echo '> Collecting contigs...'
    {
        time platanus assemble -o Poil -f sub1.fastq.trimmed sub2.fastq.trimmed 2> assemble.log
    } &> /dev/null

    echo '> Collecting scaffolds...'
    {
        time platanus scaffold -o Poil -c Poil_contig.fa -IP1 sub1.fastq.trimmed sub2.fastq.trimmed -OP2 matepairs1.fastq.int_trimmed matepairs2.fastq.int_trimmed 2> scaffold.log
    } &> /dev/null

    echo '> Gap closing...'
    {
        time platanus gap_close -o Poil -c Poil_scaffold.fa -IP1 sub1.fastq.trimmed sub2.fastq.trimmed -OP2 matepairs1.fastq.int_trimmed  matepairs2.fastq.int_trimmed 2> gapclose.log
    } &> /dev/null

    echo '> Removing trimmed readings...'
    {
        rm *trimmed

        rm -rf platanus
        mkdir platanus 
        mv Poil* platanus/
        mv *.log platanus/
    } &> /dev/null

    echo '> DONE!'
}