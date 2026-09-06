#!/usr/bin/env python3
"""Convert a biallelic, no-missing-genotype SNP VCF into a FASTA core-SNP
alignment (one sequence per sample, one column per site), plus a sliding-
window SNP-density scan as a lightweight recombination screen.

Usage:
  vcf_to_snp_alignment.py --vcf calls.vcf.gz --fasta-out alignment.fasta \
      --sites-out sites.tsv --density-out density_windows.tsv \
      --window-size 5000 --contig-length-file contig_lengths.tsv
"""
import argparse
import gzip
import statistics
import sys
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--vcf", required=True)
parser.add_argument("--fasta-out", required=True)
parser.add_argument("--sites-out", required=True)
parser.add_argument("--density-out", required=True)
parser.add_argument("--window-size", type=int, default=5000)
parser.add_argument("--contig-length-file", required=True,
                     help="TSV of contig<TAB>length (from `samtools faidx` .fai, first 2 columns)")
args = parser.parse_args()


def open_maybe_gz(path):
    if str(path).endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, encoding="utf-8")


samples = []
sequences = {}
site_records = []  # (chrom, pos, ref, alt)
snp_positions = []  # (chrom, pos) for density scan

with open_maybe_gz(args.vcf) as fh:
    for line in fh:
        if line.startswith("##"):
            continue
        if line.startswith("#CHROM"):
            fields = line.rstrip("\n").split("\t")
            samples = fields[9:]
            sequences = {s: [] for s in samples}
            continue
        fields = line.rstrip("\n").split("\t")
        chrom, pos, _id, ref, alt = fields[0], fields[1], fields[2], fields[3], fields[4]
        if len(ref) != 1 or len(alt) != 1:
            continue  # defensive: this script assumes biallelic SNPs only
        genotypes = fields[9:]
        alleles_here = []
        skip_site = False
        for gt_field in genotypes:
            gt = gt_field.split(":")[0]
            if gt in (".", "./.", ".|."):
                skip_site = True
                break
            allele_index = gt[0]  # haploid GT is a single digit, e.g. "0" or "1"
            alleles_here.append(ref if allele_index == "0" else alt)
        if skip_site:
            continue
        for sample, allele in zip(samples, alleles_here):
            sequences[sample].append(allele)
        site_records.append((chrom, pos, ref, alt))
        snp_positions.append((chrom, int(pos)))

if not site_records:
    raise SystemExit("No biallelic, fully-genotyped SNP sites found -- check upstream filtering.")

with open(args.fasta_out, "w", encoding="utf-8") as fh:
    for sample in samples:
        fh.write(f">{sample}\n{''.join(sequences[sample])}\n")

with open(args.sites_out, "w", encoding="utf-8") as fh:
    fh.write("column\tchrom\tpos\tref\talt\n")
    for i, (chrom, pos, ref, alt) in enumerate(site_records, start=1):
        fh.write(f"{i}\t{chrom}\t{pos}\t{ref}\t{alt}\n")

# Sliding-window SNP density: a real signal that unusually SNP-dense
# regions may reflect recombination rather than clonal point-mutation
# accumulation (recombined DNA imports many linked SNPs at once) -- this
# is a lightweight proxy, not a substitute for a dedicated recombination
# detector (e.g. Gubbins, ClonalFrameML), which this pipeline does not
# require students to install.
contig_lengths = {}
with open(args.contig_length_file, encoding="utf-8") as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 2:
            contig_lengths[parts[0]] = int(parts[1])

window_counts = {}
for chrom, pos in snp_positions:
    length = contig_lengths.get(chrom)
    if length is None:
        continue
    window_index = (pos - 1) // args.window_size
    window_counts[(chrom, window_index)] = window_counts.get((chrom, window_index), 0) + 1

all_counts = list(window_counts.values())
mean_count = statistics.mean(all_counts) if all_counts else 0
stdev_count = statistics.stdev(all_counts) if len(all_counts) > 1 else 0
threshold = mean_count + 3 * stdev_count

with open(args.density_out, "w", encoding="utf-8") as fh:
    fh.write("chrom\twindow_start\twindow_end\tsnp_count\tflagged_high_density\n")
    for (chrom, window_index), count in sorted(window_counts.items()):
        start = window_index * args.window_size + 1
        end = start + args.window_size - 1
        flagged = "YES" if count > threshold else "no"
        fh.write(f"{chrom}\t{start}\t{end}\t{count}\t{flagged}\n")

n_flagged = sum(1 for c in all_counts if c > threshold)
print(f"OK: {len(samples)} samples x {len(site_records)} core-SNP sites written to {args.fasta_out}", file=sys.stderr)
print(f"Density scan: mean {mean_count:.2f} SNPs/window, threshold {threshold:.2f} (mean + 3 SD), "
      f"{n_flagged} window(s) flagged as unusually SNP-dense", file=sys.stderr)
if n_flagged:
    print("NOTE: inspect flagged windows before trusting the tree -- a real recombination import "
          "can look like a burst of shared derived SNPs that a point-mutation model would "
          "misread as strong phylogenetic signal.", file=sys.stderr)
