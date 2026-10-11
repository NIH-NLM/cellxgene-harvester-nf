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
    path provenance_in,    stageAs: 'api_snapshot.provenance.json'
    path existing,         stageAs: 'existing'

    output:
    path "all_datasets_complete.csv",      emit: csv
    path "api_snapshot.provenance.json",   emit: provenance

    script:
    """
    # not made again if it is already there and the API has not changed
    cp -L existing/all_datasets_complete.csv . 2>/dev/null || true
    cellxgene-harvester --run-dir . append-details
    """

    stub:
    """
    echo 'reference,dataset_id,cellxgene_schema_version' > all_datasets_complete.csv
    cp -L api_snapshot.provenance.json prov.tmp && mv prov.tmp api_snapshot.provenance.json
    """
}
