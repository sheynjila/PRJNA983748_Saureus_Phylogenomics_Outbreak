# *Staphylococcus aureus* Phylogenomics and Outbreak Context — PRJNA983748

**Study:** Chakrawarti A, Eckstrom K, Laaguiby P, Barlow JW (2024). Access Microbiology 6(3):000766.v3. [doi:10.1099/acmi.0.000766.v3](https://doi.org/10.1099/acmi.0.000766.v3)
**Public sequence project:** PRJNA983748
**Guiding question:** What evolutionary relationships are supported, and what conclusions are not justified by the tree alone?

## Why these five isolates

Three are the same isolates used by the sibling `PRJNA983748_Saureus_Genome_Assembly` and `variant-calling-capstone-suite` repos, reused for continuity. Two more are added specifically because 3 taxa cannot show a real branch-support comparison (an unrooted 3-taxon tree has exactly one possible topology) — and because these five isolates' real BioSample records (confirmed individually, not inferred from the paper's aggregate description) give a genuinely rich outbreak-context narrative:

| Isolate | Real farm/isolate ID | Isolation source | MLST strain | Year |
|---|---|---|---|---|
| SAMN36020147 | AC06-105 | human hand swab | ST398 | 2018 |
| SAMN36020150 | AC06-111 | human nasal swab | ST398 | 2018 |
| SAMN36020166 | OF-17-34 | bulk tank milk | ST8 | 2013 |
| SAMN36020155 | AC12-45 | human nasal swab | ST7 | 2018 |
| SAMN36020190 | AC05-56 | human hand swab | ST5957 | 2018 |

Two isolates share a real farm and MLST type (AC06, ST398) — a plausible within-farm signal to test. One isolate is the only non-human source present (bulk tank milk) — a real, honest test case for the module's core guardrail that genetic relatedness is not evidence of direct transmission.

## Pipeline

| Script | Purpose |
|---|---|
| `1_Fetch_And_Verify_Raw_Reads.sh` | Fetches pilot isolate's real Illumina reads |
| `2_Interpret_FastQC_Diagnostics.sh` | FastQC on the pilot |
| `3_Fetch_All_Isolates.sh` | Fetches the remaining 4 isolates |
| `4_Map_With_BWA.sh` | BWA-MEM against NCTC 8325, isolate-specific `@RG`, verified sample identity |
| `5_Call_Variants_Bcftools.sh` | Joint `bcftools call --ploidy 1`, verified zero heterozygous genotypes, cohort-wide callable-region BED |
| `6_Build_Core_SNP_Alignment.sh` | Biallelic, no-missing-data core-SNP FASTA alignment + sliding-window SNP-density recombination screen |
| `7_Infer_Tree_IQTREE.sh` | IQ-TREE2, ModelFinder `+ASC` (required for a SNP-only alignment — see the script's own comment), 1000 ultrafast bootstrap replicates |
| `8_Interpret_Tree_And_Outbreak_Context.sh` | Midpoint rooting (via Biopython's `Bio.Phylo`, not a hand-rolled algorithm), UFBoot support summary, real metadata overlay, outbreak-interpretation template |
| `9_QC_Report_Generator.sh` | Consolidated report and portfolio-artifact checklist |

## Real, disclosed methodological choices

- **`+ASC` ascertainment-bias correction** is required, not optional, because the alignment contains only variable sites by construction — see Script 7's own comment for why omitting it would systematically distort branch lengths.
- **Midpoint rooting**: no real outgroup exists among these five isolates (all are *S. aureus* from the same study). Midpoint rooting is the standard, defensible default in that situation — not a claim of a known ancestral state.
- **Recombination screen**: a sliding-window SNP-density scan (no external tool required), not a dedicated detector like Gubbins or ClonalFrameML — a documented, lighter-weight proxy.
- **Sparse sampling, disclosed explicitly**: only 5 of this real study's 62 real isolates are used. The final report states this as a real limitation on any outbreak-context conclusion, not a footnote.

## Verification status

Reviewed line by line for correct tool syntax and real, ENA/NCBI-confirmed accessions and BioSample metadata. `utils/vcf_to_snp_alignment.py` (pure standard library) was functionally tested against a synthetic VCF, including a missing-genotype site correctly excluded. `utils/root_and_interpret_tree.py` (uses Biopython's `Bio.Phylo`) was syntax-checked but **not functionally tested** — this session's environment has no working `pip` even inside WSL, so biopython could not be installed to test the actual midpoint-rerooting call. State this explicitly if you run it and it needs a fix.

## License

MIT — see [`LICENSE`](LICENSE).
