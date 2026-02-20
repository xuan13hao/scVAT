//
// Performs alignment and quantification for short-read (Illumina) single-cell RNA-seq data.
//
// Quantifier routing:
//   umitools_count  → QUANTIFY_SCRNA_SHORTREAD
//                     (featureCounts gene-tag → umi_tools dedup per-gene → umi_tools count)
//                     Correct for UMI-based short-read scRNA-seq (10x Genomics, etc.)
//
//   isoquant        → QUANTIFY_SCRNA_ISOQUANT  (long-read oriented; kept for compatibility)
//   oarfish         → QUANTIFY_SCRNA_OARFISH   (long-read oriented; kept for compatibility)
//

// SUBWORKFLOWS
include { ALIGN_SHORTREADS           } from '../../subworkflows/local/align_shortreads'
include { QUANTIFY_SCRNA_SHORTREAD   } from '../../subworkflows/local/quantify_scrna_shortread'
include { QUANTIFY_SCRNA_ISOQUANT    } from '../../subworkflows/local/quantify_scrna_isoquant'
include { QUANTIFY_SCRNA_OARFISH     } from '../../subworkflows/local/quantify_scrna_oarfish'

// MODULES
include { SAMTOOLS_FLAGSTAT as SAMTOOLS_FLAGSTAT_TAGGED } from '../../modules/nf-core/samtools/flagstat'
include { SAMTOOLS_INDEX    as SAMTOOLS_INDEX_TAGGED    } from '../../modules/nf-core/samtools/index'

include { TAG_BARCODES } from '../../modules/local/tag_barcodes'


