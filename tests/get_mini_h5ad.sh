#!/usr/bin/env bash
# Unpack the mini kidney h5ad file (3566 cells) used by the test profile.
# Usage: tests/get_mini_h5ad.sh path/to/minilake.h5ad.tar.gz [output folder]
# Then:  nextflow run main.nf -profile test,local --h5ad <output folder>/adata_normal_n3566.h5ad
set -euo pipefail
tar_file="${1:?give the path of minilake.h5ad.tar.gz (nlm-ckn/data/test/kidney/h5ad)}"
out="${2:-tests/data/mini}"
mkdir -p "$out"
tar -xzf "$tar_file" -C "$out"
find "$out" -name '*.h5ad' -not -name '._*'
