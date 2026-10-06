# crap-gate 1
#
# CRAP gate. Everything project-specific lives in the repository's .config/crap-exceptions.json.
#
# Score of a method: CC^2 * (1 - line coverage)^3 + CC, read from the coverlet Cobertura reports found
# under -CoverageRoot (cyclomatic complexity and line hits). Several reports are merged: a line is covered
# when any report hit it. A method above the threshold fails unless the exceptions file admits it with a
# reason and a complexity ceiling. Left out as generated code: Razor BuildRenderTree, lambdas and their
# closure classes, files under obj/, *.g.cs, *.g.i.cs, *.Designer.cs and EF Core Migrations/. An async or
# iterator state machine (Type/<Name>d__N.MoveNext) is scored under its source method's name.
#
# Exceptions file:
#   { "exceptions":    [ { "method": "Namespace.Type::Method", "complexity": 40, "reason": "..." } ],
#     "excludedFiles": [ { "pattern": "*/Localization/PluralRules.cs", "reason": "..." } ] }
# An exception that no longer serves, or whose ceiling is above the method's complexity, fails the gate,
# and so does an excluded-file pattern that matches no scored file: the list only ever shrinks to the truth.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CoverageRoot,
    [string]$ExceptionsPath,
    [double]$Threshold = 30,
    # Writes the method scores to this CSV, for review; the gate itself never reads it.
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$invariant = [Globalization.CultureInfo]::InvariantCulture

$resolvedRoot = Resolve-Path -LiteralPath $CoverageRoot
if (-not $ExceptionsPath) {
    $ExceptionsPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.config\crap-exceptions.json'
}
$reports = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.cobertura*.xml' |
    Where-Object FullName -NotMatch '[\\/](In|Out)[\\/]')
if ($reports.Count -eq 0) {
    throw "No Cobertura report under ${resolvedRoot}: coverage was not collected, the gate cannot score anything."
}

# The identity of a method, or $null for generated code.
function Get-MethodKey([string]$className, [string]$methodName) {
    if ($methodName -eq 'BuildRenderTree') { return $null }
    $owner = $className
    $name = $methodName
    $nested = $className.IndexOf('/')
    if ($nested -ge 0) {
        $owner = $className.Substring(0, $nested)
        $inner = $className.Substring($nested + 1)
        # Closure classes (<>c, <>c__DisplayClass) hold lambda bodies: generated.
        if ($inner.StartsWith('<>c')) { return $null }
        if ($inner -match '^<(?<source>[^>]+)>d__\d+$') {
            if ($Matches.source -like '*b__*') { return $null }
            $name = $Matches.source
        }
        else {
            $owner = $className
        }
    }
    # Lambdas compiled into the type itself.
    if ($name -match '^<[^>]*>b__') { return $null }
    # Local functions: <Outer>g__Inner|n_m, scored as Outer.Inner.
    if ($name -match '^<(?<outer>[^>]+)>g__(?<inner>[^|]+)\|') { $name = "$($Matches.outer).$($Matches.inner)" }
    return "${owner}::$name"
}

