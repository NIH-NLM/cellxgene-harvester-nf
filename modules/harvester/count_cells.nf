/**
 * Count Cells Module (step 5, scatter)
 *
 * Counts the cells of ONE dataset from its h5ad file, on both sides of every
 * pair: source (all cells of the dataset) and filtered (the cells that pass the
 * tissue, disease and age filters, and whose assay is in the assay file, if one
 * is given). The cells that pass are written to {dataset_id}.filtered.h5ad.
 * The dataset file is copied and the copy is updated, so the input is never
 * changed.
 *
 * The h5ad file is the one given in h5ad (a local file, used for tests), else
 * the address in the dataset's h5ad_url (downloaded in the task).
 *
 * If a dataset cannot be counted after two more tries, it is left out and the
 * run goes on. Its name is in the Nextflow log.
 *
 * Input:
 * ------
 * @param record:         {dataset_id}.filtered.json from filter_datasets
 * @param uberon:         file from resolve_uberon
 * @param disease:        file from resolve_disease
 * @param hsapdv:         file from resolve_hsapdv
 * @param assay:           file from resolve_assay (the assays you want), or assets/NO_FILE for none
 * @param h5ad:           a local h5ad file to read instead of the dataset's h5ad_url, or assets/NO_FILE
 * @param url_prefix:     public address of the filtered h5ad files (temporary, until the location is set), or '' for none
 *
 * Output:
 * -------
 * @emit record: the counted {dataset_id}.filtered.json
 * @emit h5ad:   the {dataset_id}.filtered.h5ad (none when no cell passes)
 * @emit log:    the count log of the dataset
 */
process count_cells_process {
    tag "count_${record.baseName}"
    publishDir "${params.run_name}/logs", mode: params.publish_mode, pattern: 'out/*.log', saveAs: { f -> file(f).name }
    // TEMPORARY location: set h5ad_publish_dir to the public S3 folder when it is known
    publishDir "${params.h5ad_publish_dir ?: params.run_name + '/filtered_h5ad'}", mode: params.publish_mode, pattern: 'h5ad_out/*.h5ad', saveAs: { f -> file(f).name }

    input:
    path record, stageAs: 'in/*'
    path uberon
    path disease
    path hsapdv
    path assay
    path h5ad, stageAs: 'h5ad_in/*'
    val url_prefix

    output:
    path "out/*.filtered.json", emit: record
    path "h5ad_out/*.h5ad",     emit: h5ad, optional: true
    path "out/*.log",           emit: log, optional: true

    script:
    def fname      = record.toString().tokenize('/').last()
    def assay_flag = assay.name != 'NO_FILE' ? "--assay ${assay}" : ''
    def h5ad_flag  = h5ad.toString().tokenize('/').last() != 'NO_FILE' ? "--h5ad ${h5ad}" : ''
    def url_flag   = url_prefix ? "--h5ad-url-prefix ${url_prefix}" : ''
    """
    mkdir out
    cp -L in/* out/
    python -m harvester.count_normal_cells_single \
        --record out/${fname} \
        --uberon ${uberon} --disease ${disease} --hsapdv ${hsapdv} \
        ${assay_flag} ${h5ad_flag} ${url_flag} \
        --h5ad-out h5ad_out
    """

    stub:
    def fname = record.toString().tokenize('/').last()
    """
    mkdir out
    cp -L in/* out/
    touch out/${fname}.count.log
    """
}
