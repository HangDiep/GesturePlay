param([string]$ProjectDirectory)
$ErrorActionPreference = 'Stop'
if (-not $ProjectDirectory) { $ProjectDirectory = Join-Path $PSScriptRoot '..\flutter_app' }
$projectPath = [IO.Path]::GetFullPath($ProjectDirectory)
$manifestPath = Join-Path $projectPath '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $manifestPath)) { exit 0 }
$pluginManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$linkDirectory = Join-Path $projectPath 'windows\flutter\ephemeral\.plugin_symlinks'
New-Item -ItemType Directory -Path $linkDirectory -Force | Out-Null
foreach ($plugin in $pluginManifest.plugins.windows) {
    if ($plugin.name -notmatch '^[a-z0-9_]+$') { throw 'Invalid plugin name.' }
    $targetPath = [IO.Path]::GetFullPath($plugin.path)
    if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) { throw "Missing Flutter plugin: $($plugin.name)" }
    $linkPath = Join-Path $linkDirectory $plugin.name
    if (-not (Test-Path -LiteralPath $linkPath)) {
        # Directory junctions work without changing Windows Developer Mode.
        # Links stay in Flutter's ignored, generated directory; package sources are read only.
        New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
    }
}
