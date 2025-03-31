version 1.0

workflow plink2_prune_for_relatedness_testing {
    input {
        File pgen
        File pvar
        File psam
        File? keep_samples  # Optional file of sample IDs to retain
        String? out_prefix

        # Modifiable filtering parameters
        Float maf_threshold = 0.30                   # MAF ≥ 0.30
        Float geno_threshold = 0.001                  # Variant call rate ≥ 0.999 (i.e. missingness ≤ 0.001)
        Int max_alleles = 2                          # Only biallelic SNPs
        Int ld_window_bp = 150000                    # LD pruning window size in base pairs
        Int ld_step = 1                              # LD pruning step size
        Float ld_r2 = 0.00005                        # LD pruning r² threshold (very stringent)
    }

    call prune_for_relatedness_testing {
        input:
            pgen = pgen,
            pvar = pvar,
            psam = psam,
            keep_samples = keep_samples,
            out_prefix = out_prefix,
            maf_threshold = maf_threshold,
            geno_threshold = geno_threshold,
            max_alleles = max_alleles,
            ld_window_bp = ld_window_bp,
            ld_step = ld_step,
            ld_r2 = ld_r2
    }

    output {
        File out_bed = prune_for_relatedness_testing.out_bed
        File out_bim = prune_for_relatedness_testing.out_bim
        File out_fam = prune_for_relatedness_testing.out_fam
        Map[String, String] md5sum = prune_for_relatedness_testing.md5sum
    }

    meta {
        author: "Michael Betti"
        email: "michael.j.betti@vanderbilt.edu"
    }
}

task prune_for_relatedness_testing {
    input {
        File pgen
        File pvar
        File psam
        File? keep_samples
        String? out_prefix

        # Filter parameters
        Float maf_threshold
        Float geno_threshold
        Int max_alleles
        Int ld_window_bp
        Int ld_step
        Float ld_r2

        Int mem_gb = 16
    }

    Int disk_size = ceil(3 * (size(pgen, "GB") + size(pvar, "GB") + size(psam, "GB"))) + 10
    String out_string = if defined(out_prefix) then out_prefix else basename(pgen, ".pgen")

    command {
        # Step 1: LD pruning on high-quality SNPs
        plink2 \
            --pgen ~{pgen} --pvar ~{pvar} --psam ~{psam} \
            ~{if defined(keep_samples) then "--keep " + keep_samples else ""} \
            --maf ~{maf_threshold} \
            --geno ~{geno_threshold} \
            --max-alleles ~{max_alleles} \
            --indep-pairwise ~{ld_window_bp} ~{ld_step} ~{ld_r2} \
            --out pruned

        # Step 2: Extract pruned SNPs and output bed/bim/fam files
        plink2 \
            --pgen ~{pgen} --pvar ~{pvar} --psam ~{psam} \
            ~{if defined(keep_samples) then "--keep " + keep_samples else ""} \
            --extract pruned.prune.in \
            --make-bed \
            --out ${out_string}

        # Generate md5sums for output files
        md5sum ${out_string}.bed | cut -d " " -f 1 > md5_bed.txt
        md5sum ${out_string}.bim | cut -d " " -f 1 > md5_bim.txt
        md5sum ${out_string}.fam | cut -d " " -f 1 > md5_fam.txt
    }

    output {
        File out_bed = "${out_string}.bed"
        File out_bim = "${out_string}.bim"
        File out_fam = "${out_string}.fam"
        Map[String, String] md5sum = {
            "bed": read_string("md5_bed.txt"),
            "bim": read_string("md5_bim.txt"),
            "fam": read_string("md5_fam.txt")
        }
    }

    runtime {
        docker: "quay.io/biocontainers/plink2:2.00a5.10--h4ac6f70_0"
        disks: "local-disk " + disk_size + " SSD"
        memory: mem_gb + " GB"
    }
}