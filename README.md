# cellxgene-harvester-nf

Nextflow workflow for [cellxgene-harvester](https://github.com/NIH-NLM/cellxgene-harvester). It finds the CellxGene datasets of one organ, one disease state and one age range, and counts their cells in the CellxGene Census. Every choice is a parameter.

Version 1.0.0. Tested with Nextflow 26.04.4.

## What it does

```
resolve organ, disease, age, (assay)      steps 0a to 0d    the ontology ids that define the scope
        |
fetch collections -> flatten -> add details   steps 1 to 3    skipped if you give --all_datasets_complete_csv
        |
filter datasets                            step 4            one JSON file for each dataset kept
        |
count cells in the Census                  step 5            one task for each dataset
        |
delete datasets with no cells              step 6
        |
write the CSV for sc-nsforest-qc-nf        step 7
```

Each JSON file holds the dataset, the choices that were made, and the cell counts before (`source_`) and after (`filtered_`) filtering. The JSON files are the record. The CSV is the input list for [sc-nsforest-qc-nf](https://github.com/NIH-NLM/sc-nsforest-qc-nf). See the cellxgene-harvester README for the format.

## Requirements

- Nextflow 25.04 or newer
- Docker (the image is `linux/amd64`), or a machine where `cellxgene-harvester` is installed (`-profile local`)
- A network: the ontology service (OLS4), the CellxGene API and the Census are called

## Quick start

A small run on the files in `tests/data`. Nothing is fetched and no ontology service is called, but step 5 reads the Census:

```bash
nextflow run main.nf -profile test
```

A run for one organ, from the ontology labels:

```bash
nextflow run main.nf \
    --organ kidney \
    --disease normal \
    --min_age 15 \
    --exclude_assay "spatial transcriptomics,MERFISH" \
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
| `exclude_assay` | none | Assay (technique) labels or EFO ids to leave out of the filtered counts: a list in a params file, or a comma-separated text on the command line |
| `organism` | `Homo sapiens` | Keep datasets of this organism. `''` keeps every organism |
| `no_preprints` | `false` | `true` leaves preprints out |
| `census_version` | `latest` | CellxGene Census release to read. It is recorded in each file |
| `uberon_json` | none | A file from `resolve-uberon`, used instead of resolving |
| `disease_json` | none | A file from `resolve-disease` |
| `hsapdv_json` | none | A file from `resolve-hsapdv` |
| `assay_json` | none | A file from `resolve-assay` |
| `all_datasets_complete_csv` | none | A file from `append-details`. Skips steps 1 to 3 |
| `run_name` | `<today>-run`, for example `2026-10-06-run` | The run folder. It is made in the folder where you start the workflow, and all results go in it |
| `publish_mode` | `copy` | How results are put in the run folder |
| `container` | `ghcr.io/nih-nlm/cellxgene-harvester:latest` | The image. Use a version tag for a release |
| `count_max_forks` | `4` | Datasets counted at the same time |
| `count_cpus`, `count_memory` | `2`, `16 GB` | Resources for each dataset |

Give `--run_name` on the command line or in a params file. The report files are named when the configuration is read, before a profile is applied, so a profile that sets `run_name` (as `test` does) has to name the reports itself.

## Results

Everything goes to the run folder, `<run_name>/`, in the folder where you started the workflow:

```
uberon_<organ>.json .csv .log          the resolve files (step 0)
disease_<state>.json .csv .log
hsapdv_adult_<age>.json .csv .log
assay_<first label>.json .csv .log     only with exclude_assay
collections_metadata.json              steps 1 to 3, only if they ran
all_datasets.csv
all_datasets_complete.csv
datasets.filter.log                    step 4
<organism>_<organ>_harvester/          one <dataset_id>.filtered.json for each dataset that has cells (step 6)
<organism>_<organ>_harvester.cleanup.log
<organism>_<organ>_nsforest_datasets.csv   the list for sc-nsforest-qc-nf (step 7)
<organism>_<organ>_nsforest_datasets.log
logs/<dataset_id>.filtered.json.count.log  the count log of each dataset
pipeline_timeline.html, pipeline_trace.txt, pipeline_dag.html
```

No number in these files has a thousands comma: a count is written as `11464`.

## Good to know

- **Exact labels only.** The resolve steps never ask a question. A label must match one ontology term exactly, or be an ontology id. Otherwise the step stops with an error that names the parameter. `kidney` and `UBERON:0002113` work; `kidn` does not.
- **One root term for the organ.** An organ is one UBERON term. A resolve file with several root terms is refused in step 4.
- **A dataset that cannot be counted** is tried three times and then left out. The run goes on, and the name is in the Nextflow log. It is not in the result folder.
- **Datasets that are not in the Census release** end with 0 cells and are deleted in step 6. A Census release holds the datasets that existed when it was built, so a new collections file can hold datasets that an older release does not have. Check `census_version` before a run.
- **Set `curation.filter_normal`** to `true` or `false` in each JSON file before you use the CSV with sc-nsforest-qc-nf. The export log warns how many datasets have it empty. sc-nsforest-qc-nf applies its disease and age filters only when it is `True`.
- **Resume.** Use `-resume`. The slow steps (fetch, details, counts) are not repeated when their inputs are the same.
- **The image** starts the `cellxgene-harvester` command, so every process runs with `--entrypoint ""`. Build or pull an image that has the commands of version 1.0 (`resolve-assay`, `export-datasets-csv`, `--run-dir`).

## Profiles

| Profile | Meaning |
|---------|---------|
| `test` | The files in `tests/data`: 4 datasets, 3 of which pass the filters |
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

Every pull request runs the `Tests` workflow: `nextflow lint`, a stub run of the whole workflow, a check that the generated docs are current, and a docs build that treats warnings as errors. The pull request template asks what was tested and what was not.

## Related

- [cellxgene-harvester](https://github.com/NIH-NLM/cellxgene-harvester): the commands that this workflow runs, and the container.
- [sc-nsforest-qc-nf](https://github.com/NIH-NLM/sc-nsforest-qc-nf): reads the CSV that step 7 writes.

## Contributing

The default branch is protected by the organization ruleset: change it through a pull request with a review and signed commits.

## License and security

MIT License (see `LICENSE`). Report vulnerabilities as described in `SECURITY.md`.
