# Germline alignment and variant calling pipeline on Azure
This repository is an example of running the germline alignment and variant calling pipeline, based on [Best Practices Genome Analysis Pipeline by Broad Institute of MIT and Harvard](https://software.broadinstitute.org/gatk/best-practices/workflow?id=11165), on Cromwell on Azure.<br/> 

# Validating
```
wget https://github.com/broadinstitute/cromwell/releases/download/51/womtool-51.jar
java -jar womtool-51.jar /path/to/WholeGenomeGermlineSingleSample.wdl
```

### LICENSING :
Copyright Broad Institute, 2019 | BSD-3
This script is released under the WDL open source code license (BSD-3) (full license text at https://github.com/openwdl/wdl/blob/master/LICENSE). Note however that the programs it calls may be subject to different licenses. Users are responsible for checking that they are authorized to run all programs before running this script.
- [GATK](https://software.broadinstitute.org/gatk/download/licensing.php)
- [BWA](http://bio-bwa.sourceforge.net/bwa.shtml#13)
- [Picard](https://broadinstitute.github.io/picard/)
- [Samtools](http://www.htslib.org/terms/)
