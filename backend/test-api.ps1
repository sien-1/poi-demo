$ErrorActionPreference = "Stop"

function Invoke-RawHttpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,
        [Parameter(Mandatory = $true)]
        [string]$Method,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$Token = "",
        [string]$Body = ""
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect("127.0.0.1", $Port)
        $stream = $client.GetStream()
        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($Body)
        $headers = @(
            "$Method $Path HTTP/1.1",
            "Host: 127.0.0.1:$Port",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: $($bodyBytes.Length)",
            "Connection: close"
        )
        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $headers += "X-Demo-Token: $Token"
        }
        $headerText = ($headers -join "`r`n") + "`r`n`r`n"
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($headerText)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        if ($bodyBytes.Length -gt 0) {
            $stream.Write($bodyBytes, 0, $bodyBytes.Length)
        }
        $stream.Flush()

        $memory = New-Object System.IO.MemoryStream
        $buffer = New-Object byte[] 4096
        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) {
                break
            }
            $memory.Write($buffer, 0, $read)
        }

        $allBytes = $memory.ToArray()
        $allText = [Text.Encoding]::ASCII.GetString($allBytes)
        $delimiter = $allText.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
        if ($delimiter -lt 0) {
            throw "服务返回的 HTTP 响应缺少响应头终止符。"
        }
        $responseHeaders = $allText.Substring(0, $delimiter) -split "`r`n"
        $statusCode = [int]($responseHeaders[0].Split(" ")[1])
        $bodyStart = $delimiter + 4
        $jsonBody = if ($allBytes.Length -gt $bodyStart) {
            [Text.Encoding]::UTF8.GetString($allBytes, $bodyStart, $allBytes.Length - $bodyStart)
        }
        else {
            ""
        }
        $objectBody = if ([string]::IsNullOrWhiteSpace($jsonBody)) { $null } else { $jsonBody | ConvertFrom-Json }

        return [pscustomobject]@{
            StatusCode = $statusCode
            Body = $objectBody
            RawBody = $jsonBody
        }
    }
    finally {
        $client.Close()
        $client.Dispose()
    }
}

function Add-TestResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [bool]$Passed,
        [string]$Detail = ""
    )

    $script:testResults += [pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Detail = $Detail
    }
}

$script:testResults = @()
$probe = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$probe.Start()
$port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
$probe.Stop()

