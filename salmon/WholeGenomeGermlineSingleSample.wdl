version 1.0

## Copyright Broad Institute, 2018
##
## This WDL pipeline implements data pre-processing and initial variant calling (GVCF
## generation) according to the GATK Best Practices (June 2016) for germline SNP and
## Indel discovery in human whole-genome data.
##
## Requirements/expectations :
## - Human whole-genome pair-end sequencing data in unmapped BAM (uBAM) format
## - One or more read groups, one per uBAM file, all belonging to a single sample (SM)
## - Input uBAM files must additionally comply with the following requirements:
## - - filenames all have the same suffix (we use ".unmapped.bam")
## - - files must pass validation by ValidateSamFile
## - - reads are provided in query-sorted order
## - - all reads must have an RG tag
## - GVCF output names must end in ".g.vcf.gz"
## - Reference genome must be Hg38 with ALT contigs
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation.
## For program versions, see docker containers.
##
## LICENSING :
## This script is released under the WDL source code license (BSD-3) (see LICENSE in
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the docker
## page at https://hub.docker.com/r/broadinstitute/genomes-in-the-cloud/ for detailed
## licensing information pertaining to the included programs.

# Local import
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/UnmappedBamToAlignedBam.wdl" as ToBam
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/AggregatedBamQC.wdl" as AggregatedQC
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/GermlineVariantDiscovery.wdl" as Calling
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/Qc.wdl" as QC
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/Utilities.wdl" as Utils
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/BamToCram.wdl" as ToCram
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/tasks/BamToGvcf.wdl" as ToGvcf
import "https://raw.githubusercontent.com/dfo-mpo/bioinf-cloud/master/salmon/structs/GermlineStructs.wdl"

# Git URL import
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/UnmappedBamToAlignedBam.wdl" as ToBam
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/AggregatedBamQC.wdl" as AggregatedQC
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/GermlineVariantDiscovery.wdl" as Calling
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/Qc.wdl" as QC
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/Utilities.wdl" as Utils
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/BamToCram.wdl" as ToCram
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/BamToGvcf.wdl" as ToGvcf
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/structs/GermlineStructs.wdl"