workflow PROCESS_SHORTREAD_SCRNA {
    take:
        fasta                    // channel: [ val(meta), path(fasta) ]
        fai                      // channel: [ val(meta), path(fai) ]
        gtf                      // channel: [ val(meta), path(gtf) ]
        fastq_r1                 // channel: [ val(meta), path(fastq_r1) ] - R1: barcode+UMI
        fastq_r2                 // channel: [ val(meta), path(fastq_r2) ] - R2: cDNA (aligned)
        rseqc_bed                // channel: [ val(meta), path(rseqc_bed) ]
        whitelist                // channel: [ val(meta), path(whitelist) ]
        quant_list               // list: quantifiers to run
        dedup_tool               // str: dedup tool (always 'umitools' for short-read)
        genome_aligned           // bool: genome vs transcriptome alignment
        fasta_delimiter          // str: delimiter in FASTA sequence IDs

        skip_save_minimap2_index // bool
        skip_qc                  // bool
        skip_rseqc               // bool
        skip_bam_nanocomp        // bool
        skip_seurat              // bool
        skip_dedup               // bool (must be false for short-read; included for interface parity)

    main:
        ch_versions = Channel.empty()

        //
        // SUBWORKFLOW: Align R2 (cDNA) reads with VAT
        //   R1 was processed upstream by umi_tools extract, which encoded
        //   the cell barcode and UMI into the R2 read name as:
        //     @<original_id>_<BARCODE>_<UMI>
        //   R2 (with modified headers) is passed here for alignment.
        //
        alignment_mode = genome_aligned ? 'wgs' : 'splice'

        ALIGN_SHORTREADS(
            fasta,
            fai,
            gtf,
            fastq_r2,
            rseqc_bed,
            skip_save_minimap2_index,
            skip_qc,
            skip_rseqc,
            skip_bam_nanocomp,
            alignment_mode,
            false   // long_read_mode: always false for short reads
        )
        ch_versions = ch_versions.mix(ALIGN_SHORTREADS.out.versions)

        //
        // MODULE: Transfer cell barcode + UMI from read name into BAM tags
        //   Adds CB (corrected barcode), UB (corrected UMI) BAM tags.
        //   Uses Hamming-distance ≤ 1 correction against the whitelist.
        //
        TAG_BARCODES(
            ALIGN_SHORTREADS.out.sorted_bam
                .join(ALIGN_SHORTREADS.out.sorted_bai, by: 0),
            whitelist.map { it[1] },
            true    // extract_from_readid: true for short-read
        )
        ch_versions = ch_versions.mix(TAG_BARCODES.out.versions)

        //
        // MODULE: Index and QC-stat the CB/UB-tagged BAM
        //
        SAMTOOLS_INDEX_TAGGED( TAG_BARCODES.out.tagged_bam )
        ch_versions = ch_versions.mix(SAMTOOLS_INDEX_TAGGED.out.versions)

        SAMTOOLS_FLAGSTAT_TAGGED(
            TAG_BARCODES.out.tagged_bam
                .join(SAMTOOLS_INDEX_TAGGED.out.bai, by: [0])
        )
        ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT_TAGGED.out.versions)

        // ── Quantification outputs ──────────────────────────────────────────
        ch_bam              = Channel.empty()
        ch_bai              = Channel.empty()
        ch_flagstat         = Channel.empty()
        ch_idxstats         = Channel.empty()
        ch_gene_qc_stats    = Channel.empty()
        ch_transcript_qc_stats = Channel.empty()
        ch_count_tsv        = Channel.empty()
        ch_count_mtx_dir    = Channel.empty()

        // ──────────────────────────────────────────────────────────────────
        // PATH A: umitools_count — correct short-read UMI dedup + counting
        //
        //   featureCounts (XT gene tag)
        //     → coordinate sort
        //     → umi_tools dedup --per-gene --per-cell
        //     → umi_tools count  (cell × gene matrix)
        //
        // This is the only path that performs dedup AFTER gene assignment,
        // which is mandatory for correct UMI counting in scRNA-seq.
        // ──────────────────────────────────────────────────────────────────
        if (quant_list.contains("umitools_count")) {
            QUANTIFY_SCRNA_SHORTREAD(
                TAG_BARCODES.out.tagged_bam,
                SAMTOOLS_INDEX_TAGGED.out.bai,
                SAMTOOLS_FLAGSTAT_TAGGED.out.flagstat,
                gtf,
                skip_qc,
                skip_seurat
            )
            ch_versions         = ch_versions.mix(QUANTIFY_SCRNA_SHORTREAD.out.versions)
            ch_bam              = QUANTIFY_SCRNA_SHORTREAD.out.dedup_bam
            ch_bai              = QUANTIFY_SCRNA_SHORTREAD.out.dedup_bai
            ch_flagstat         = QUANTIFY_SCRNA_SHORTREAD.out.dedup_flagstat
            ch_idxstats         = QUANTIFY_SCRNA_SHORTREAD.out.dedup_idxstats
            ch_gene_qc_stats    = QUANTIFY_SCRNA_SHORTREAD.out.gene_qc_stats
            ch_count_tsv        = QUANTIFY_SCRNA_SHORTREAD.out.count_tsv
            ch_count_mtx_dir    = QUANTIFY_SCRNA_SHORTREAD.out.count_mtx_dir
        }

        // ──────────────────────────────────────────────────────────────────
        // PATH B / C: isoquant / oarfish — legacy paths kept for
        // compatibility (long-read oriented; not recommended for short reads)
        // ──────────────────────────────────────────────────────────────────
        if (quant_list.contains("oarfish")) {
            QUANTIFY_SCRNA_OARFISH(
                ch_bam.ifEmpty(TAG_BARCODES.out.tagged_bam),
                ch_bai.ifEmpty(SAMTOOLS_INDEX_TAGGED.out.bai),
                ch_flagstat.ifEmpty(SAMTOOLS_FLAGSTAT_TAGGED.out.flagstat),
                fasta,
                skip_qc,
                skip_seurat
            )
            ch_versions            = ch_versions.mix(QUANTIFY_SCRNA_OARFISH.out.versions)
            ch_transcript_qc_stats = QUANTIFY_SCRNA_OARFISH.out.transcript_qc_stats
        }

        if (quant_list.contains("isoquant")) {
            QUANTIFY_SCRNA_ISOQUANT(
                ch_bam.ifEmpty(TAG_BARCODES.out.tagged_bam),
                ch_bai.ifEmpty(SAMTOOLS_INDEX_TAGGED.out.bai),
                ch_flagstat.ifEmpty(SAMTOOLS_FLAGSTAT_TAGGED.out.flagstat),
                fasta,
                fai,
                gtf,
                skip_qc,
                skip_seurat
            )
            ch_versions         = ch_versions.mix(QUANTIFY_SCRNA_ISOQUANT.out.versions)
            ch_gene_qc_stats    = QUANTIFY_SCRNA_ISOQUANT.out.gene_qc_stats
            ch_transcript_qc_stats = QUANTIFY_SCRNA_ISOQUANT.out.transcript_qc_stats
        }

    emit:
        versions = ch_versions

        // VAT alignment QC
        minimap_bam              = ALIGN_SHORTREADS.out.sorted_bam
        minimap_bai              = ALIGN_SHORTREADS.out.sorted_bai
        minimap_stats            = ALIGN_SHORTREADS.out.stats
        minimap_flagstat         = ALIGN_SHORTREADS.out.flagstat
        minimap_idxstats         = ALIGN_SHORTREADS.out.idxstats
        minimap_rseqc_read_dist  = ALIGN_SHORTREADS.out.rseqc_read_dist
        minimap_nanocomp_bam_txt = ALIGN_SHORTREADS.out.nanocomp_bam_txt

        // Post-tagging QC
        bc_tagged_bam            = TAG_BARCODES.out.tagged_bam
        bc_tagged_bai            = SAMTOOLS_INDEX_TAGGED.out.bai
        bc_tagged_flagstat       = SAMTOOLS_FLAGSTAT_TAGGED.out.flagstat

        // Post-dedup BAM and QC
        dedup_bam                = ch_bam
        dedup_bai                = ch_bai
        dedup_flagstat           = ch_flagstat
        dedup_idxstats           = ch_idxstats

        // Count matrices (umitools_count path)
        count_tsv                = ch_count_tsv
        count_mtx_dir            = ch_count_mtx_dir

        // Seurat QC (empty unless long-read quantifiers are used)
        gene_qc_stats            = ch_gene_qc_stats
        transcript_qc_stats      = ch_transcript_qc_stats
}
