Harvester Modules
=================

Nextflow modules for the ``cellxgene-harvester-nf`` workflow. Each module
runs one command of ``cellxgene-harvester`` inside the
``ghcr.io/nih-nlm/cellxgene-harvester`` container and is orchestrated by
``main.nf``.

The ``cellxgene-harvester`` package finds the CellxGene datasets of one
organ, disease state and age, and counts their cells in the CellxGene
Census. For the commands and the output format see the
`cellxgene-harvester repository <https://github.com/NIH-NLM/cellxgene-harvester>`_.

Execution order:

1. ``resolve_uberon_process``, ``resolve_disease_process``,
   ``resolve_hsapdv_process``, ``resolve_assay_process`` (optional) — the
   ontology ids that define the scope (steps 0a to 0d)
2. ``fetch_collections_process``, ``generate_metadata_process``,
   ``append_details_process`` — the dataset list (steps 1 to 3; skipped with
   ``--all_datasets_complete_csv``)
3. ``filter_datasets_process`` — one JSON file for each dataset kept (step 4)
4. ``count_cells_process`` — the Census counts, one task for each dataset (step 5)
5. ``final_cleanup_process`` — delete the datasets with no cells (step 6)
6. ``export_datasets_csv_process`` — the CSV for sc-nsforest-qc-nf (step 7)


Append Details Process
^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``append_details_process``

*Source:* ``modules/harvester/append_details.nf``

Append Details Module (step 3)

Adds the title, total cell count, h5ad url and explorer url of each dataset,
with one request to the CellxGene API for each dataset. It takes about 10 to
20 minutes for 2000 datasets. Keep the result and give it back with
--all_datasets_complete_csv to skip steps 1 to 3 in later runs.


Input:
~~~~~~
@param all_datasets_csv: all_datasets.csv from generate_metadata


Output:
~~~~~~~
@emit csv: all_datasets_complete.csv

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Count Cells Process
^^^^^^^^^^^^^^^^^^^

.. rubric:: ``count_cells_process``

*Source:* ``modules/harvester/count_cells.nf``

Count Cells Module (step 5, scatter)

Counts the cells of ONE dataset in the CellxGene Census, on both sides of every
pair: source (all cells of the dataset) and filtered (the cells that pass the
tissue, disease and age filters, and whose assay is not in the excluded assay
file). The dataset file is copied and the copy is updated, so the input is
never changed.

If a dataset cannot be counted after two more tries, it is left out and the
run goes on. Its name is in the Nextflow log.


Input:
~~~~~~
@param record:         {dataset_id}.filtered.json from filter_datasets
@param uberon:         file from resolve_uberon
@param disease:        file from resolve_disease
@param hsapdv:         file from resolve_hsapdv
@param exclude_assay:  file from resolve_assay, or assets/NO_FILE for none
@param census_version: Census release to read, for example 'latest'


Output:
~~~~~~~
@emit record: the counted {dataset_id}.filtered.json
@emit log:    the count log of the dataset

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Export Datasets Csv Process
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``export_datasets_csv_process``

*Source:* ``modules/harvester/export_datasets_csv.nf``

Export Datasets CSV Module (step 7)

Writes the CSV that sc-nsforest-qc-nf reads (--datasets_csv): one row for each
dataset that has cells after filtering. The JSON files stay the full record.

Set curation.filter_normal to true or false in each JSON file before this
step. The log warns how many datasets have it empty.


Input:
~~~~~~
@param folder:   folder from final_cleanup
@param csv_name: name of the CSV, for example homo_sapiens_kidney_nsforest_datasets.csv


Output:
~~~~~~~
@emit csv: the datasets CSV
@emit log: the export log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Fetch Collections Process
^^^^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``fetch_collections_process``

*Source:* ``modules/harvester/fetch_collections.nf``

Fetch Collections Module (step 1)

Fetches every public collection from the CellxGene curation API.


Output:
~~~~~~~
@emit json: collections_metadata.json

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Filter Datasets Process
^^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``filter_datasets_process``

*Source:* ``modules/harvester/filter_datasets.nf``

Filter Datasets Module (step 4)

Keeps the datasets whose tissue and disease ids are in the resolve files, and
writes one {dataset_id}.filtered.json for each dataset that is kept. The
choices made here (organism, preprints, and the three resolve files) are
recorded in each file. The age file is only recorded here; the age filter runs
in step 5.


