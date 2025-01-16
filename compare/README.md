# Compare program output to a string

Compare the output of a program to a string given as a parameter.
A single trailing newline will be ignored.
The command is run by bash on Linux and macOS, and by PowerShell on Windows.

The action is successful if the output of `command` is equal to `expected`.

## Inputs

* `command`

  The command to get the output of for comparison. **Required.**

  Example: `echo Foo Bar`

* `expected`

  The string that the output is expected to equal. **Required.**

  Example: `Foo Bar`

* `init`

  Extra initialisation code to run before the command to compare. **Optional.**

  Example: `source someScript.sh`

## Outputs

None.
