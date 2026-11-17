param(
    [int]$Port = 8765
)

& (Join-Path $PSScriptRoot "server.ps1") -Port $Port