Input:
~~~~~~
@param complete_csv: all_datasets_complete.csv
@param uberon:       file from resolve_uberon
@param disease:      file from resolve_disease
@param hsapdv:       file from resolve_hsapdv
@param organism:     organism to keep, or '' to keep every organism
@param no_preprints: true leaves preprints out


Output:
~~~~~~~
@emit records: {dataset_id}.filtered.json, one for each dataset kept
@emit log:     the filter log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Final Cleanup Process
^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``final_cleanup_process``

*Source:* ``modules/harvester/final_cleanup.nf``

Final Cleanup Module (step 6)

Gathers the counted dataset files into one folder and deletes the files of the
datasets that have no cells after filtering (filtered_cell_count of 0). The
deleted dataset ids are in the log. A dataset that was never counted is not
in this folder.


Input:
~~~~~~
@param records: all counted {dataset_id}.filtered.json files (may be empty)
@param folder:  name of the folder, for example homo_sapiens_kidney_harvester


Output:
~~~~~~~
@emit folder: the folder of dataset files that have cells after filtering
@emit log:    the cleanup log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Generate Metadata Process
^^^^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``generate_metadata_process``

*Source:* ``modules/harvester/generate_metadata.nf``

Generate Metadata Module (step 2)

Flattens the collections into one row for each dataset (latest version).


Input:
~~~~~~
@param collections_json: collections_metadata.json from fetch_collections


Output:
~~~~~~~
@emit csv: all_datasets.csv

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Resolve Assay Process
^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``resolve_assay_process``

*Source:* ``modules/harvester/resolve_assay.nf``

Resolve Assay Module (step 0d, optional)

Resolves one or more assay (technique) terms in EFO, with all their
descendants. The file is a NEGATIVE selection: the cells whose assay ontology
id is in it are left out of the filtered counts (for example spatial
techniques). Each query is a root term and must match one EFO term exactly,
or be an EFO id such as EFO:0008994. The step never asks a question.


Input:
~~~~~~
@param queries: list of assay labels or EFO ids, for example
                ['spatial transcriptomics', 'MERFISH']


Output:
~~~~~~~
@emit json: assay_{first label}.json
@emit csv:  assay_{first label}.csv
@emit log:  assay_{first label}.log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Resolve Disease Process
^^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``resolve_disease_process``

*Source:* ``modules/harvester/resolve_disease.nf``

Resolve Disease Module (step 0b)

Resolves one disease or phenotype (a PATO or MONDO label or id) and all its
descendants through the OLS4 web service.

The label must match one term exactly, or be an id such as PATO:0000461. The
step never asks a question: if the label does not match exactly, the step
stops with an error.


Input:
~~~~~~
@param query: disease label or id, for example 'normal'


Output:
~~~~~~~
@emit json: disease_{label}.json
@emit csv:  disease_{label}.csv
@emit log:  disease_{label}.log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Resolve Hsapdv Process
^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``resolve_hsapdv_process``

*Source:* ``modules/harvester/resolve_hsapdv.nf``

Resolve HsapDv Module (step 0c)

Reads the HsapDv (human development stage) ontology and keeps the stages that
start at or after the minimum age. The age is kept in the file as "min_age".


Input:
~~~~~~
@param min_age: minimum age in years, for example 15


Output:
~~~~~~~
@emit json: hsapdv_adult_{min_age}.json
@emit csv:  hsapdv_adult_{min_age}.csv
@emit log:  hsapdv_adult_{min_age}.log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``


Resolve Uberon Process
^^^^^^^^^^^^^^^^^^^^^^

.. rubric:: ``resolve_uberon_process``

*Source:* ``modules/harvester/resolve_uberon.nf``

Resolve UBERON Module (step 0a)

Resolves one organ (an UBERON label or id) and all its descendants through the
OLS4 web service, and writes the term file that the later steps read.

The label must match one UBERON term exactly, or be an UBERON id such as
UBERON:0002113. The step never asks a question: if the label does not match
exactly, the step stops with an error, so no organ is chosen for you.


Input:
~~~~~~
@param query: UBERON label or id, for example 'kidney'


Output:
~~~~~~~
@emit json: uberon_{label}.json (queries, root_terms, obo_ids, terms, total)
@emit csv:  uberon_{label}.csv
@emit log:  uberon_{label}.log

**Params referenced:**

- ``params.publish_mode``
- ``params.run_name``