function Test-GeneratedFile([string]$file) {
    $path = $file.Replace('\', '/')
    return ($path -match '(^|/)obj/' -or $path -match '\.(g|g\.i|Designer)\.cs$' -or $path -match '(^|/)Migrations/')
}

$exceptions = @()
$excludedFiles = @()
if (Test-Path -LiteralPath $ExceptionsPath) {
    $config = Get-Content -LiteralPath $ExceptionsPath -Raw | ConvertFrom-Json
    if ($config.PSObject.Properties['exceptions']) { $exceptions = @($config.exceptions | Where-Object { $_ }) }
    if ($config.PSObject.Properties['excludedFiles']) { $excludedFiles = @($config.excludedFiles | Where-Object { $_ }) }
}

$failures = [Collections.Generic.List[string]]::new()
foreach ($excluded in $excludedFiles) {
    if ([string]::IsNullOrWhiteSpace([string]$excluded.pattern)) { $failures.Add('An excluded file names no pattern.'); continue }
    if ([string]::IsNullOrWhiteSpace([string]$excluded.reason)) { $failures.Add("Excluded file '$($excluded.pattern)' has no reason.") }
}
$excludedUsed = @{}

# Method key -> merged figures across every report.
$methods = @{}
foreach ($report in $reports) {
    [xml]$coverage = Get-Content -LiteralPath $report.FullName -Raw
    foreach ($class in @($coverage.coverage.packages.package.classes.class)) {
        if ($null -eq $class) { continue }
        $file = [string]$class.filename
        if (Test-GeneratedFile $file) { continue }
        $skip = $false
        foreach ($excluded in $excludedFiles) {
            if ($excluded.pattern -and $file.Replace('\', '/') -like ([string]$excluded.pattern).Replace('\', '/')) {
                $excludedUsed[[string]$excluded.pattern] = $true
                $skip = $true
            }
        }
        if ($skip) { continue }
        foreach ($method in @($class.methods.method)) {
            if ($null -eq $method) { continue }
            $key = Get-MethodKey ([string]$class.name) ([string]$method.name)
            if ($null -eq $key) { continue }
            $lines = @($method.lines.line | Where-Object { $_ })
            if ($lines.Count -eq 0) { continue }
            $complexity = [double]::Parse([string]$method.complexity, $invariant)
            if (-not $methods.ContainsKey($key)) {
                $methods[$key] = @{ File = $file; Line = [int]$lines[0].number; Complexity = $complexity; Lines = @{} }
            }
            $entry = $methods[$key]
            $entry.Complexity = [Math]::Max($entry.Complexity, $complexity)
            foreach ($line in $lines) {
                $number = "$file#$($line.number)"
                $hit = [long]$line.hits -gt 0
                $entry.Lines[$number] = [bool]$entry.Lines[$number] -or $hit
            }
        }
    }
}

foreach ($excluded in $excludedFiles) {
    if ($excluded.pattern -and -not $excludedUsed.ContainsKey([string]$excluded.pattern)) {
        $failures.Add("Excluded file '$($excluded.pattern)' matches no scored file: remove it.")
    }
}

$entries = @(foreach ($key in $methods.Keys) {
    $m = $methods[$key]
    $valid = $m.Lines.Count
    $covered = @($m.Lines.Values | Where-Object { $_ }).Count
    $uncovered = 1 - ($covered / $valid)
    [pscustomobject]@{
        Key        = $key
        File       = $m.File
        Line       = $m.Line
        Complexity = $m.Complexity
        Coverage   = $covered / $valid
        Score      = ($m.Complexity * $m.Complexity * [Math]::Pow($uncovered, 3)) + $m.Complexity
    }
})
if ($entries.Count -eq 0) {
    throw 'The coverage reports hold no scorable method.'
}

if ($ReportPath) {
    $entries | Sort-Object Score -Descending | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding utf8
}

$byKey = @{}
foreach ($exception in $exceptions) {
    if ([string]::IsNullOrWhiteSpace([string]$exception.method)) {
        $failures.Add('An exception names no method.')
        continue
    }
    if ($byKey.ContainsKey($exception.method)) {
        $failures.Add("$($exception.method) is admitted twice.")
    }
    $byKey[$exception.method] = $exception
    if ([string]::IsNullOrWhiteSpace([string]$exception.reason)) {
        $failures.Add("$($exception.method) is admitted without a reason.")
    }
}

$used = @{}
foreach ($entry in $entries | Where-Object Score -gt $Threshold | Sort-Object Score -Descending) {
    $exception = $byKey[$entry.Key]
    $where = "$($entry.File):$($entry.Line)"
    if ($null -eq $exception) {
        $failures.Add(('{0} scores {1:N1} (complexity {2}, lines covered {3:P0}) above {4}, {5}: split it or cover it.' -f
            $entry.Key, $entry.Score, $entry.Complexity, $entry.Coverage, $Threshold, $where))
        continue
    }
    $used[$entry.Key] = $entry.Complexity
    if ($entry.Complexity -gt [double]$exception.complexity) {
        $failures.Add("$($entry.Key) grew to complexity $($entry.Complexity), above its admitted ceiling $($exception.complexity), ${where}.")
    }
}

foreach ($exception in $exceptions | Where-Object { $_.method }) {
    if (-not $used.ContainsKey($exception.method)) {
        $failures.Add("$($exception.method) no longer scores above $Threshold (or is gone): remove its exception.")
    }
    elseif ($used[$exception.method] -lt [double]$exception.complexity) {
        $failures.Add("$($exception.method) is down to complexity $($used[$exception.method]): lower its ceiling from $($exception.complexity).")
    }
}

if ($failures.Count -gt 0) {
    throw ("CRAP gate failed ($($failures.Count)):`n  " + ($failures -join "`n  "))
}

Write-Host ("CRAP gate passed: {0} methods scored from {1} report(s), none above {2} outside the {3} justified exception(s) and {4} excluded file pattern(s)." -f
    $entries.Count, $reports.Count, $Threshold, $exceptions.Count, $excludedFiles.Count) -ForegroundColor Green
