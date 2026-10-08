# Coverage gate: fails when the library's line or branch coverage falls under its floor.
#
# Reads exactly one Cobertura report under -CoverageRoot: the merged report of the launcher
# (TestResults/CoverageReport/Cobertura.xml) or the single suite's report in CI. Several reports are refused
# rather than summed, since two suites covering the same library would count its lines twice.
# The floors below are the only definition: the launcher and CI call the script without overriding them.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CoverageRoot,
    [double]$MinLine = 95,
    [double]$MinBranch = 85
)

$ErrorActionPreference = 'Stop'

$reports = @(Get-ChildItem -LiteralPath (Resolve-Path -LiteralPath $CoverageRoot) -Recurse -File -Filter '*.xml' |
    Where-Object { $_.Name -match 'cobertura' -and $_.FullName -notmatch '[\\/](In|Out)[\\/]' })
if ($reports.Count -ne 1) {
    throw "Expected one Cobertura report under ${CoverageRoot}, found $($reports.Count): merge them before the gate."
}

$coverage = ([xml](Get-Content -LiteralPath $reports[0].FullName -Raw)).coverage
$results = foreach ($measure in @(
        @{ Name = 'Line'; Covered = [long]$coverage.'lines-covered'; Valid = [long]$coverage.'lines-valid'; Floor = $MinLine },
        @{ Name = 'Branch'; Covered = [long]$coverage.'branches-covered'; Valid = [long]$coverage.'branches-valid'; Floor = $MinBranch })) {
    if ($measure.Valid -le 0) { throw "The report has no measurable $($measure.Name.ToLowerInvariant())." }
    $rate = 100.0 * $measure.Covered / $measure.Valid
    [pscustomobject]@{ Name = $measure.Name; Rate = $rate; Covered = $measure.Covered; Valid = $measure.Valid; Floor = $measure.Floor; Passed = $rate -ge $measure.Floor }
}

foreach ($result in $results) {
    Write-Host ("{0} coverage: {1:N2}% ({2}/{3}), floor {4}%: {5}" -f $result.Name, $result.Rate, $result.Covered, $result.Valid, $result.Floor,
        $(if ($result.Passed) { 'passed' } else { 'FAILED' }))
}
if (@($results | Where-Object { -not $_.Passed }).Count -gt 0) {
    Write-Host 'Coverage gate failed.' -ForegroundColor Red
    exit 1
}
Write-Host 'Coverage gate passed.'
exit 0
