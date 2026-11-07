# Fixture for strict-list-check.ps1: no Set-StrictMode, so nothing here is checked or run.
function Get-None { }
$bare = Get-None
$bare.Count
