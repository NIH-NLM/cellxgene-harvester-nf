/**
 * Final Cleanup Module (step 6)
 *
 * Gathers the counted dataset files into one folder and deletes the files of the
 * datasets that have no cells after filtering (filtered_cell_count of 0). The
 * deleted dataset ids are in the log. A dataset that was never counted is not
 * in this folder.
 *
 * Input:
 * ------
 * @param records: all counted {dataset_id}.filtered.json files (may be empty)
 * @param folder:  name of the folder, for example homo_sapiens_kidney_harvester
 *
 * Output:
 * -------
 * @emit folder: the folder of dataset files that have cells after filtering
 * @emit log:    the cleanup log
 */
process final_cleanup_process {
    tag "final_cleanup_${folder}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path records
    val folder

    output:
    path folder,                 emit: folder
    path "${folder}.cleanup.log", emit: log

    script:
    """
    mkdir ${folder}
    for f in ${records}; do cp -L "\$f" ${folder}/; done
    cellxgene-harvester --run-dir . final-cleanup ${folder}
    """

    stub:
    """
    mkdir ${folder}
    for f in ${records}; do cp -L "\$f" ${folder}/; done
    touch ${folder}.cleanup.log
    """
}
