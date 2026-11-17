function Get-PatientSummary {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        $Patient
    )

    if ($Principal.role -ceq "researcher") {
        return [ordered]@{
            studyCode = $Patient.studyCode
            ageBand = $Patient.ageBand
            status = $Patient.status
            consentStatus = $Patient.consentStatus
        }
    }

    $relationship = Get-CurrentRelationship -State $State -PatientId $Patient.patientId
    $department = if ($null -ne $relationship) {
        Get-ItemById -Items $State.departments -Property "departmentId" -Value $relationship.departmentId
    }
    else {
        $null
    }

    return [ordered]@{
        patientId = $Patient.patientId
        studyCode = $Patient.studyCode
        ageBand = $Patient.ageBand
        status = $Patient.status
        currentDepartment = if ($null -ne $department) { $department.name } else { $null }
        nextVisitAt = Get-NextVisitDate -State $State -PatientId $Patient.patientId
    }
}

function Find-Patients {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [hashtable]$Query = @{}
    )

    $patientIds = Get-AuthorizedPatientIds -State $State -Principal $Principal
    $patients = @($State.patients) | Where-Object { $_.patientId -in $patientIds }

    if ($Query.ContainsKey("q") -and -not [string]::IsNullOrWhiteSpace($Query["q"])) {
        $keyword = [string]$Query["q"]
        $patients = @(
            $patients |
                Where-Object {
                    $_.patientId.IndexOf($keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                    $_.studyCode.IndexOf($keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0
                }
        )
    }
    if ($Query.ContainsKey("status") -and -not [string]::IsNullOrWhiteSpace($Query["status"])) {
        $patients = @($patients | Where-Object { $_.status -ceq [string]$Query["status"] })
    }

    return @($patients | Sort-Object studyCode, patientId)
}

function Find-Tasks {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [hashtable]$Query = @{}
    )

    $tasks = @(Get-VisibleTasks -State $State -Principal $Principal)

    if ($Query.ContainsKey("patientId") -and -not [string]::IsNullOrWhiteSpace($Query["patientId"])) {
        $tasks = @($tasks | Where-Object { $_.patientId -ceq [string]$Query["patientId"] })
    }
    if ($Query.ContainsKey("status") -and -not [string]::IsNullOrWhiteSpace($Query["status"])) {
        $tasks = @($tasks | Where-Object { $_.status -ceq [string]$Query["status"] })
    }
    if ($Query.ContainsKey("from") -and -not [string]::IsNullOrWhiteSpace($Query["from"])) {
        $tasks = @($tasks | Where-Object { [string]::CompareOrdinal($_.dueAt, [string]$Query["from"]) -ge 0 })
    }
    if ($Query.ContainsKey("to") -and -not [string]::IsNullOrWhiteSpace($Query["to"])) {
        $tasks = @($tasks | Where-Object { [string]::CompareOrdinal($_.dueAt, [string]$Query["to"]) -le 0 })
    }
    if ($Query.ContainsKey("visitNo") -and -not [string]::IsNullOrWhiteSpace($Query["visitNo"])) {
        $visitNo = 0
        if ([int]::TryParse([string]$Query["visitNo"], [ref]$visitNo)) {
            $visitIds = @(
                $State.visits |
                    Where-Object { [int]$_.visitNo -eq $visitNo } |
                    ForEach-Object { $_.visitId }
            )
            $tasks = @($tasks | Where-Object { $_.visitId -in $visitIds })
        }
    }
    if ($Query.ContainsKey("q") -and -not [string]::IsNullOrWhiteSpace($Query["q"])) {
        $keyword = [string]$Query["q"]
        $tasks = @(
            $tasks |
                Where-Object {
                    $_.title.IndexOf($keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                    $_.taskId.IndexOf($keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0
                }
        )
    }

    return @($tasks | Sort-Object dueAt, taskId)
}

function Get-TaskProjection {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        $Task
    )

    $result = [ordered]@{
        taskId = $Task.taskId
        title = $Task.title
        kind = $Task.kind
        dueAt = $Task.dueAt
        status = $Task.status
        completedAt = $Task.completedAt
    }

    if ($Principal.role -ne "patient") {
        $patient = Get-ItemById -Items $State.patients -Property "patientId" -Value $Task.patientId
        $visit = Get-ItemById -Items $State.visits -Property "visitId" -Value $Task.visitId
        $result["studyCode"] = if ($null -ne $patient) { $patient.studyCode } else { $null }
        $result["visitNo"] = if ($null -ne $visit) { $visit.visitNo } else { $null }
        $result["organizationId"] = $Task.organizationId
        $result["departmentId"] = $Task.departmentId
        $result["clinicianId"] = $Task.clinicianId
    }

    return $result
}

function Get-VisitProjection {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        $Visit
    )

    $patient = Get-ItemById -Items $State.patients -Property "patientId" -Value $Visit.patientId
    $result = [ordered]@{
        visitId = $Visit.visitId
        patientId = $Visit.patientId
        studyCode = if ($null -ne $patient) { $patient.studyCode } else { $null }
        visitNo = $Visit.visitNo
        visitCode = $Visit.visitCode
        plannedAt = $Visit.plannedAt
        completedAt = $Visit.completedAt
        status = $Visit.status
    }

    if ($Principal.role -ne "patient") {
        $result["organizationId"] = $Visit.organizationId
        $result["departmentId"] = $Visit.departmentId
        $result["clinicianId"] = $Visit.clinicianId
    }

    return $result
}

