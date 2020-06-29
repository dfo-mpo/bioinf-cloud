version 1.0

struct SampleAndUnmappedBams {
  String base_file_name
  String final_gvcf_base_name
  Array[File] flowcell_unmapped_bams
  String sample_name
  String unmapped_bam_suffix
}

struct ReferenceFasta {
  File ref_dict
  File ref_fasta
  File ref_fasta_index
}

struct GermlineSingleSampleReferences {
  File contamination_sites_ud
  File contamination_sites_bed
  File contamination_sites_mu
  File calling_interval_list

  Int break_bands_at_multiples_of

  ReferenceFasta reference_fasta

  File evaluation_interval_list
}

struct PapiSettings {
  Int preemptible_tries
  Int agg_preemptible_tries
}
