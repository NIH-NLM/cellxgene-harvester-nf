#!/usr/bin/env nextflow

/*
 * cellxgene-harvester-nf
 * ======================
 * Runs cellxgene-harvester from step 0 to step 7:
 *
 *   0a-0d  resolve the organ, disease, age and (optional) assay to ontology ids
 *   1-3    fetch the CellxGene collections, flatten them, add the dataset details
 *   4      filter the datasets by tissue, disease and (optional) assay
 *   5      count the cells of each dataset from its h5ad file and write the filtered
 *          h5ad file                                       (one task for each dataset)
 *   6      delete the datasets that have no cells after filtering
 *   7      write the final CSV (read by sc-nsforest-qc-nf) and the final JSON, side by side
 *   8      publish them, and the resolve files, to a new branch of the GitHub repository (needs --github_token)
 *
 * All the choices are parameters; see nextflow.config and the README.
 */

include { resolve_uberon_process }    from './modules/harvester/resolve_uberon.nf'
include { resolve_disease_process }   from './modules/harvester/resolve_disease.nf'
include { resolve_hsapdv_process }    from './modules/harvester/resolve_hsapdv.nf'
include { resolve_assay_process }     from './modules/harvester/resolve_assay.nf'
include { fetch_collections_process } from './modules/harvester/fetch_collections.nf'
include { generate_metadata_process } from './modules/harvester/generate_metadata.nf'
include { append_details_process }    from './modules/harvester/append_details.nf'
include { filter_datasets_process }   from './modules/harvester/filter_datasets.nf'
include { count_cells_process }       from './modules/harvester/count_cells.nf'
include { final_cleanup_process }     from './modules/harvester/final_cleanup.nf'
include { export_datasets_csv_process } from './modules/harvester/export_datasets_csv.nf'
include { build_gene_mapping_process } from './modules/harvester/build_gene_mapping.nf'
include { publish_github_process }    from './modules/harvester/publish_github.nf'

// A resolve file given as a parameter is published with its CSV when the CSV is next to it.
def sibling_csv(json_path) {
    def csv_file = file(json_path.toString().replaceAll(/\.json$/, '.csv'))
    return csv_file.exists() ? channel.value(csv_file) : channel.empty()
}

// A folder of data_dir that holds files made before, or the empty placeholder when there is none.
// The commands do not make again a file that is already there and answers the same question.
def existing_dir(sub) {
    def dir = params.data_dir ? file("${params.data_dir}/${sub}") : null
    return channel.value(dir && dir.isDirectory() ? dir : file("${projectDir}/assets/NO_FILE"))
}

