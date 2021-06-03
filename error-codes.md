# Error Codes

## Description

This solution will [log to the Windows Eventlog](logging.html).
As part of its regular execution, it will generate error records if something fails.

The primary record to monitor for execution failure is:

```text
Eventlog: ServerConfigurationManager
Souce:    ScmExecution
Event ID: 666
```

More detailed error codes will also be generated to give better insights, into what went wrong:

## Codes

> Application | Application

|666|Generated when unable to deploy logging itself.|

> ServerConfigurationManager | ScmLauncher

|666|General Launcher Error - each other error ALSO triggers this error.|
|700|Failed to deploy nuget binaries|
|701|Failed to update PSRepository|
|702|Failed to register PSRepository|
|703|Repository not found (triggers in edge cases where the previous commands fail to cause an exception)|
|720|Error creating config folder in the current user's LocalAppData folder. This would happen if there is a fundamental problem accessing environment variables.|
|721|Failed to write repository configuration file. Could happen if the file is locked or antivirus interferes.|
|800|Error installing the latest version of ServerConfigurationManager|

> ServerConfigurationManager | ScmExecution

|ID|Description|
|---|---|
|404|The Content Path - the network location from which data sets are being loaded - does not exist or is malformed. Review the setup documentation and ensure network connectivity|
|405|The name of the PowerShell Repository could not be validated. This happens if for whatever reason the repository does not exist, though it should have been created during launcher. This will usually only happen when a concurrent action outside of this process removed it or this module was not launched from the launcher that ensures repository registration.|
|500|Failed to import an actions file. This happens when an action script has an internal execution error or possibly a syntax error|
|501|Failed to import a targets file. This happens when a target script has an internal execution error or possibly a syntax error|
|666|Overall configuration invocation failed. There are guaranteed to also be other errors logged, this event is generated to have a generalized failure event.|
|2002|Error executing a target script. This happens when target processing code has encountered an error. Target scripts should not throw exceptions, this will need a code fix.|
|2203|Error loading configuration file. This happens when creating a malformed configuration file or including unsafe executable code in it|
|5000|Invalid Configuration Entry, Name is missing. This happens when defining a configuration entry without a Name property.|
|5001|Invalid Configuration Entry, Action is missing. This happens when defining a configuration entry without an Action property.|
|5003|Action not found. This happens when configuring an Action but not providing an Action of that name. Ensure spelling is correct and the action is loaded as intended.|
|5004|Missing mandatory parameter. This error happens when the configuration entry does not provide all parameters needed for the selected Action. Validate needed parameters and ensure they are provided. This error could happen if an Action is updated later on with new required parameters.|
|5005|Dependency not met. A configuration entry whose dependencies are not met cannot execute. Ensure the configuration entries are properly sorted and figure out why the depended on configuration entry was not successful.|
|5006|Error executing the test before applying the action. This should not happen and indicates a coding issue inside of the Action validation code|
|5008|Error executing Action execution code. This should not happen and indicates a coding issue inside of the Action execution code|
|5009|Error executing the test after applying the action. This should not happen and indicates a coding issue inside of the Action validation code|
|5011|Test unsuccessful after executing the Action code. This may require further debugging with the parameters specified and the Action code|
