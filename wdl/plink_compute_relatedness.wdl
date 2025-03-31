version 1.0

workflow plink_compute_relatedness {
    input {
        File bed
        File bim
        File fam
        File? keep_samples        # Optional file of sample IDs to retain
        String? out_prefix        # Optional output prefix
        Int? disk_size            # Optional disk size
    }

    call compute_relatedness {
        input:
            bed = bed,
            bim = bim,
            fam = fam,
            keep_samples = keep_samples,
            out_prefix = out_prefix,
            disk_size = select_first([disk_size, ceil(size(bed, "GB") + size(bim, "GB") + size(fam, "GB")) + 10])
    }

    output {
        File relatedness_genome = compute_relatedness.genome_file
        Map[String, String] md5sum = compute_relatedness.md5sum
    }

    meta {
        author: "Michael Betti"
        email: "michael.j.betti@vanderbilt.edu"
    }
}

task compute_relatedness {
    input {
        File bed
        File bim
        File fam
        File? keep_samples
        String? out_prefix
        Int mem_gb = 64
        Int disk_size
    }

    String out_string = if defined(out_prefix) then out_prefix else "relatedness_output"

    command {
        # Symlink files with consistent basename
        ln -s ~{bed} input.bed
        ln -s ~{bim} input.bim
        ln -s ~{fam} input.fam

        plink \
            --bfile input \
            ~{if defined(keep_samples) then "--keep " + keep_samples else ""} \
            --memory ~{mem_gb * 1000} \
            --genome \
            --out ~{out_string}

        md5sum ~{out_string}.genome | cut -d " " -f 1 > md5_genome.txt
    }

    output {
        File genome_file = "${out_string}.genome"
        Map[String, String] md5sum = {
            "genome": read_string("md5_genome.txt")
        }
    }

    runtime {
        docker: "hkim298/plink_1.9_2.0:20230116_20230707"
        memory: mem_gb + " GB"
        disks: "local-disk " + disk_size + " HDD"
    }
}