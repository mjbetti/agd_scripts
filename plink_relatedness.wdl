version 1.0

import "https://raw.githubusercontent.com/shengqh/warp/develop/tasks/vumc_biostatistics/GcpUtils.wdl" as http_GcpUtils
import "https://raw.githubusercontent.com/shengqh/warp/develop/pipelines/vumc_biostatistics/genotype/Utils.wdl" as http_GenotypeUtils
import "https://raw.githubusercontent.com/shengqh/warp/develop/pipelines/vumc_biostatistics/agd/AgdUtils.wdl" as http_AgdUtils

task HailPLINKRelatedness {
    input {
        String sample_name
        File genotype_data   # Input genotype data (VCF or Hail MatrixTable)
        String output_prefix # Prefix for output files
        String reference_genome = "GRCh38" # Default reference genome
        String genotype_data_type = "mt"   # "mt" for MatrixTable or "vcf" for VCF file
    }

    command <<<
        set -e

        # Create a temporary Python script to run the Hail code
        cat > run_hail.py << 'EOF'
        import hail as hl

        # Initialize Hail
        hl.init(default_reference='${reference_genome}')

        # Import genotype data
        if '${genotype_data_type}' == 'vcf':
            mt = hl.import_vcf('${genotype_data}')
        elif '${genotype_data_type}' == 'mt':
            mt = hl.read_matrix_table('${genotype_data}')
        else:
            raise ValueError('Invalid genotype data type: ${genotype_data_type}')

        # Run identity_by_descent
        ibd = hl.identity_by_descent(mt)

        # Export the results
        ibd.write('${output_prefix}_relatedness.ht', overwrite=True)
        ibd_df = ibd.to_pandas()
        ibd_df.to_csv('${output_prefix}_relatedness.tsv', sep='\t', index=False)
        EOF

        # Run the Python script
        python run_hail.py
    >>>

    runtime {
        docker: "hailgenetics/hail:latest"  # Use the latest Hail Docker image
        memory: "16G"
        cpu: "4"
    }

    output {
        File relatedness_ht = "${output_prefix}_relatedness.ht"
        File relatedness_tsv = "${output_prefix}_relatedness.tsv"
    }
}

workflow RelatednessWorkflow {
    input {
        String sample_name
        File genotype_data
        String genotype_data_type = "mt"    # Default to Hail MatrixTable
        String reference_genome = "GRCh38"  # Default reference genome
    }

    call HailPLINKRelatedness {
        input:
            sample_name = sample_name,
            genotype_data = genotype_data,
            genotype_data_type = genotype_data_type,
            output_prefix = sample_name,
            reference_genome = reference_genome
    }

    output {
        File relatedness_ht = HailPLINKRelatedness.relatedness_ht
        File relatedness_tsv = HailPLINKRelatedness.relatedness_tsv
    }
}