workflow {

    // ---- check the parameters ----------------------------------------------------
    if (!params.organ && !params.uberon_json) {
        error "Give --organ (an exact UBERON label or id) or --uberon_json."
    }

    def organ_name    = params.organ ?: file(params.uberon_json).baseName.replace('uberon_', '')
    def organ_slug    = organ_name.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    def organism_slug = params.organism ? params.organism.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_') : 'all_organisms'
    def folder_name   = "${organism_slug}_${organ_slug}_harvester"
    def csv_name      = "${organism_slug}_${organ_slug}_harvester_final.csv"

    log.info "cellxgene-harvester-nf ${workflow.manifest.version}"
    def disease_name = params.disease_json ? file(params.disease_json).name : params.disease
    def age_name     = params.hsapdv_json ? file(params.hsapdv_json).name : params.min_age
    log.info "organ ${organ_name} | disease ${disease_name} | min_age ${age_name} | organism ${params.organism ?: 'all'}"
    log.info "results in ${params.run_name}"

    // ---- step 0: the resolve files ---------------------------------------------------
    def uberon_ch
    def uberon_csv
    if (params.uberon_json) {
        uberon_ch  = channel.value(file(params.uberon_json, checkIfExists: true))
        uberon_csv = sibling_csv(params.uberon_json)
    }
    else {
        // exact relation labels whose terms are added to the organ, for example 'contributes to morphology of'
        def relations = !params.uberon_relation ? [] : (params.uberon_relation instanceof List ? params.uberon_relation : [params.uberon_relation.toString()])
        def resolved = resolve_uberon_process(params.organ, relations, existing_dir("${organ_slug}/cellxgene-harvester-nf"))
        uberon_ch  = resolved.json.first()
        uberon_csv = resolved.csv
    }

    def disease_ch
    def disease_csv
    if (params.disease_json) {
        disease_ch  = channel.value(file(params.disease_json, checkIfExists: true))
        disease_csv = sibling_csv(params.disease_json)
    }
    else {
        def resolved = resolve_disease_process(params.disease, existing_dir('ontology_lookup_server'))
        disease_ch  = resolved.json.first()
        disease_csv = resolved.csv
    }

    def hsapdv_ch
    def hsapdv_csv
    if (params.hsapdv_json) {
        hsapdv_ch  = channel.value(file(params.hsapdv_json, checkIfExists: true))
        hsapdv_csv = sibling_csv(params.hsapdv_json)
    }
    else {
        def resolved = resolve_hsapdv_process(params.min_age, existing_dir('ontology_lookup_server'))
        hsapdv_ch  = resolved.json.first()
        hsapdv_csv = resolved.csv
    }

    // optional: the assays you want (an allow-list); every other assay is left out
    def assay_ch
    def assay_csv = channel.empty()
    if (params.assay_json) {
        assay_ch  = channel.value(file(params.assay_json, checkIfExists: true))
        assay_csv = sibling_csv(params.assay_json)
    }
    else if (params.assay) {
        def assays = params.assay instanceof List ? params.assay : params.assay.toString().split(',').collect { s -> s.trim() }
        def resolved = resolve_assay_process(channel.value(assays), existing_dir('ontology_lookup_server'))
        assay_ch  = resolved.json.first()
        assay_csv = resolved.csv
    }
    else {
        assay_ch = channel.value(file("${projectDir}/assets/NO_FILE"))
    }

    // ---- steps 1 to 3: the dataset list --------------------------------------------
    // The dataset list is a snapshot of the CellxGene API. Step 1 always asks the API; steps 2 and 3 do not
    // make their files again when they are already in data_dir and the API has not changed since. The
    // provenance file (the date, inside it, and the checksums of the files) goes on to step 4, which
    // records it in every dataset file.
    def complete_ch
    def snapshot_prov_ch
    def datasets_files = channel.value(file("${projectDir}/assets/NO_FILE"))
    if (params.all_datasets_complete_csv) {
        complete_ch = channel.value(file(params.all_datasets_complete_csv, checkIfExists: true))
        snapshot_prov_ch = channel.value(params.all_datasets_provenance
            ? file(params.all_datasets_provenance, checkIfExists: true)
            : file("${projectDir}/assets/NO_FILE"))
    }
    else {
        def fetched   = fetch_collections_process(existing_dir('cellxgene-datasets'))
        def generated = generate_metadata_process(fetched.json, fetched.provenance, existing_dir('cellxgene-datasets'))
        def appended  = append_details_process(generated.csv, generated.provenance, existing_dir('cellxgene-datasets'))
        complete_ch      = appended.csv
        snapshot_prov_ch = appended.provenance
        datasets_files    = fetched.json.mix(generated.csv, appended.csv, appended.provenance).collect()
    }

    // ---- step 4: filter the datasets -----------------------------------------------
    def filtered = filter_datasets_process(
        complete_ch, snapshot_prov_ch, uberon_ch, disease_ch, hsapdv_ch, assay_ch,
        params.organism ?: '', params.no_preprints ? true : false,
        params.author_cell_type ?: '', params.embedding ?: ''
    )

    // ---- step 5: count the cells, one task for each dataset ----------------------------
    def h5ad_ch = params.h5ad
        ? channel.value(file(params.h5ad, checkIfExists: true))
        : channel.value(file("${projectDir}/assets/NO_FILE"))
    def counted = count_cells_process(
        filtered.records.flatten(), uberon_ch, disease_ch, hsapdv_ch, assay_ch,
        h5ad_ch, params.h5ad_url_prefix ?: ''
    )

    // ---- step 5b: the gene id to gene name table of the GENCODE release ---------------------------
    def gencode_files = channel.value(file("${projectDir}/assets/NO_FILE"))
    if (params.build_gene_mapping) {
        def gene_mapping = build_gene_mapping_process(
            params.gene_mapping_gtf
                ? channel.value(file(params.gene_mapping_gtf, checkIfExists: true))
                : channel.value(file("${projectDir}/assets/NO_FILE")),
            existing_dir('gencode'))
        gencode_files = gene_mapping.csv.mix(gene_mapping.provenance).collect()
    }

    // ---- steps 6 and 7: gather, clean up, export ---------------------------------------
    def cleaned = final_cleanup_process(counted.record.toList(), folder_name)
    def exported = export_datasets_csv_process(cleaned.folder, csv_name)

    // ---- step 8: publish to a branch, for inspection and merge --------------------------
    if (params.github_token) {
        def stamp  = new java.text.SimpleDateFormat("yyyy-MMM-dd-HHmm").format(new Date()).toLowerCase()
        def branch = "${stamp}-${organ_slug}-cellxgene-harvester-nf"
        // the organ folder: the final JSON and CSV, and the organ's resolve files
        def organ_files  = exported.json.mix(exported.csv, uberon_ch, uberon_csv).collect()
        // ontology_lookup_server: the files shared by every organ
        def shared_files = disease_ch.mix(disease_csv, hsapdv_ch, hsapdv_csv)
            .mix(params.assay || params.assay_json ? assay_ch : channel.empty(), assay_csv)
            .collect()
        publish_github_process(
            organ_files, shared_files, gencode_files, datasets_files,
            counted.h5ad.collect().ifEmpty(file("${projectDir}/assets/NO_FILE")),
            branch, organ_slug
        )
    }
    else {
        log.warn "--github_token not set: the results are not published to GitHub"
    }
}
