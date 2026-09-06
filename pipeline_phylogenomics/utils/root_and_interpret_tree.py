#!/usr/bin/env python3
"""Midpoint-root an IQ-TREE consensus tree, extract UFBoot support per
clade, and write a plain-text summary. Uses Biopython's Bio.Phylo (a real,
tested implementation) rather than a hand-rolled midpoint-rerooting
algorithm.

NARRATIVE -- why midpoint rooting specifically: none of these five real
isolates is a legitimate outgroup (all are S. aureus from the same real
study); without a real outgroup, midpoint rooting (root at the midpoint of
the longest tip-to-tip path) is the standard, defensible default -- not
because it is guaranteed correct, but because there is no better-justified
alternative available from this data alone. This choice, and its
limitation, is stated explicitly in the output rather than left implicit.

Usage:
  root_and_interpret_tree.py --tree saureus_core_snp.contree \
      --out-newick rooted_tree.nwk --out-summary tree_summary.tsv \
      --support-threshold 95
"""
import argparse
import sys

try:
    from Bio import Phylo
except ImportError:
    sys.exit(
        "ERROR: biopython is required for this step (pip install biopython). "
        "This pipeline uses Bio.Phylo's real, tested midpoint-rerooting "
        "implementation rather than a hand-rolled one."
    )

parser = argparse.ArgumentParser()
parser.add_argument("--tree", required=True, help="IQ-TREE .contree or .treefile (Newick)")
parser.add_argument("--out-newick", required=True)
parser.add_argument("--out-summary", required=True)
parser.add_argument("--support-threshold", type=float, default=95.0)
args = parser.parse_args()

tree = Phylo.read(args.tree, "newick")

# IQ-TREE writes UFBoot support as the internal-node "name" (technically a
# confidence label, not a taxon name) -- Bio.Phylo exposes it as
# `.confidence` only if it can parse it as a number from that position;
# otherwise it stays in `.name`. Normalize both cases into `.confidence`.
for clade in tree.get_nonterminals():
    if clade.confidence is None and clade.name is not None:
        try:
            clade.confidence = float(clade.name)
            clade.name = None
        except ValueError:
            pass

tree.root_at_midpoint()
Phylo.write(tree, args.out_newick, "newick")

internal_clades = [c for c in tree.get_nonterminals() if c.confidence is not None]
n_total = len(internal_clades)
n_well_supported = sum(1 for c in internal_clades if c.confidence >= args.support_threshold)

with open(args.out_summary, "w", encoding="utf-8") as fh:
    fh.write("metric\tvalue\n")
    fh.write(f"rooting_method\tmidpoint (no real outgroup available among these 5 isolates)\n")
    fh.write(f"n_tips\t{tree.count_terminals()}\n")
    fh.write(f"n_internal_branches_with_support_value\t{n_total}\n")
    fh.write(f"support_threshold_used\t{args.support_threshold}\n")
    fh.write(f"n_branches_at_or_above_threshold\t{n_well_supported}\n")
    fh.write(f"n_branches_below_threshold\t{n_total - n_well_supported}\n")
    fh.write("\nper_clade_support\ttip_names\n")
    for clade in internal_clades:
        tips = ",".join(t.name for t in clade.get_terminals())
        fh.write(f"{clade.confidence:.1f}\t{tips}\n")

print(f"OK: wrote {args.out_newick} and {args.out_summary}", file=sys.stderr)
if n_total - n_well_supported > 0:
    print(f"NOTE: {n_total - n_well_supported} of {n_total} internal branches fall below "
          f"the {args.support_threshold}% UFBoot threshold -- do not report the relationships "
          "those branches imply as confidently resolved.", file=sys.stderr)
