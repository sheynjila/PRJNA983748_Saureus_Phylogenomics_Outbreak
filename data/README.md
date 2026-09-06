# Data

No sample-metadata TSV is used here — the five isolates' real BioSample metadata (farm/isolate ID, isolation source, MLST strain, collection year) is fixed directly in `pipeline_phylogenomics/lib/common.sh` as associative arrays (`ISOLATE_LABEL`, `ISOLATE_SOURCE`, `ISOLATE_STRAIN`, `ISOLATE_YEAR`, `ISOLATE_FARM`), confirmed against each isolate's own real NCBI BioSample record (not inferred from the paper's aggregate text). Extend those same arrays if you add more of the source study's real 62 isolates.