function Get-PatientDetail {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        $Patient
    )

    $current = Get-CurrentRelationship -State $State -PatientId $Patient.patientId
    $department = if ($null -ne $current) {
        Get-ItemById -Items $State.departments -Property "departmentId" -Value $current.departmentId
    }
    else {
        $null
    }
    $relationships = @(
        Get-VisibleRelationshipsForPatient -State $State -Principal $Principal -PatientId $Patient.patientId |
            Sort-Object startAt -Descending
    )
    $visits = @(
        Get-VisibleVisitsForPatient -State $State -Principal $Principal -PatientId $Patient.patientId |
            Sort-Object plannedAt -Descending
    )
    $tasks = @(
        Get-VisibleTasks -State $State -Principal $Principal |
            Where-Object { $_.patientId -ceq $Patient.patientId } |
            Sort-Object dueAt -Descending |
            Select-Object -First 10
    )
    $bundles = @(
        $State.questionnaires |
            Where-Object {
                $_.patientId -ceq $Patient.patientId -and
                (
                    $Principal.role -eq "patient" -or
                    (
                        $_.organizationId -ceq $Principal.organizationId -and
                        (
                            $Principal.role -eq "hospital_admin" -or
                            $_.departmentId -ceq $Principal.departmentId
                        )
                    )
                )
            } |
            Sort-Object dueAt -Descending |
            Select-Object -First 10
    )

    return [ordered]@{
        patient = [ordered]@{
            patientId = $Patient.patientId
            studyCode = $Patient.studyCode
            ageBand = $Patient.ageBand
            status = $Patient.status
            consentStatus = $Patient.consentStatus
            currentDepartment = if ($null -ne $department) { $department.name } else { $null }
            nextVisitAt = Get-NextVisitDate -State $State -PatientId $Patient.patientId
        }
        careRelationships = @(
            $relationships |
                ForEach-Object {
                    [ordered]@{
                        relationshipId = $_.relationshipId
                        relationshipType = $_.relationshipType
                        status = $_.status
                        startAt = $_.startAt
                        endAt = $_.endAt
                        organizationId = $_.organizationId
                        departmentId = $_.departmentId
                        clinicianId = $_.clinicianId
                        source = $_.source
                    }
                }
        )
        visits = @(
            $visits |
                ForEach-Object { Get-VisitProjection -State $State -Principal $Principal -Visit $_ }
        )
        recentTasks = @(
            $tasks |
                ForEach-Object { Get-TaskProjection -State $State -Principal $Principal -Task $_ }
        )
        questionnaireSummary = @(
            $bundles |
                ForEach-Object {
                    [ordered]@{
                        bundleId = $_.bundleId
                        dueAt = $_.dueAt
                        status = $_.status
                        instrumentCount = @($_.instruments).Count
                        submittedAt = if ($null -ne $_.submission) { $_.submission.submittedAt } else { $null }
                    }
                }
        )
    }
}

