param([Parameter(Mandatory = $true)][string]$FlutterExecutable)
$ErrorActionPreference = 'Stop'
$gestureplayFlutterArguments = @(ConvertFrom-Json $env:GESTUREPLAY_FLUTTER_ARGUMENTS)
& $FlutterExecutable @gestureplayFlutterArguments
exit $LASTEXITCODE
