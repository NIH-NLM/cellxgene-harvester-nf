/**
 * Append Details Module (step 3)
 *
 * Adds the title, total cell count, h5ad url and explorer url of each dataset,
 * with one request to the CellxGene API for each dataset. It takes about 10 to
 * 20 minutes for 2000 datasets. Keep the result and give it back with
 * --all_datasets_complete_csv to skip steps 1 to 3 in later runs.
 *
 * Input:
 * ------
 * @param all_datasets_csv: all_datasets.csv from generate_metadata
 *
 * Output:
 * -------
 * @emit csv: all_datasets_complete.csv
 */
process append_details_process {
    tag "append_details"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path all_datasets_csv, stageAs: 'all_datasets.csv'

    output:
    path "all_datasets_complete.csv", emit: csv

    script:
    """
    cellxgene-harvester --run-dir . append-details
    """

    stub:
    """
    echo 'reference,dataset_id' > all_datasets_complete.csv
    """
}
