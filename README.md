[![Build and Deploy Sphinx Documentation](https://github.com/NIH-NLM/cellxgene-harvester-nf/actions/workflows/docs.yml/badge.svg)](https://github.com/NIH-NLM/cellxgene-harvester-nf/actions/workflows/docs.yml)
[![Mini kidney test](https://github.com/NIH-NLM/cellxgene-harvester-nf/actions/workflows/mini-test.yml/badge.svg)](https://github.com/NIH-NLM/cellxgene-harvester-nf/actions/workflows/mini-test.yml)

# cellxgene-harvester-nf

Nextflow workflow for [cellxgene-harvester](https://github.com/NIH-NLM/cellxgene-harvester). It finds the CellxGene datasets of one organ, one disease state and one age range, and counts their cells from the h5ad file of each dataset, writing the cells that pass the filters to a new h5ad file. Every choice is a parameter.

Version 1.0.0. Tested with Nextflow 26.04.4.

## What it does

```
resolve organ, disease, age, (assay)      steps 0a to 0d    the ontology ids that define the scope
        |
fetch collections -> flatten -> add details   steps 1 to 3    skipped if you give --all_datasets_complete_csv
        |
filter datasets                            step 4            one JSON file for each dataset kept
        |
count cells, write filtered h5ad file      step 5            one task for each dataset
        |
delete datasets with no cells              step 6
        |
write the CSV for sc-nsforest-qc-nf        step 7
        |
publish to a new GitHub branch             step 8            only with --github_token
```

Each JSON file holds the dataset, the choices that were made, and the cell counts before (`source_`) and after (`filtered_`) filtering. Step 5 also writes `<dataset_id>.filtered.h5ad`, the cells that pass the filters, and the JSON says where it is published (`filtered_h5ad_url`). The JSON files are the record. The CSV is the input list for [sc-nsforest-qc-nf](https://github.com/NIH-NLM/sc-nsforest-qc-nf). See the cellxgene-harvester README for the format.

## Requirements

- Nextflow 25.04 or newer
- Docker (the image is `linux/amd64`), or a machine where `cellxgene-harvester` is installed (`-profile local`)
- A network: the ontology service (OLS4), the CellxGene API and the h5ad files of the datasets are called

## Quick start

A small run on the mini kidney h5ad file (3566 cells, one dataset; `nlm-ckn/data/test/kidney/h5ad/minilake.h5ad.tar.gz`). The resolve steps run normally (OLS4). Step 5 reads only the mini file, so no other h5ad file is downloaded:

```bash
tests/get_mini_h5ad.sh path/to/minilake.h5ad.tar.gz
nextflow run main.nf -profile test,local --h5ad tests/data/mini/adata_normal_n3566.h5ad
```

On Lifebit, give the edited file in S3 as `--h5ad`.

A run for one organ, from the ontology labels (each dataset's h5ad file is downloaded from CellxGene):

```bash
nextflow run main.nf \
    --organ kidney \
    --disease normal \
    --min_age 15 \
    --assay "10x 3' v3,10x 3' v2,Smart-seq2" \
    --no_preprints true
```

The same choices in a file (`params/example_kidney.json`):

```bash
nextflow run main.nf -params-file params/example_kidney.json
```

Without `--all_datasets_complete_csv` the run fetches every collection and adds the details of about 2000 datasets, which takes 10 to 20 minutes. Keep `all_datasets_complete.csv` from the run folder and give it to later runs.

## Parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `organ` | none | UBERON label or id, for example `kidney`. Needed unless `uberon_json` is given |
| `disease` | `normal` | Disease or phenotype label or id (PATO, MONDO) |
| `min_age` | `15` | Minimum age in years. The HsapDv stages that start at or after it are kept |
| `assay` | none | The assays (techniques) you **want**, by exact EFO label or EFO id: a list in a params file, or a comma-separated text. Only the cells of these assays are counted on the filtered side, so every other assay, for example every spatial technique, is left out. An assay that does not resolve is skipped and listed under `unresolved` |
| `organism` | `Homo sapiens` | Keep datasets of this organism. `''` keeps every organism |
| `no_preprints` | `false` | `true` leaves preprints out |
| `h5ad` | none | A local h5ad file to read instead of each dataset's `h5ad_url`. For tests, with one dataset |
| `h5ad_publish_dir` | none | **Temporary, to be set.** Folder the filtered h5ad files are copied to. The public S3 folder on the STRIDES account goes here. When none, `<run_name>/filtered_h5ad` |
| `h5ad_url_prefix` | none | **Temporary, to be set.** Public address of that folder. Written to `filtered_h5ad_url` in each file and to `h5ad_url` in the CSV that sc-nsforest-qc-nf reads. When none, the local path |
| `github_token` | none | A token that can push to `publish_repo`. Without it, step 8 (publish) is skipped with a warning |
| `publish_repo` | `NIH-NLM/nlm-ckn` | Repository that gets the new branch |
| `publish_env` | `prod` | `prod`: the final JSON and CSV (and the organ's uberon files) to `data/prod/<organ>/cellxgene-harvester-nf/`, and the disease, hsapdv and assay files to `data/prod/ontology_lookup_server/`. `test` (set by the test profile): the same under `data/test/`, and the filtered h5ad files to `data/test/<organ>/filtered-h5ad/` |
| `publish_dest_dir` | none | Replaces the organ folder above |
| `publish_shared_dir` | none | Replaces the `ontology_lookup_server` folder above |
| `assay_name` | `published` | Name of the assay file, `assay_<assay_name>.json` and `.csv`. Name the set of assays, not its first label. Another set of assays gets another name |
| `uberon_json` | none | A file from `resolve-uberon`, used instead of resolving |
| `disease_json` | none | A file from `resolve-disease` |
| `hsapdv_json` | none | A file from `resolve-hsapdv` |
| `assay_json` | none | A file from `resolve-assay` |
| `all_datasets_complete_csv` | none | A file from `append-details`. Skips steps 1 to 3 |
| `run_name` | `<today>-run`, for example `2026-10-06-run` | The run folder. It is made in the folder where you start the workflow, and all results go in it |
| `publish_mode` | `copy` | How results are put in the run folder |
| `container` | `ghcr.io/nih-nlm/cellxgene-harvester:latest` | The image. Use a version tag (`1.0.0`) for a release, or a branch name to test a branch: the image is built on every commit to cellxgene-harvester |
| `count_max_forks` | `4` | Datasets counted at the same time |
| `count_cpus`, `count_memory` | `2`, `16 GB` | Resources for each dataset |

Give `--run_name` on the command line or in a params file. The report files are named when the configuration is read, before a profile is applied, so a profile that sets `run_name` (as `test` does) has to name the reports itself.

## Results

Everything goes to the run folder, `<run_name>/`, in the folder where you started the workflow:

```
uberon_<organ>.json .csv .log          the resolve files (step 0)
disease_<state>.json .csv .log
hsapdv_adult_<age>.json .csv .log
assay_<assay_name>.json .csv .log      only with assay (default assay_published: the assays that resolved, and the unresolved labels)
collections_metadata.json              steps 1 to 3, only if they ran
all_datasets.csv
all_datasets_complete.csv
datasets.filter.log                    step 4
<organism>_<organ>_harvester/          working folder: one <dataset_id>.filtered.json for each dataset that has cells (step 6). Not published
<organism>_<organ>_harvester.cleanup.log
<organism>_<organ>_harvester_final.csv   the list for sc-nsforest-qc-nf (step 7)
<organism>_<organ>_harvester_final.json  one JSON array with the full record of the same datasets (step 7), next to the CSV
<organism>_<organ>_harvester_final.log
filtered_h5ad/<dataset_id>.filtered.h5ad  the cells that pass the filters (step 5; the folder is h5ad_publish_dir when it is given)
logs/<dataset_id>.filtered.json.count.log  the count log of each dataset
pipeline_timeline.html, pipeline_trace.txt, pipeline_dag.html
```

No number in these files has a thousands comma: a count is written as `11464`.

## Good to know

- **Exact labels only.** The resolve steps never ask a question. A label must match one ontology term exactly, or be an ontology id. Otherwise the step stops with an error that names the parameter. `kidney` and `UBERON:0002113` work; `kidn` does not.
- **Read `unresolved`.** An assay label that does not resolve is skipped, not fatal, so the cells of that assay are left out of the counts. Look at `unresolved` in `assay_*.json` (it is also in each dataset file under `filter_choices.assay`). It should be empty.
- **One root term for the organ.** An organ is one UBERON term. A resolve file with several root terms is refused in step 4.
- **A dataset that cannot be counted** is tried three times and then left out. The run goes on, and the name is in the Nextflow log. It is not in the result folder.
- **The filtered h5ad location is not set yet.** Until `h5ad_publish_dir` and `h5ad_url_prefix` are given, the files stay in `<run_name>/filtered_h5ad` and the CSV points to the local path. Set both before a production run, because sc-nsforest-qc-nf reads the filtered file from that address.
- **Resume.** Use `-resume`. The slow steps (fetch, details, counts) are not repeated when their inputs are the same.
- **The image** starts the `cellxgene-harvester` command, so every process runs with `--entrypoint ""`. The image must have the commands of version 1.0 (`resolve-assay`, `export-datasets-csv`, `--run-dir`, and the h5ad counting with `--h5ad-out`). Images are built automatically on every commit, so a branch tag has them before the merge.

## Tests on GitHub Actions

| Workflow | When | What |
|----------|------|------|
| `Tests` | every pull request and push to main | lint, stub run, docs build |
| `Mini kidney test` | **manual** (Actions tab > Run workflow) | the whole workflow on the mini kidney file with a real harvester image. The `harvester_image` input must hold the h5ad counting: the image is built automatically on every commit to cellxgene-harvester (tag `<branch name>` or `sha-<commit>`). Tick `publish` to also push the results to a branch of `NIH-NLM/nlm-ckn` under `data/test/kidney/` (needs the secret `NLM_CKN_TOKEN`) |

## Publishing (step 8)

With `--github_token`, the run ends by pushing the final files and the resolve files to a new branch of `publish_repo`, in two places:

```
data/<env>/<organ>/cellxgene-harvester-nf/   <organism>_<organ>_harvester_final.json and .csv, uberon_<organ>.json and .csv (all at one level)
data/<env>/ontology_lookup_server/           disease_*.json/.csv, hsapdv_adult_*.json/.csv, assay_<assay_name>.json/.csv (shared by every organ)
data/test/<organ>/filtered-h5ad/             the filtered h5ad files (test only)
```

`<env>` is `prod` or `test` (`publish_env`). The per-dataset working folder is not published. A resolve file given as `uberon_json`, `disease_json`, `hsapdv_json` or `assay_json` is published with its CSV when the CSV is next to it. Nothing goes to `main`. You inspect the branch and merge it by hand. The branch is named by date, time and organ, for example `2026-oct-07-1415-kidney-cellxgene-harvester-nf`. In `prod` the filtered h5ad files are not put in GitHub: they go to the public S3 folder (`h5ad_publish_dir`, `h5ad_url_prefix`), which is not set yet.

## Profiles

| Profile | Meaning |
|---------|---------|
| `test` | One kidney dataset in `tests/data`, counted from the mini h5ad file you give with `--h5ad` |
| `local` | The `cellxgene-harvester` installed on this machine, no container |

Check the scripts and the wiring without calling anything:

```bash
nextflow lint .
nextflow run main.nf -profile test,local -stub-run
```

## Documentation

The documentation is built with Sphinx and published to GitHub Pages. The Nextflow pages are generated from the `/** ... */` block above each process in `modules/`:

```bash
python3 docs/parse_nf_docs.py
pip install sphinx myst-parser sphinx-rtd-theme
sphinx-build -W -b html docs/source docs/build/html
```

Run `docs/parse_nf_docs.py` after you change a module and commit the generated files in `docs/source/nextflow/`. The `Tests` workflow fails if they are out of date.

## Tests and review

The real test is the manual `Mini kidney test` above. Every pull request runs the `Tests` workflow: `nextflow lint`, a stub run of the whole workflow (including the publish step), a check that the generated docs are current, and a docs build that treats warnings as errors. The pull request template asks what was tested and what was not.

## Related

- [cellxgene-harvester](https://github.com/NIH-NLM/cellxgene-harvester): the commands that this workflow runs, and the container.
- [sc-nsforest-qc-nf](https://github.com/NIH-NLM/sc-nsforest-qc-nf): reads the CSV that step 7 writes.

## Contributing

The default branch is protected by the organization ruleset: change it through a pull request with a review and signed commits.

## License and security

MIT License (see `LICENSE.md`). Report vulnerabilities as described in `SECURITY.md`.
