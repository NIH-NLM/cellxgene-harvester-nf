/**
 * Export Final Files Module (step 7)
 *
 * Writes two files side by side, named alike:
 *   {name}_final.csv   read by sc-nsforest-qc-nf (--datasets_csv): one row for each
 *                      dataset that has cells after filtering
 *   {name}_final.json  one JSON array with the full record of the same datasets,
 *                      in the same order
 *
 * Input:
 * ------
 * @param folder:   folder from final_cleanup
 * @param csv_name: name of the CSV, for example homo_sapiens_kidney_harvester_final.csv
 *
 * Output:
 * -------
 * @emit csv:  the final CSV
 * @emit json: the final JSON, named like the CSV
 * @emit log:  the export log
 */
process export_datasets_csv_process {
    tag "export_${csv_name}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path folder
    val csv_name

    output:
    path csv_name,                                   emit: csv
    path "${csv_name.replaceAll(/\.csv$/, '.json')}", emit: json
    path "${csv_name.replaceAll(/\.csv$/, '')}.log",  emit: log

    script:
    def json_name = csv_name.replaceAll(/\.csv$/, '.json')
    """
    cellxgene-harvester --run-dir . export-datasets-csv ${folder} --output ${csv_name} --output-json ${json_name}
    """

    stub:
    def json_name = csv_name.replaceAll(/\.csv$/, '.json')
    """
    echo 'reference,dataset_id' > ${csv_name}
    echo '[]' > ${json_name}
    touch ${csv_name.replaceAll(/\.csv$/, '')}.log
    """
}
