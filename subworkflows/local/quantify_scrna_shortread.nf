//
// Short-read UMI scRNA-seq quantification:
//   1. featureCounts  – assigns each aligned read a gene (XT BAM tag)
//   2. SAMTOOLS_SORT  – coordinate-sorts the gene-annotated BAM
//   3. UMITOOLS_DEDUP – deduplicates per cell (CB) + per gene (XT)
//   4. UMITOOLS_COUNT – counts UMIs per cell × gene → TSV + MEX matrix
//
// NOTE: TAG_BARCODES must have been run upstream so that every read
// carries CB (corrected cell barcode) and UB (corrected UMI) BAM tags.
// Deduplication is intentionally placed AFTER gene assignment so that
// reads are collapsed within each (cell, gene) group rather than by
// genomic coordinate alone – the correct approach for UMI-based scRNA-seq.
//

include { FEATURECOUNTS                                               } from '../../modules/local/featurecounts'
include { UMITOOLS_DEDUP                                              } from '../../modules/nf-core/umitools/dedup/main'
include { UMITOOLS_COUNT                                              } from '../../modules/local/umitools_count'
include { SAMTOOLS_SORT                                               } from '../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX  as SAMTOOLS_INDEX_ANNOT                    } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_INDEX  as SAMTOOLS_INDEX_DEDUP                    } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_FLAGSTAT as SAMTOOLS_FLAGSTAT_DEDUP               } from '../../modules/nf-core/samtools/flagstat/main'
include { SAMTOOLS_IDXSTATS as SAMTOOLS_IDXSTATS_DEDUP               } from '../../modules/nf-core/samtools/idxstats/main'


workflow QUANTIFY_SCRNA_SHORTREAD {
    take:
        in_bam      // channel: [ val(meta), path(bam) ]
        in_bai      // channel: [ val(meta), path(bai) ]
        in_flagstat // channel: [ val(meta), path(flagstat) ]  (pre-dedup, for QC passthrough)
        in_gtf      // channel: [ val(meta2), path(gtf) ]
        skip_qc     // bool: skip downstream QC modules
        skip_seurat // bool: skip seurat (always true for short-read currently)

    main:
        ch_versions = Channel.empty()

        //
        // MODULE: Assign reads to genes using featureCounts
        //   Adds XT (gene id) and XS (assignment status) BAM tags.
        //   Prerequisite: BAM must already carry CB and UB tags from TAG_BARCODES.
        //
        FEATURECOUNTS(
            in_bam,
            in_gtf.map { it[1] }.first()    // broadcast single GTF path to all samples
        )
        ch_versions = ch_versions.mix(FEATURECOUNTS.out.versions)

        //
        // MODULE: Coordinate-sort the gene-annotated BAM
        //   umi_tools dedup --per-gene requires a coordinate-sorted BAM.
        //
        SAMTOOLS_SORT(
            FEATURECOUNTS.out.bam,
            Channel.value([ [:], [] ])   // no FASTA reference needed for coordinate sort
        )
        ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

        // Index the sorted annotated BAM
        SAMTOOLS_INDEX_ANNOT( SAMTOOLS_SORT.out.bam )
        ch_versions = ch_versions.mix(SAMTOOLS_INDEX_ANNOT.out.versions)

        //
        // MODULE: UMI deduplication per cell + per gene
        //   --per-gene --gene-tag=XT  groups reads by gene before dedup
        //   --per-cell --cell-tag=CB  separates dedup per cell barcode
        //   --umi-tag=UB              uses the UMI from the UB tag
        //
        //   Force meta.single_end=true: the BAM contains only R2 reads
        //   (R1 was used for barcode/UMI extraction only), so the alignment
        //   is effectively single-end regardless of the original library type.
        //
        ch_for_dedup = SAMTOOLS_SORT.out.bam
            .join(SAMTOOLS_INDEX_ANNOT.out.bai, by: [0])
            .map { meta, bam, bai -> [ meta + [single_end: true], bam, bai ] }

        UMITOOLS_DEDUP( ch_for_dedup, false )
        ch_versions = ch_versions.mix(UMITOOLS_DEDUP.out.versions)

        // Index the deduplicated BAM
        SAMTOOLS_INDEX_DEDUP( UMITOOLS_DEDUP.out.bam )
        ch_versions = ch_versions.mix(SAMTOOLS_INDEX_DEDUP.out.versions)

        ch_dedup_bam_bai = UMITOOLS_DEDUP.out.bam
            .join(SAMTOOLS_INDEX_DEDUP.out.bai, by: [0])

        //
        // MODULE: QC stats on deduplicated BAM
        //
        SAMTOOLS_FLAGSTAT_DEDUP( ch_dedup_bam_bai )
        ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT_DEDUP.out.versions)

        SAMTOOLS_IDXSTATS_DEDUP( ch_dedup_bam_bai )
        ch_versions = ch_versions.mix(SAMTOOLS_IDXSTATS_DEDUP.out.versions)

        //
        // MODULE: Generate count matrix (cells × genes)
        //   umi_tools count reads XT (gene), CB (cell), UB (UMI) tags from
        //   the deduplicated BAM and emits both a long-format TSV and a
        //   MEX (Matrix Market) directory compatible with Seurat / scanpy.
        //
        UMITOOLS_COUNT( ch_dedup_bam_bai )
        ch_versions = ch_versions.mix(UMITOOLS_COUNT.out.versions)

    emit:
        versions            = ch_versions

        // Count matrix outputs
        count_tsv           = UMITOOLS_COUNT.out.counts
        count_mtx_dir       = UMITOOLS_COUNT.out.mtx_dir

        // Deduplicated BAM
        dedup_bam           = UMITOOLS_DEDUP.out.bam
        dedup_bai           = SAMTOOLS_INDEX_DEDUP.out.bai
        dedup_flagstat      = SAMTOOLS_FLAGSTAT_DEDUP.out.flagstat
        dedup_idxstats      = SAMTOOLS_IDXSTATS_DEDUP.out.idxstats
        dedup_log           = UMITOOLS_DEDUP.out.log

        // featureCounts QC
        featurecounts_summary = FEATURECOUNTS.out.summary

        // Empty channels (no Seurat QC in short-read mode currently)
        gene_qc_stats       = Channel.empty()
        transcript_qc_stats = Channel.empty()
}