function Complete-TaskForPrincipal {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$TaskId
    )

    if ($Principal.role -ne "patient") {
        return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "当前角色不能执行患者任务。")
    }

    $task = @(Get-VisibleTasks -State $State -Principal $Principal) |
        Where-Object { $_.taskId -ceq $TaskId } |
        Select-Object -First 1
    if ($null -eq $task) {
        return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到任务或无权访问。")
    }

    if ($task.status -eq "completed") {
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            task = Get-TaskProjection -State $State -Principal $Principal -Task $task
            alreadyCompleted = $true
        })
    }
    if ($task.status -notin @("pending", "overdue")) {
        return New-ApiResponse -StatusCode 409 -Body (New-ApiError "INVALID_TASK_STATE" "当前任务状态不能标记为完成。")
    }

    $task.status = "completed"
    $task.completedAt = [DateTimeOffset]::UtcNow.ToString("o")
    Add-AuditEvent -State $State -Principal $Principal -Action "COMPLETE_TASK" `
        -ObjectType "task" -ObjectId $task.taskId -OrganizationId $task.organizationId `
        -DepartmentId $task.departmentId

    return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
        task = Get-TaskProjection -State $State -Principal $Principal -Task $task
        alreadyCompleted = $false
    })
}

function Get-QuestionnaireForPrincipal {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$BundleId
    )

    $bundle = Get-ItemById -Items $State.questionnaires -Property "bundleId" -Value $BundleId
    if ($null -eq $bundle -or -not (Test-CanAccessPatient -State $State -Principal $Principal -PatientId $bundle.patientId)) {
        return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到问卷或无权访问。")
    }
    if ($Principal.role -ceq "researcher") {
        return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "研究角色不能进入真实业务问卷。")
    }
    if ($Principal.role -ne "patient" -and $Principal.role -ne "hospital_admin") {
        if ($bundle.organizationId -cne $Principal.organizationId -or $bundle.departmentId -cne $Principal.departmentId) {
            return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到问卷或无权访问。")
        }
    }
    if ($Principal.role -eq "hospital_admin" -and $bundle.organizationId -cne $Principal.organizationId) {
        return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到问卷或无权访问。")
    }

    if ($Principal.role -ceq "patient") {
        $items = @()
        foreach ($instrument in @($bundle.instruments)) {
            foreach ($question in @($instrument.questions)) {
                $items += [ordered]@{
                    questionId = $question.questionId
                    prompt = $question.prompt
                    required = [bool]$question.required
                    options = @($question.options)
                }
            }
        }
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            bundleId = $bundle.bundleId
            status = $bundle.status
            dueAt = $bundle.dueAt
            title = "健康随访问卷"
            items = @($items)
        })
    }

    $instruments = @(
        $bundle.instruments |
            ForEach-Object {
                [ordered]@{
                    instrumentId = $_.instrumentId
                    instrumentVersionId = $_.instrumentVersionId
                    displayName = $_.displayName
                    questionCount = @($_.questions).Count
                    required = [bool]$_.required
                }
            }
    )
    $submissionSummary = if ($null -ne $bundle.submission) {
        [ordered]@{
            status = "submitted"
            submittedAt = $bundle.submission.submittedAt
            answerCount = @($bundle.submission.answers).Count
            scoreResult = $bundle.submission.scoreResult
        }
    }
    else {
        $null
    }

    return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
        bundleId = $bundle.bundleId
        patientId = $bundle.patientId
        visitId = $bundle.visitId
        status = $bundle.status
        dueAt = $bundle.dueAt
        organizationId = $bundle.organizationId
        departmentId = $bundle.departmentId
        clinicianId = $bundle.clinicianId
        instruments = @($instruments)
        submissionSummary = $submissionSummary
    })
}

