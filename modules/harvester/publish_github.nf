/**
 * Publish Module (step 8)
 *
 * Copies every JSON and CSV file of the run to a NEW branch of the GitHub
 * repository (default NIH-NLM/nlm-ckn), for you to inspect and merge by hand.
 * Nothing is pushed to main.
 *
 * Branch:  {YYYY-mon-DD}-{HHmm}-{organ}-cellxgene-harvester-nf
 *          for example 2026-oct-07-1415-kidney-cellxgene-harvester-nf
 *
 * Folders (publish_env = prod, the default):
 *   data/prod/{organ}/cellxgene-harvester-nf/            the JSON and CSV files
 *   The filtered h5ad files go to the public S3 bucket, not to GitHub.
 *
 * Folders (publish_env = test):
 *   data/test/{organ}/cellxgene-harvester-nf/            the JSON and CSV files
 *   data/test/{organ}/filtered-h5ad/                     the filtered h5ad files
 *
 * The step is skipped, with a warning, when github_token is not given.
 *
 * Input:
 * ------
 * @param files:  the JSON and CSV files and the folder of dataset files of the run
 * @param h5ad:   the filtered h5ad files (copied only when publish_env is test)
 * @param branch: name of the branch to create
 * @param organ:  organ slug, for example 'kidney'
 *
 * Output:
 * -------
 * @emit report: publish_report.txt (branch and folders)
 */
process publish_github_process {
    tag "publish_${organ}"
    maxForks 1
    errorStrategy 'ignore'

    input:
    path files, stageAs: 'run/*'
    path h5ad,  stageAs: 'h5ad/*'
    val branch
    val organ

    output:
    path "publish_report.txt", emit: report

    script:
    def repo      = params.publish_repo
    def json_dir  = params.publish_dest_dir ?: "data/${params.publish_env}/${organ}/cellxgene-harvester-nf"
    def h5ad_dir  = "data/test/${organ}/filtered-h5ad"
    def copy_h5ad = params.publish_env == 'test'
    def repo_url  = repo.contains('://') ? repo : "https://\${GITHUB_TOKEN}@github.com/${repo}.git"   // a full address is for tests
    """
    export GITHUB_TOKEN="${params.github_token}"

    git clone --depth 1 ${repo_url} publish-repo
    cd publish-repo
    git config user.email "cellxgene-harvester-nf@noreply.github.com"
    git config user.name  "cellxgene-harvester-nf"
    git checkout -b ${branch}

    mkdir -p "${json_dir}"
    cp -rL ../run/* "${json_dir}/"
    ${copy_h5ad ? """
    mkdir -p "${h5ad_dir}"
    cp -L ../h5ad/*.h5ad "${h5ad_dir}/" 2>/dev/null || true""" : ''}

    git add data/
    git commit -m "cellxgene-harvester-nf: ${organ} ${params.publish_env} results (${branch})"
    git push origin ${branch}

    echo "branch : ${branch}"   >  ../publish_report.txt
    echo "repo   : ${repo}"     >> ../publish_report.txt
    echo "folder : ${json_dir}" >> ../publish_report.txt
    """

    stub:
    """
    echo "stub: would publish ${organ} to ${branch}" > publish_report.txt
    """
}
