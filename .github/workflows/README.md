These are callable workflows used by the rest of the hpcflow organisation.

To use one, put something like this in your _Github Actions_ workfow:

```
jobs:
  some-name:
    uses: hpcflow/github-support/.github/workflows/the-workflow-name.yml@0.5
    with:
      argument-1: argument-value
      argument-2: ...
```

> [!IMPORTANT]
> Note that these are _not_ hpcflow/matflow workflows. They are _used by_ hpcflow and matflow to implement their development automation.

> [!CAUTION]
> These workflows **must** be placed in this folder in order to function correctly.

## Recovering a partially completed release

The `release-impl.yml` workflow pushes the version commit and tag before generating
the incremental release notes. A failure after that push does not roll back those
changes. Check the remote branch, tag, GitHub release, and PyPI version before
attempting recovery.

In normal release mode, the `bump-version` job deliberately skips reruns
(`gh-run-attempt != '1'`), so
rerunning a failed release cannot regenerate missing release notes or restart its
dependent publishing jobs. Rerunning also does not necessarily load a newer
revision of the reusable workflow.

If the release tag exists but publishing has not started:

1. Fix the failing step in this repository before making another release.
2. Keep the existing version commit and tag; do not delete or move a public tag,
   or run the version bump again to recover the same version.
3. Call `release-impl.yml` from a `workflow_dispatch` workflow with `recovery-tag`
   set to the existing stable tag (for example `v0.3.0`) and
   `recovery-previous-tag` set to the previous stable tag (`v0.2.0`).
   Pass the stable branch as `pr-base-ref` and the pre-release branch as
   `pr-head-ref`, along with the usual application inputs and secrets.
   Set `pr-merged` to `"false"`; recovery does not require a PR merge.
4. Review and explicitly confirm publication in the caller before dispatching.
   Use the same concurrency group as normal releases to prevent overlap.

Recovery validates that both tags exist, the previous tag strictly precedes the
release tag, the release commit belongs to the stable branch, and its Poetry
package version matches the tag. It supports stable `vX.Y.Z` tags and the
production PyPI or TestPyPI upload URLs only. It rejects existing GitHub releases
(including drafts visible to the token), existing PyPI versions, and API errors.
It is not a general resume mechanism for partially published versions.

After validation, recovery checks out the resolved release **commit SHA** for app
data caching, executable builds, benchmarks, package builds, and documentation.
It generates the `CHANGELOG_increment` artifact with only the two selected tags
visible to git-chglog and requests the recovery tag alone. This excludes the
previous release and combines changes across intervening prereleases, without
deleting any tags. It then runs the existing build/publish jobs. Version bumping,
tag creation, application repository pushes, and branch rebases are skipped.
Binary links are written only to the documentation build checkout; the website
repository is still updated, including the stable documentation symlink.

Recovery can be rerun if it fails **before publication**. If either GitHub or PyPI
already has the version, inspect that publication and finish the remaining work
separately; the preflight will refuse another recovery run. Do not delete a
publication merely to bypass this safeguard.

The app-data caching step authenticates GitHub downloads using
`FSSPEC_GITHUB_USERNAME` and `FSSPEC_GITHUB_TOKEN` with the caller's
`general-token`. This avoids the shared runner IP's unauthenticated API quota.
Using `GH_TOKEN` alone is insufficient for application versions that only read it
while running tests.
