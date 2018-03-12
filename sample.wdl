import "library.wdl" as libraryWorkflow
import "tasks/biopet.wdl" as biopet
import "bam-to-gvcf/gvcf.wdl" as gvcf

workflow sample {
    Array[File] sampleConfigs
    String sampleId
    File sampleConfigJar
    String outputDir
    File ref_fasta
    File ref_dict
    File ref_fasta_index

    call biopet.SampleConfig as librariesConfigs {
        input:
            tool_jar = sampleConfigJar,
            inputFiles = sampleConfigs,
            sample = sampleId,
            jsonOutputPath = sampleId + ".config.json",
            tsvOutputPath = sampleId + ".config.tsv"
    }

    scatter (lb in librariesConfigs.keys) {
        if (lb != "") {
            call libraryWorkflow.library as library {
                input:
                    outputDir = outputDir + "/lib_" + lb,
                    sampleConfigJar = sampleConfigJar,
                    sampleConfigs = select_all([librariesConfigs.jsonOutput]),
                    libraryId = lb,
                    sampleId = sampleId,
                    ref_fasta = ref_fasta,
                    ref_dict = ref_dict,
                    ref_fasta_index = ref_fasta_index
            }
        }
    }

    call gvcf.Gvcf as createGvcf {
        input:
            ref_fasta = ref_fasta,
            ref_dict = ref_dict,
            ref_fasta_index = ref_fasta_index,
            bamFiles = select_all(library.bqsrBamFile),
            bamIndexes = select_all(library.bqsrBamIndexFile),
            gvcf_basename = outputDir + "/" + sampleId + ".g"
    }

    output {
        File gvcf = createGvcf.output_gvcf
        File gvcf_index = createGvcf.output_gvcf_index
        Array[String] libraries = librariesConfigs.keys
    }
}