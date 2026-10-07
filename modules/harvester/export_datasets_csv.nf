/**
 * Export Datasets CSV Module (step 7)
 *
 * Writes the CSV that sc-nsforest-qc-nf reads (--datasets_csv): one row for each
 * dataset that has cells after filtering. The JSON files stay the full record.
 *
 * Input:
 * ------
 * @param folder:   folder from final_cleanup
 * @param csv_name: name of the CSV, for example homo_sapiens_kidney_harvester_final.csv
 *
 * Output:
 * -------
 * @emit csv: the datasets CSV
 * @emit log: the export log
 */
process export_datasets_csv_process {
    tag "export_${csv_name}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path folder
    val csv_name

    output:
    path csv_name,                           emit: csv
    path "${csv_name.replaceAll(/\.csv$/, '')}.log", emit: log

    script:
    """
    cellxgene-harvester --run-dir . export-datasets-csv ${folder} --output ${csv_name}
    """

    stub:
    """
    echo 'reference,dataset_id' > ${csv_name}
    touch ${csv_name.replaceAll(/\.csv$/, '')}.log
    """
}