$serverScript = Join-Path $PSScriptRoot "server.ps1"
$seedPath = Join-Path $PSScriptRoot "data\demo-seed.json"
$serverProcess = Start-Process -FilePath "powershell.exe" `
    -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $serverScript,
        "-Port",
        $port,
        "-DataPath",
        $seedPath
    ) `
    -PassThru `
    -WindowStyle Hidden

try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        try {
            $health = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/health"
            if ($health.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
        }
        Start-Sleep -Milliseconds 150
    }
    if (-not $ready) {
        throw "后端未能在测试端口启动。"
    }

    Add-TestResult "health endpoint returns ok" ($health.StatusCode -eq 200 -and $health.Body.status -eq "ok")

    $noToken = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/me"
    Add-TestResult "missing demo token is rejected" ($noToken.StatusCode -eq 401 -and $noToken.Body.error.code -eq "UNAUTHORIZED")

    $metadata = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/metadata" -Token "doctor-c001"
    Add-TestResult "metadata exposes storage boundary" (
        $metadata.StatusCode -eq 200 -and
        $metadata.Body.storageMode -eq "synthetic-in-memory" -and
        $metadata.Body.productionStorageRequired -eq "PostgreSQL"
    )

    $pageOne = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients?page=1&pageSize=2" -Token "doctor-c001"
    $pageTwo = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients?page=2&pageSize=2" -Token "doctor-c001"
    $pageOneIds = @($pageOne.Body.items | ForEach-Object { $_.patientId })
    $pageTwoIds = @($pageTwo.Body.items | ForEach-Object { $_.patientId })
    $overlap = @($pageOneIds | Where-Object { $_ -in $pageTwoIds })
    Add-TestResult "patient pagination is stable and non-overlapping" (
        $pageOne.Body.meta.total -eq 4 -and
        @($pageOne.Body.items).Count -eq 2 -and
        @($pageTwo.Body.items).Count -eq 2 -and
        $overlap.Count -eq 0
    ) "total=$($pageOne.Body.meta.total), overlap=$($overlap.Count)"

    $patientFields = @($pageOne.Body.items[0].PSObject.Properties.Name)
    $sensitiveFieldNames = @("name", "phone", "idNumber", "idCard", "address")
    $sensitiveLeak = @($patientFields | Where-Object { $_ -in $sensitiveFieldNames })
    Add-TestResult "patient list omits direct identity fields" ($sensitiveLeak.Count -eq 0)

    $crossDoctor = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-003" -Token "doctor-c001"
    Add-TestResult "doctor cannot read another doctor's patient" (
        $crossDoctor.StatusCode -eq 404 -and
        $crossDoctor.Body.error.code -eq "NOT_FOUND"
    )

    $crossDepartment = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-003" -Token "dept-admin-endo"
    $sameDepartment = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-003" -Token "dept-admin-repro"
    Add-TestResult "department administrator is constrained to own department" (
        $crossDepartment.StatusCode -eq 404 -and
        $sameDepartment.StatusCode -eq 200
    )

    $crossHospital = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-001" -Token "hospital-admin-h2"
    Add-TestResult "hospital administrator cannot cross organizations" ($crossHospital.StatusCode -eq 404)

    $patientCrossRead = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-003" -Token "patient-p001"
    Add-TestResult "patient cannot enumerate another patient" ($patientCrossRead.StatusCode -eq 404)

    $patientTasks = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/tasks?pageSize=100" -Token "patient-p001"
    $patientTaskIds = @($patientTasks.Body.items | ForEach-Object { $_.taskId })
    Add-TestResult "patient task response only contains own tasks" (
        $patientTasks.StatusCode -eq 200 -and
        $patientTaskIds.Count -eq 2 -and
        "TASK-001" -in $patientTaskIds -and
        "TASK-002" -in $patientTaskIds -and
        "TASK-003" -notin $patientTaskIds
    )

    $searchTasks = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/tasks?q=TASK-003&pageSize=100" -Token "doctor-c001"
    Add-TestResult "staff task search filters before pagination" (
        $searchTasks.StatusCode -eq 200 -and
        $searchTasks.Body.meta.total -eq 1 -and
        $searchTasks.Body.items[0].taskId -eq "TASK-003"
    )

    $completedAgain = Invoke-RawHttpRequest -Port $port -Method "POST" -Path "/api/v1/tasks/TASK-002/complete" -Token "patient-p001" -Body "{}"
    Add-TestResult "task completion is safely idempotent" (
        $completedAgain.StatusCode -eq 200 -and
        $completedAgain.Body.alreadyCompleted -eq $true
    )

    $bundle = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/questionnaires/BUNDLE-002" -Token "patient-p001"
    Add-TestResult "patient questionnaire is returned under a neutral title" (
        $bundle.StatusCode -eq 200 -and
        $bundle.Body.title -eq "健康随访问卷" -and
        @($bundle.Body.items).Count -eq 3
    )

    $submitBody = @{
        answers = @(
            @{ questionId = "KUP-01"; value = "1" },
            @{ questionId = "KUP-02"; value = "2" },
            @{ questionId = "SLEEP-01"; value = "1" }
        )
    } | ConvertTo-Json -Depth 5 -Compress
    $submitted = Invoke-RawHttpRequest -Port $port -Method "POST" -Path "/api/v1/questionnaires/BUNDLE-002/submit" -Token "patient-p001" -Body $submitBody
    $submittedAgain = Invoke-RawHttpRequest -Port $port -Method "POST" -Path "/api/v1/questionnaires/BUNDLE-002/submit" -Token "patient-p001" -Body $submitBody
    Add-TestResult "questionnaire submission is write-once" (
        $submitted.StatusCode -eq 201 -and
        $submittedAgain.StatusCode -eq 409 -and
        $submittedAgain.Body.error.code -eq "ALREADY_SUBMITTED"
    )

    $doctorBundle = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/questionnaires/BUNDLE-002" -Token "doctor-c001"
    $doctorBundleProps = @($doctorBundle.Body.PSObject.Properties.Name)
    Add-TestResult "doctor receives questionnaire summary without raw answers" (
        $doctorBundle.StatusCode -eq 200 -and
        $doctorBundle.Body.submissionSummary.status -eq "submitted" -and
        "answers" -notin $doctorBundleProps -and
        $null -eq $doctorBundle.Body.instruments[0].PSObject.Properties["questions"]
    )

    $transferDetail = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-007" -Token "hospital-admin-h1"
    $relationshipIds = @($transferDetail.Body.careRelationships | ForEach-Object { $_.relationshipId })
    Add-TestResult "transferred patient retains both unit relationships" (
        $transferDetail.StatusCode -eq 200 -and
        "REL-007" -in $relationshipIds -and
        "REL-008" -in $relationshipIds
    )

    $historicalTasks = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-007/tasks?pageSize=100" -Token "hospital-admin-h1"
    $oldTask = @($historicalTasks.Body.items | Where-Object { $_.taskId -eq "TASK-007" }) | Select-Object -First 1
    Add-TestResult "historical task preserves issuing unit context" (
        $null -ne $oldTask -and
        $oldTask.departmentId -eq "DEPT-REPRO" -and
        $oldTask.clinicianId -eq "CLN-C002"
    )

    $tasksBeforeBatch = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/tasks?pageSize=100" -Token "doctor-c001"
    $batchBody = @{
        visitIds = @("VIS-002-02")
        templateId = "TPL-POI-3M"
        idempotencyKey = "acceptance-batch-001"
    } | ConvertTo-Json -Compress
    $batchFirst = Invoke-RawHttpRequest -Port $port -Method "POST" -Path "/api/v1/batches/task-generation" -Token "doctor-c001" -Body $batchBody
    $tasksAfterFirst = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/tasks?pageSize=100" -Token "doctor-c001"
    $batchReplay = Invoke-RawHttpRequest -Port $port -Method "POST" -Path "/api/v1/batches/task-generation" -Token "doctor-c001" -Body $batchBody
    $tasksAfterReplay = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/tasks?pageSize=100" -Token "doctor-c001"
    Add-TestResult "batch task generation is idempotent" (
        $batchFirst.StatusCode -eq 200 -and
        @($batchFirst.Body.success).Count -eq 3 -and
        $batchReplay.Body.idempotentReplay -eq $true -and
        $tasksAfterFirst.Body.meta.total -eq ($tasksBeforeBatch.Body.meta.total + 3) -and
        $tasksAfterReplay.Body.meta.total -eq $tasksAfterFirst.Body.meta.total
    ) "before=$($tasksBeforeBatch.Body.meta.total), after=$($tasksAfterFirst.Body.meta.total)"

    $batchCrossUnitBody = @{
        visitIds = @("VIS-002-02", "VIS-005-02")
        templateId = "TPL-POI-3M"
        idempotencyKey = "acceptance-batch-cross-unit"
    } | ConvertTo-Json -Compress
    $batchCrossUnit = Invoke-RawHttpRequest -Port $port -Method "POST" -Path "/api/v1/batches/task-generation" -Token "doctor-c001" -Body $batchCrossUnitBody
    $unitSkips = @($batchCrossUnit.Body.skipped | Where-Object { $_.code -eq "NOT_FOUND_OR_FORBIDDEN" })
    Add-TestResult "batch rejects visits outside the doctor's unit" ($unitSkips.Count -eq 1)

    $audit = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/audit?pageSize=100" -Token "hospital-admin-h1"
    $auditActions = @($audit.Body.items | ForEach-Object { $_.action })
    Add-TestResult "audit log records critical operations" (
        $audit.StatusCode -eq 200 -and
        "VIEW_PATIENT" -in $auditActions -and
        "SUBMIT_QUESTIONNAIRE" -in $auditActions -and
        "GENERATE_TASKS" -in $auditActions
    )

    $researcherPatients = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients?pageSize=100" -Token "researcher-demo"
    $researcherFields = @($researcherPatients.Body.items[0].PSObject.Properties.Name)
    Add-TestResult "researcher receives deidentified patient summaries" (
        $researcherPatients.StatusCode -eq 200 -and
        "studyCode" -in $researcherFields -and
        "patientId" -notin $researcherFields -and
        "currentDepartment" -notin $researcherFields
    )

    $researcherDetail = Invoke-RawHttpRequest -Port $port -Method "GET" -Path "/api/v1/patients/PAT-001" -Token "researcher-demo"
    Add-TestResult "researcher cannot open identifiable patient detail" ($researcherDetail.StatusCode -eq 403)
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
    }
}

foreach ($result in $script:testResults) {
    $label = if ($result.Passed) { "PASS" } else { "FAIL" }
    $suffix = if ([string]::IsNullOrWhiteSpace($result.Detail)) { "" } else { " [$($result.Detail)]" }
    Write-Output "$label`t$($result.Name)$suffix"
}

$failed = @($script:testResults | Where-Object { -not $_.Passed })
Write-Output ""
Write-Output "SUMMARY`tchecks=$($script:testResults.Count) passed=$($script:testResults.Count - $failed.Count) failed=$($failed.Count)"
if ($failed.Count -gt 0) {
    exit 1
}
