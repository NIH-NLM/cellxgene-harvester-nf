cellxgene-harvester-nf Documentation
=====================================

``cellxgene-harvester-nf`` is a Nextflow workflow for
`cellxgene-harvester <https://github.com/NIH-NLM/cellxgene-harvester>`_.
It finds the CellxGene datasets of one organ, one disease state and one age
range, and counts their cells from each dataset's h5ad file. Every choice is a
parameter, and every result goes to one run folder named by its date.

It writes the list of datasets that
`sc-nsforest-qc-nf <https://github.com/NIH-NLM/sc-nsforest-qc-nf>`_ reads.

It is part of the `NIH NLM Cell Knowledge Network <https://github.com/NIH-NLM/cell-kn>`_.

.. toctree::
   :maxdepth: 2
   :caption: Overview

   README

.. toctree::
   :maxdepth: 2
   :caption: Nextflow Workflow

   nextflow/index

Related Projects
----------------

- `cellxgene-harvester <https://github.com/NIH-NLM/cellxgene-harvester>`_ — the commands that this workflow runs, and the container
- `sc-nsforest-qc-nf <https://github.com/NIH-NLM/sc-nsforest-qc-nf>`_ — NSForest and scsilhouette on the harvested datasets
- `cell-kn <https://github.com/NIH-NLM/cell-kn>`_ — NIH NLM Cell Knowledge Network

Quick Start
-----------

.. code-block:: bash

   nextflow run main.nf \
       --organ         kidney \
       --disease       normal \
       --min_age       15 \
       --assay         "10x 3' v3,10x 3' v2,Smart-seq2" \
       --no_preprints  true

Everything goes to ``<run_name>/``, for example ``2026-10-06-run/``, in the
folder where the workflow was started.

Repository Structure
--------------------

.. code-block:: text

   cellxgene-harvester-nf/
   ├── assets/NO_FILE                  # placeholder for an optional input file
   ├── configs/test.config             # the test profile
   ├── docs/                           # Sphinx documentation
   │   ├── parse_nf_docs.py            # Auto-generates RST from .nf docblocks
   │   └── source/
   ├── modules/harvester/              # one Nextflow process for each step
   ├── params/example_kidney.json      # an example parameter file
   ├── tests/data/                     # one-row dataset list and the mini h5ad script
   ├── main.nf                         # Workflow entry point
   └── nextflow.config                 # Default parameters and container config

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
