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

The `bump-version` job deliberately skips reruns (`gh-run-attempt != '1'`), so
rerunning a failed release cannot regenerate missing release notes or restart its
dependent publishing jobs. Rerunning also does not necessarily load a newer
revision of the reusable workflow.

If the release tag exists but publishing has not started:

1. Fix the failing step in this repository before making another release.
2. Keep the existing version commit and tag; do not delete or move a public tag,
   or run the version bump again to recover the same version.
3. Prepare a separate, manually dispatched recovery workflow that checks out the
   existing release tag, bypasses version/tag mutation, and supplies the original
   `new_tag` and `version` outputs to the downstream jobs.
4. Generate `CHANGELOG_increment.md` using the release template and the range
   from the previous stable tag to the existing release tag, for example:
   ```bash
   ./git-chglog --template .chglog/RELEASE.tpl.md --output CHANGELOG_increment.md "v0.2.0..v0.3.0"
   ```
   Upload it as the `CHANGELOG_increment` artifact expected by the publishing job.
5. Ensure all downstream checkouts use the existing release tag rather than a
   branch that may have advanced. Build the required executable and benchmark
   artifacts, then publish and update documentation through the remaining jobs.

The recovery workflow described above is not currently provided by
`release-impl.yml`; it must be prepared and reviewed before dispatch. If either
GitHub or PyPI already has the version, inspect that publication before proceeding
to avoid duplicate uploads or replacing existing release assets.
