# Reference data

Place the reference genome here as `GCF_000013425.1_NCTC8325.fasta` — the same real reference used by the sibling `PRJNA983748_Saureus_Genome_Assembly` and `variant-calling-capstone-suite` repos, kept consistent here so the core-genome coordinate system matches across all three real questions asked about this same real biological material.

```
curl -o GCF_000013425.1_NCTC8325.fasta.gz \
  "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/013/425/GCF_000013425.1_ASM1342v1/GCF_000013425.1_ASM1342v1_genomic.fna.gz"
gunzip GCF_000013425.1_NCTC8325.fasta.gz
```

Do not commit it (see `.gitignore`); record its source URL, release, and SHA-256 checksum in `reference_manifest.tsv`. The pipeline stops when this reference is absent (`require_file` in Script 4) — this is intentional.
