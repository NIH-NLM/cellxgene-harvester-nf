/**
 * Filter Datasets Module (step 4)
 *
 * Keeps the datasets whose tissue, disease and (when an assay file is given)
 * assay ids are in the resolve files, and writes one {dataset_id}.filtered.json
 * for each dataset that is kept. The choices made here (organism, preprints, and
 * the resolve files) are recorded in each file. The assay file is applied again to
 * the cells in step 5, so both steps use one choice. The age file is only recorded
 * here; the age filter runs in step 5.
 *
 * Input:
 * ------
 * @param complete_csv: all_datasets_complete.csv
 * @param uberon:       file from resolve_uberon
 * @param disease:      file from resolve_disease
 * @param hsapdv:       file from resolve_hsapdv
 * @param assay:        file from resolve_assay (the assays you want), or assets/NO_FILE for none
 * @param organism:     organism to keep, or '' to keep every organism
 * @param no_preprints: true leaves preprints out
 * @param author_cell_type: curation.author_cell_type for every dataset (the obs column of the author's cell types), or '' to take it from the CSV
 * @param embedding:    curation.embedding for every dataset (the obsm key, for example X_umap), or '' to take it from the CSV
 *
 * Output:
 * -------
 * @emit records: {dataset_id}.filtered.json, one for each dataset kept
 * @emit log:     the filter log
 */
process filter_datasets_process {
    tag "filter_datasets"
    publishDir "${params.run_name}", mode: params.publish_mode, pattern: '*.filter.log'

    input:
    path complete_csv
    path uberon
    path disease
    path hsapdv
    path assay
    val organism
    val no_preprints
    val author_cell_type
    val embedding

    output:
    path "datasets/*.filtered.json", emit: records, optional: true
    path "datasets.filter.log",      emit: log

    script:
    def organism_flag = organism ? "--organism '${organism}'" : ''
    def preprint_flag = no_preprints ? '--no-preprints' : ''
    def assay_flag    = assay.name != 'NO_FILE' ? "--assay ${assay}" : ''
    def type_flag     = author_cell_type ? "--author-cell-type '${author_cell_type}'" : ''
    def embedding_flag = embedding ? "--embedding '${embedding}'" : ''
    """
    cellxgene-harvester --run-dir . filter-datasets ${complete_csv} \
        --output datasets \
        --uberon ${uberon} --disease ${disease} --hsapdv ${hsapdv} \
        ${assay_flag} ${organism_flag} ${preprint_flag} ${type_flag} ${embedding_flag}
    """

    stub:
    """
    mkdir datasets
    for id in stub_a stub_b; do
        echo '{"dataset": {"dataset_id": "'\$id'"}, "filtered_cell_count": null}' > datasets/\$id.filtered.json
    done
    touch datasets.filter.log
    """
}
