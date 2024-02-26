#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/riboseq
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/riboseq
    Website: https://nf-co.re/riboseq
    Slack  : https://nfcore.slack.com/channels/riboseq
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { RIBOSEQ                 } from './workflows/riboseq'
include { PREPARE_GENOME          } from './subworkflows/local/prepare_genome'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_riboseq_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_riboseq_pipeline'

include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_riboseq_pipeline'
include { checkMaxContigSize      } from './subworkflows/local/utils_nfcore_riboseq_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.fasta            = getGenomeAttribute('fasta')
params.transcript_fasta = getGenomeAttribute('transcript_fasta')
params.additional_fasta = getGenomeAttribute('additional_fasta')
params.gtf              = getGenomeAttribute('gtf')
params.gff              = getGenomeAttribute('gff')
params.gene_bed         = getGenomeAttribute('bed12')
params.bbsplit_index    = getGenomeAttribute('bbsplit')
params.star_index       = getGenomeAttribute('star')
params.hisat2_index     = getGenomeAttribute('hisat2')
params.rsem_index       = getGenomeAttribute('rsem')
params.salmon_index     = getGenomeAttribute('salmon')
params.sortmerna_index  = getGenomeAttribute('sortmerna')
params.kallisto_index   = getGenomeAttribute('kallisto')

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_RIBOSEQ {

    main:

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Prepare reference genome files
    //
    PREPARE_GENOME (
        params.fasta,
        params.gtf,
        params.gff,
        params.additional_fasta,
        params.transcript_fasta,
        params.gene_bed,
        params.splicesites,
        params.bbsplit_fasta_list,
        params.ribo_database_manifest,
        params.star_index,
        params.rsem_index,
        params.salmon_index,
        params.kallisto_index,
        params.hisat2_index,
        params.bbsplit_index,
        params.sortmerna_index,
        params.gencode,
        params.featurecounts_group_type,
        params.aligner,
        params.pseudo_aligner,
        params.skip_gtf_filter,
        params.skip_bbsplit,
        ! params.remove_ribo_rna,
        params.skip_alignment,
        params.skip_pseudo_alignment
    )
    ch_versions = ch_versions.mix(PREPARE_GENOME.out.versions)

    // Check if contigs in genome fasta file > 512 Mbp
    if (!params.skip_alignment && !params.bam_csi_index) {
        PREPARE_GENOME
            .out
            .fai
            .map { checkMaxContigSize(it) }
    }

    //
    // WORKFLOW: Run nf-core/riboseq workflow
    //
    ch_samplesheet = Channel.value(file(params.input, checkIfExists: true))
    RIBOSEQ (
        ch_samplesheet,
        ch_versions,
        PREPARE_GENOME.out.fasta,
        PREPARE_GENOME.out.gtf,
        PREPARE_GENOME.out.fai,
        PREPARE_GENOME.out.chrom_sizes,
        PREPARE_GENOME.out.gene_bed,
        PREPARE_GENOME.out.transcript_fasta,
        PREPARE_GENOME.out.star_index,
        PREPARE_GENOME.out.rsem_index,
        PREPARE_GENOME.out.hisat2_index,
        PREPARE_GENOME.out.salmon_index,
        PREPARE_GENOME.out.kallisto_index,
        PREPARE_GENOME.out.bbsplit_index,
        PREPARE_GENOME.out.sortmerna_index,
        PREPARE_GENOME.out.splicesites
    )
    ch_versions = ch_versions.mix(RIBOSEQ.out.versions)

    emit:
    multiqc_report = RIBOSEQ.out.multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions                // channel: [version1, version2, ...]


}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.help,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_RIBOSEQ ()

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_RIBOSEQ.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
