# Logging

The Server Configuration Manager comes with integrated logging to the Windows Eventlog.
Upon import / launch it will register its own application eventlog if not yet present, including 4 different souces:

|ScmLauncher|Events written by the launcher before the SCM module executes|
|ScmExecution|Events written by the SCM module itself, but not the Actions executed|
|ScmAction|Events written by the individual Actions|
|ScmDebug|Events written by anybody that are mostly intended for debug purposes and not relevant to actual execution success or failure|

To write log entries, use the `Write-ScmLog` function.
All actions should generate errors when the execution script fails.

> Note: Passing any error records to the functions `-ErrorRecord` parameter will generate a second eventlog entry - a warning - with a processed message content, displaying the error record as useful as possible for debugging purposes.
> Be sure to not pass on errors that can contain secrets or otherwise sensitive information.
