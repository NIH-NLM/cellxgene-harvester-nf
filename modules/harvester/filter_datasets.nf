/**
 * Filter Datasets Module (step 4)
 *
 * Keeps the datasets whose tissue and disease ids are in the resolve files, and
 * writes one {dataset_id}.filtered.json for each dataset that is kept. The
 * choices made here (organism, preprints, and the three resolve files) are
 * recorded in each file. The age file is only recorded here; the age filter runs
 * in step 5.
 *
 * Input:
 * ------
 * @param complete_csv: all_datasets_complete.csv
 * @param uberon:       file from resolve_uberon
 * @param disease:      file from resolve_disease
 * @param hsapdv:       file from resolve_hsapdv
 * @param organism:     organism to keep, or '' to keep every organism
 * @param no_preprints: true leaves preprints out
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
    val organism
    val no_preprints

    output:
    path "datasets/*.filtered.json", emit: records, optional: true
    path "datasets.filter.log",      emit: log

    script:
    def organism_flag = organism ? "--organism '${organism}'" : ''
    def preprint_flag = no_preprints ? '--no-preprints' : ''
    """
    cellxgene-harvester --run-dir . filter-datasets ${complete_csv} \
        --output datasets \
        --uberon ${uberon} --disease ${disease} --hsapdv ${hsapdv} \
        ${organism_flag} ${preprint_flag}
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
