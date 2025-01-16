These are callable workflows used by the rest of the hpcflow organisation.

To use one, put something like this in your _Github Actions_ workfow:

```
jobs:
  some-name:
    uses: hpcflow/github-support/.github/workflows/the-workflow-name.yml@main
    with:
      argument-1: argument-value
      argument-2: ...
```

> [!IMPORTANT]
> Note that these are _not_ hpcflow/matflow workflows. They are _used by_ hpcflow and matflow to implement their development automation.

> [!CAUTION]
> These workflows **must** be placed in this folder in order to function correctly.