# WORKFLOW DEFINITION
workflow WholeGenomeGermlineSingleSample {
  input {
    SampleAndUnmappedBams sample_and_unmapped_bams
    GermlineSingleSampleReferences references
    PapiSettings papi_settings
    File wgs_coverage_interval_list
  }

  # Not overridable:
  Int read_length = 150
  Float lod_threshold = -20.0
  String cross_check_fingerprints_by = "READGROUP"

  call ToBam.UnmappedBamToAlignedBam {
    input:
      sample_and_unmapped_bams    = sample_and_unmapped_bams,
      references                  = references,
      papi_settings               = papi_settings,
      lod_threshold               = lod_threshold
  }


  call ToCram.BamToCram as BamToCram {
    input:
      input_bam = UnmappedBamToAlignedBam.output_bam,
      ref_fasta = references.reference_fasta.ref_fasta,
      ref_fasta_index = references.reference_fasta.ref_fasta_index,
      ref_dict = references.reference_fasta.ref_dict,
      duplication_metrics = UnmappedBamToAlignedBam.duplicate_metrics,
      chimerism_metrics = AggregatedBamQC.agg_alignment_summary_metrics,
      base_file_name = sample_and_unmapped_bams.base_file_name,
      agg_preemptible_tries = papi_settings.agg_preemptible_tries
  }

  # QC the sample WGS metrics (stringent thresholds)
  call QC.CollectWgsMetrics as CollectWgsMetrics {
    input:
      input_bam = UnmappedBamToAlignedBam.output_bam,
      input_bam_index = UnmappedBamToAlignedBam.output_bam_index,
      metrics_filename = sample_and_unmapped_bams.base_file_name + ".wgs_metrics",
      ref_fasta = references.reference_fasta.ref_fasta,
      ref_fasta_index = references.reference_fasta.ref_fasta_index,
      wgs_coverage_interval_list = wgs_coverage_interval_list,
      read_length = read_length,
      preemptible_tries = papi_settings.agg_preemptible_tries
  }

  # QC the sample raw WGS metrics (common thresholds)
  call QC.CollectRawWgsMetrics as CollectRawWgsMetrics {
    input:
      input_bam = UnmappedBamToAlignedBam.output_bam,
      input_bam_index = UnmappedBamToAlignedBam.output_bam_index,
      metrics_filename = sample_and_unmapped_bams.base_file_name + ".raw_wgs_metrics",
      ref_fasta = references.reference_fasta.ref_fasta,
      ref_fasta_index = references.reference_fasta.ref_fasta_index,
      wgs_coverage_interval_list = wgs_coverage_interval_list,
      read_length = read_length,
      preemptible_tries = papi_settings.agg_preemptible_tries
  }

  call ToGvcf.BamToGvcf as BamToGvcf {
    input:
      calling_interval_list = references.calling_interval_list,
      evaluation_interval_list = references.evaluation_interval_list,
      break_bands_at_multiples_of = references.break_bands_at_multiples_of,
      contamination = UnmappedBamToAlignedBam.contamination,
      input_bam = UnmappedBamToAlignedBam.output_bam,
      input_bam_index = UnmappedBamToAlignedBam.output_bam_index,
      ref_fasta = references.reference_fasta.ref_fasta,
      ref_fasta_index = references.reference_fasta.ref_fasta_index,
      ref_dict = references.reference_fasta.ref_dict,
      base_file_name = sample_and_unmapped_bams.base_file_name,
      final_gvcf_base_name = sample_and_unmapped_bams.final_gvcf_base_name,
      agg_preemptible_tries = papi_settings.agg_preemptible_tries
  }

  # Outputs that will be retained when execution is complete
  output {
    Array[File] quality_yield_metrics = UnmappedBamToAlignedBam.quality_yield_metrics

    Array[File] unsorted_read_group_base_distribution_by_cycle_pdf = UnmappedBamToAlignedBam.unsorted_read_group_base_distribution_by_cycle_pdf
    Array[File] unsorted_read_group_base_distribution_by_cycle_metrics = UnmappedBamToAlignedBam.unsorted_read_group_base_distribution_by_cycle_metrics
    Array[File] unsorted_read_group_insert_size_histogram_pdf = UnmappedBamToAlignedBam.unsorted_read_group_insert_size_histogram_pdf
    Array[File] unsorted_read_group_insert_size_metrics = UnmappedBamToAlignedBam.unsorted_read_group_insert_size_metrics
    Array[File] unsorted_read_group_quality_by_cycle_pdf = UnmappedBamToAlignedBam.unsorted_read_group_quality_by_cycle_pdf
    Array[File] unsorted_read_group_quality_by_cycle_metrics = UnmappedBamToAlignedBam.unsorted_read_group_quality_by_cycle_metrics
    Array[File] unsorted_read_group_quality_distribution_pdf = UnmappedBamToAlignedBam.unsorted_read_group_quality_distribution_pdf
    Array[File] unsorted_read_group_quality_distribution_metrics = UnmappedBamToAlignedBam.unsorted_read_group_quality_distribution_metrics

    File selfSM = UnmappedBamToAlignedBam.selfSM
    Float contamination = UnmappedBamToAlignedBam.contamination

    File wgs_metrics = CollectWgsMetrics.metrics
    File raw_wgs_metrics = CollectRawWgsMetrics.metrics

    File duplicate_metrics = UnmappedBamToAlignedBam.duplicate_metrics

    File gvcf_summary_metrics = BamToGvcf.gvcf_summary_metrics
    File gvcf_detail_metrics = BamToGvcf.gvcf_detail_metrics

    File output_cram = BamToCram.output_cram
    File output_cram_index = BamToCram.output_cram_index
    File output_cram_md5 = BamToCram.output_cram_md5

    File validate_cram_file_report = BamToCram.validate_cram_file_report

    File output_vcf = BamToGvcf.output_vcf
    File output_vcf_index = BamToGvcf.output_vcf_index
  }
}