function Submit-QuestionnaireForPrincipal {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$BundleId,
        $Body
    )

    if ($Principal.role -ne "patient") {
        return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "仅患者本人可提交问卷。")
    }

    $bundle = Get-ItemById -Items $State.questionnaires -Property "bundleId" -Value $BundleId
    if ($null -eq $bundle -or $bundle.patientId -cne $Principal.patientId) {
        return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到问卷或无权访问。")
    }
    if ($bundle.status -ceq "submitted" -or $null -ne $bundle.submission) {
        return New-ApiResponse -StatusCode 409 -Body (New-ApiError "ALREADY_SUBMITTED" "该问卷已提交，不能重复写入。")
    }

    $answerMap = @{}
    if ($null -eq $Body -or $null -eq $Body.PSObject.Properties["answers"]) {
        return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_ANSWERS" "answers 字段不能为空。")
    }
    foreach ($answer in @($Body.answers)) {
        if ($null -eq $answer -or $null -eq $answer.questionId) {
            return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_ANSWERS" "答案项缺少 questionId。")
        }
        $questionId = [string]$answer.questionId
        if ($answerMap.ContainsKey($questionId)) {
            return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_ANSWERS" "同一题项不能重复提交。")
        }
        $answerMap[$questionId] = $answer.value
    }

    $requiredQuestions = @()
    $allQuestions = @()
    foreach ($instrument in @($bundle.instruments)) {
        foreach ($question in @($instrument.questions)) {
            $allQuestions += $question
            if ([bool]$question.required) {
                $requiredQuestions += $question
            }
        }
    }
    foreach ($question in $requiredQuestions) {
        if (-not $answerMap.ContainsKey([string]$question.questionId) -or $null -eq $answerMap[[string]$question.questionId]) {
            return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_ANSWERS" "必填题项尚未完成。")
        }
    }
    $knownQuestionIds = @($allQuestions | ForEach-Object { [string]$_.questionId })
    foreach ($questionId in $answerMap.Keys) {
        if ($questionId -notin $knownQuestionIds) {
            return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_ANSWERS" "答案包含不属于该问卷的题项。")
        }
    }

    $answerItems = @(
        foreach ($question in $allQuestions) {
            if ($answerMap.ContainsKey([string]$question.questionId)) {
                [ordered]@{
                    questionId = $question.questionId
                    value = $answerMap[[string]$question.questionId]
                }
            }
        }
    )
    $score = 0.0
    foreach ($answer in $answerItems) {
        $numeric = 0.0
        if ([double]::TryParse([string]$answer.value, [ref]$numeric)) {
            $score += $numeric
        }
    }

    $submission = [pscustomobject][ordered]@{
        submissionId = "SUB-" + [Guid]::NewGuid().ToString("N")
        submittedAt = [DateTimeOffset]::UtcNow.ToString("o")
        answers = @($answerItems)
        scoreResult = [ordered]@{
            total = $score
            ruleVersion = "DEMO-ONLY-V1"
        }
    }
    $bundle.submission = $submission
    $bundle.status = "submitted"

    if (-not [string]::IsNullOrWhiteSpace([string]$bundle.taskId)) {
        $task = Get-ItemById -Items $State.tasks -Property "taskId" -Value $bundle.taskId
        if ($null -ne $task -and $task.status -in @("pending", "overdue")) {
            $task.status = "completed"
            $task.completedAt = $submission.submittedAt
        }
    }

    Add-AuditEvent -State $State -Principal $Principal -Action "SUBMIT_QUESTIONNAIRE" `
        -ObjectType "questionnaire_bundle" -ObjectId $bundle.bundleId -OrganizationId $bundle.organizationId `
        -DepartmentId $bundle.departmentId

    return New-ApiResponse -StatusCode 201 -Body ([ordered]@{
        submissionId = $submission.submissionId
        bundleId = $bundle.bundleId
        status = "submitted"
        submittedAt = $submission.submittedAt
        answerCount = @($answerItems).Count
    })
}

function Get-AuditEventsForPrincipal {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [hashtable]$Query = @{}
    )

    if (-not (Test-AdministrativeRole -Principal $Principal)) {
        return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "当前角色不能查看审计日志。")
    }

    $events = @($State.auditLog)
    if ($Principal.role -ceq "department_admin") {
        $events = @(
            $events |
                Where-Object {
                    $_.organizationId -ceq $Principal.organizationId -and
                    $_.departmentId -ceq $Principal.departmentId
                }
        )
    }
    else {
        $events = @($events | Where-Object { $_.organizationId -ceq $Principal.organizationId })
    }

    $events = @($events | Sort-Object occurredAt -Descending)
    $page = Get-PageValues -Query $Query -DefaultPageSize 50 -MaximumPageSize 100
    return New-ApiResponse -StatusCode 200 -Body (Select-Page -Items $events -Page $page.Page -PageSize $page.PageSize)
}
