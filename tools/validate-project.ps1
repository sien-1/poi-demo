$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$failures = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[string]]::new()

function Add-Pass {
    param([string]$Message)
    [void]$checks.Add("PASS`t$Message")
}

function Add-Fail {
    param([string]$Message)
    [void]$checks.Add("FAIL`t$Message")
    [void]$failures.Add($Message)
}

$htmlFiles = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.html" |
    Where-Object { $_.FullName -notmatch "\\.git\\" }

$brokenLinks = [System.Collections.Generic.List[string]]::new()
foreach ($file in $htmlFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($text, '(?:href|src)="([^"]+)"')) {
        $reference = $match.Groups[1].Value
        if ($reference -match '^(https?:|#|data:|javascript:|\?)') {
            continue
        }
        $cleanReference = ($reference -split '[?#]')[0]
        if ([string]::IsNullOrWhiteSpace($cleanReference)) {
            continue
        }
        $target = Join-Path $file.DirectoryName $cleanReference
        if (-not (Test-Path -LiteralPath $target)) {
            [void]$brokenLinks.Add("$($file.FullName) -> $reference")
        }
    }
}
if ($brokenLinks.Count -eq 0) {
    Add-Pass "local HTML links resolve"
}
else {
    foreach ($link in $brokenLinks) {
        Add-Fail "broken local link: $link"
    }
}

$duplicateIds = [System.Collections.Generic.List[string]]::new()
foreach ($file in $htmlFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $ids = [regex]::Matches($text, '\bid="([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value }
    foreach ($group in ($ids | Group-Object | Where-Object Count -gt 1)) {
        [void]$duplicateIds.Add("$($file.FullName): #$($group.Name)")
    }
}
if ($duplicateIds.Count -eq 0) {
    Add-Pass "HTML ids are unique per page"
}
else {
    foreach ($duplicate in $duplicateIds) {
        Add-Fail "duplicate HTML id: $duplicate"
    }
}

$surveyJs = Get-Content -LiteralPath (Join-Path $root "survey.js") -Raw
$surveyFullJs = Get-Content -LiteralPath (Join-Path $root "survey-full.js") -Raw
$doctorJs = Get-Content -LiteralPath (Join-Path $root "v021\doctor\doctor.js") -Raw

if ($surveyJs -match "CMSS|COX 痛经症状量表" -or $surveyFullJs -match "CMSS|COX 痛经症状量表") {
    Add-Fail "CMSS remains in survey configuration"
}
else {
    Add-Pass "CMSS is absent from survey configuration"
}

if ($surveyJs -match "Kupperman 原版 11 项" -or $surveyFullJs -match "11 项与 13 项") {
    Add-Fail "Kupperman 11-item version remains"
}
else {
    Add-Pass "Kupperman 11-item version is absent"
}

if ($surveyJs -match "Kupperman 13 项" -and $surveyFullJs -match "Kupperman 13 项量表") {
    Add-Pass "Kupperman 13-item version is retained"
}
else {
    Add-Fail "Kupperman 13-item configuration is incomplete"
}

if ($surveyJs -match "MMSE|MoCA" -or $surveyFullJs -match "MMSE|MoCA") {
    Add-Fail "MMSE or MoCA appears in patient/research questionnaire configuration"
}
else {
    Add-Pass "MMSE and MoCA are excluded from patient questionnaire configuration"
}

if ($doctorJs -match "MMSE" -and $doctorJs -match "MoCA") {
    Add-Pass "MMSE and MoCA are present in the doctor workspace"
}
else {
    Add-Fail "doctor cognitive assessment entries are incomplete"
}

$questionNumbers = [regex]::Matches(
    $surveyFullJs,
    'question\(\s*"[^"]+"\s*,\s*"(\d+)"',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
) | ForEach-Object { [int]$_.Groups[1].Value }

$expectedNumbers = 1..41
$duplicateNumbers = $questionNumbers | Group-Object | Where-Object Count -gt 1
$missingNumbers = Compare-Object $questionNumbers $expectedNumbers |
    Where-Object SideIndicator -eq "=>" |
    ForEach-Object InputObject
$extraNumbers = Compare-Object $questionNumbers $expectedNumbers |
    Where-Object SideIndicator -eq "<=" |
    ForEach-Object InputObject

if ($duplicateNumbers.Count -eq 0 -and $missingNumbers.Count -eq 0 -and $extraNumbers.Count -eq 0) {
    Add-Pass "questionnaire numbers are continuous from 1 to 41"
}
else {
    Add-Fail "questionnaire numbering mismatch; duplicate=[$($duplicateNumbers.Name -join ',')] missing=[$($missingNumbers -join ',')] extra=[$($extraNumbers -join ',')]"
}

$requiredBackendFiles = @(
    "backend\server.ps1",
    "backend\start.ps1",
    "backend\test-api.ps1",
    "backend\README.md",
    "backend\API.md",
    "backend\data\demo-seed.json",
    "backend\lib\http.ps1",
    "backend\lib\auth.ps1",
    "backend\lib\access.ps1",
    "backend\lib\resources.ps1",
    "backend\lib\batches.ps1"
)
$missingBackendFiles = @(
    $requiredBackendFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) }
)
if ($missingBackendFiles.Count -eq 0) {
    Add-Pass "backend MVP required files exist"
}
else {
    Add-Fail "backend MVP files missing: $($missingBackendFiles -join ', ')"
}

try {
    $seedJson = Get-Content -LiteralPath (Join-Path $root "backend\data\demo-seed.json") -Raw |
        ConvertFrom-Json
    $seedCountsValid =
        @($seedJson.patients).Count -eq 10 -and
        @($seedJson.organizations).Count -eq 2 -and
        @($seedJson.departments).Count -eq 3 -and
        @($seedJson.visits).Count -eq 30
    if ($seedCountsValid) {
        Add-Pass "backend synthetic seed has expected coverage"
    }
    else {
        Add-Fail "backend synthetic seed coverage is incomplete"
    }
}
catch {
    Add-Fail "backend synthetic seed is not valid JSON: $($_.Exception.Message)"
}

$backendTestOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "backend\test-api.ps1") 2>&1
if ($LASTEXITCODE -eq 0) {
    Add-Pass "backend HTTP acceptance tests pass"
}
else {
    $backendTestOutput | ForEach-Object { Write-Output $_ }
    Add-Fail "backend HTTP acceptance tests failed"
}

$checks | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "SUMMARY`tchecks=$($checks.Count - $failures.Count) passed, $($failures.Count) failed"

if ($failures.Count -gt 0) {
    exit 1
}
