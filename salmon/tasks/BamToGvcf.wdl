version 1.0

# Local Import
import "https://kesselrunstorage.blob.core.windows.net/salmon/workflow/tasks/GermlineVariantDiscovery.wdl" as Calling
import "https://kesselrunstorage.blob.core.windows.net/salmon/workflow/tasks/Qc.wdl" as QC
import "https://kesselrunstorage.blob.core.windows.net/salmon/workflow/tasks/Utilities.wdl" as Utils

# Git URL Import
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/GermlineVariantDiscovery.wdl" as Calling
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/Qc.wdl" as QC
#import "https://raw.githubusercontent.com/microsoft/five-dollar-genome-analysis-pipeline-azure/az1.1.0/tasks/Utilities.wdl" as Utils

workflow BamToGvcf {

  input {
    File calling_interval_list
    File evaluation_interval_list
    Int break_bands_at_multiples_of
    Float? contamination
    File input_bam
    File input_bam_index
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    String base_file_name
    String final_gvcf_base_name
    Int agg_preemptible_tries
  }

  # Break the calling interval_list into sub-intervals
  # Perform variant calling on the sub-intervals, and then gather the results
  call Utils.ScatterIntervalList as ScatterIntervalList {
    input:
      interval_list = calling_interval_list,
      break_bands_at_multiples_of = break_bands_at_multiples_of
  }

  # We need disk to localize the sharded input and output due to the scatter for HaplotypeCaller.
  # If we take the number we are scattering by and reduce by 20 we will have enough disk space
  # to account for the fact that the data is quite uneven across the shards.
  Int potential_hc_divisor = ScatterIntervalList.interval_count - 20
  Int hc_divisor = if potential_hc_divisor > 1 then potential_hc_divisor else 1

  # Call variants in parallel over WGS calling intervals
  scatter (index in range(ScatterIntervalList.interval_count)) {
    # Generate GVCF by interval
    call Calling.HaplotypeCaller_GATK4_VCF as HaplotypeCaller {
      input:
        contamination = contamination,
        input_bam = input_bam,
        input_bam_index = input_bam_index,
        interval_list = ScatterIntervalList.out[index],
        vcf_basename = base_file_name,
        ref_dict = ref_dict,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        make_gvcf = true,
        preemptible_tries = agg_preemptible_tries
     }
  }

  # Combine by-interval GVCFs into a single sample GVCF file
  call Calling.MergeVCFs as MergeVCFs {
    input:
      input_vcfs = HaplotypeCaller.output_vcf,
      input_vcfs_indexes = HaplotypeCaller.output_vcf_index,
      output_vcf_name = final_gvcf_base_name + ".g.vcf.gz",
      preemptible_tries = agg_preemptible_tries
  }

  Float gvcf_size = size(MergeVCFs.output_vcf, "GB")

  # Validate the GVCF output of HaplotypeCaller
  call QC.ValidateGVCF as ValidateGVCF {
    input:
      input_vcf = MergeVCFs.output_vcf,
      input_vcf_index = MergeVCFs.output_vcf_index,
      ref_fasta = ref_fasta,
      ref_fasta_index = ref_fasta_index,
      ref_dict = ref_dict,
      calling_interval_list = calling_interval_list,
      preemptible_tries = agg_preemptible_tries
  }
}
