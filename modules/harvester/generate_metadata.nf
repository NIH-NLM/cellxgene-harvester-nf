/**
 * Generate Metadata Module (step 2)
 *
 * Flattens the collections into one row for each dataset (latest version).
 *
 * Input:
 * ------
 * @param collections_json: collections_metadata.json from fetch_collections
 *
 * Output:
 * -------
 * @emit csv: all_datasets.csv
 */
process generate_metadata_process {
    tag "generate_metadata"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path collections_json, stageAs: 'collections_metadata.json'

    output:
    path "all_datasets.csv", emit: csv

    script:
    """
    cellxgene-harvester --run-dir . generate-metadata
    """

    stub:
    """
    echo 'reference,dataset_id' > all_datasets.csv
    """
}
