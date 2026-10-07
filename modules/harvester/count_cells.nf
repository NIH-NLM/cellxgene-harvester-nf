/**
 * Count Cells Module (step 5, scatter)
 *
 * Counts the cells of ONE dataset in the CellxGene Census, on both sides of every
 * pair: source (all cells of the dataset) and filtered (the cells that pass the
 * tissue, disease and age filters, and whose assay is not in the excluded assay
 * file). The dataset file is copied and the copy is updated, so the input is
 * never changed.
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
 * @param exclude_assay:  file from resolve_assay, or assets/NO_FILE for none
 * @param census_version: Census release to read, for example 'latest'
 *
 * Output:
 * -------
 * @emit record: the counted {dataset_id}.filtered.json
 * @emit log:    the count log of the dataset
 */
process count_cells_process {
    tag "count_${record.baseName}"
    publishDir "${params.run_name}/logs", mode: params.publish_mode, pattern: 'out/*.log', saveAs: { f -> file(f).name }

    input:
    path record, stageAs: 'in/*'
    path uberon
    path disease
    path hsapdv
    path exclude_assay
    val census_version

    output:
    path "out/*.filtered.json", emit: record
    path "out/*.log",           emit: log, optional: true

    script:
    def fname      = record.toString().tokenize('/').last()
    def assay_flag = exclude_assay.name != 'NO_FILE' ? "--exclude-assay ${exclude_assay}" : ''
    """
    mkdir out
    cp -L in/* out/
    python -m harvester.count_normal_cells_single \
        --record out/${fname} \
        --uberon ${uberon} --disease ${disease} --hsapdv ${hsapdv} \
        ${assay_flag} \
        --census-version ${census_version}
    """

    stub:
    def fname = record.toString().tokenize('/').last()
    """
    mkdir out
    cp -L in/* out/
    touch out/${fname}.count.log
    """
}
