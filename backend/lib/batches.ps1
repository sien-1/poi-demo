function Invoke-TaskGenerationBatch {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        $Body
    )

    if ($Principal.role -ne "clinician") {
        return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "仅医生可以生成随访任务批次。")
    }
    if ($null -eq $Body) {
        return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_BATCH" "请求体不能为空。")
    }

    $visitIds = @()
    if ($null -ne $Body.PSObject.Properties["visitIds"]) {
        $visitIds = @($Body.visitIds | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    }
    if ($visitIds.Count -eq 0) {
        return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_BATCH" "visitIds 至少需要一个访视编号。")
    }
    if ($visitIds.Count -gt 100) {
        return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_BATCH" "单批次最多处理 100 个访视。")
    }

    $templateId = if ($null -ne $Body.PSObject.Properties["templateId"]) { [string]$Body.templateId } else { "" }
    $idempotencyKey = if ($null -ne $Body.PSObject.Properties["idempotencyKey"]) { [string]$Body.idempotencyKey } else { "" }
    if ([string]::IsNullOrWhiteSpace($templateId)) {
        return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_BATCH" "templateId 不能为空。")
    }
    if ($idempotencyKey -notmatch "^[A-Za-z0-9._:-]{1,120}$") {
        return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_BATCH" "idempotencyKey 仅允许 1 至 120 位字母、数字和 . _ : -。")
    }

    $template = Get-ItemById -Items $State.templates -Property "templateId" -Value $templateId
    if ($null -eq $template -or $template.status -cne "published") {
        return New-ApiResponse -StatusCode 404 -Body (New-ApiError "TEMPLATE_NOT_FOUND" "未找到已发布的随访模板。")
    }

    $existingReceipt = @($State.batchReceipts) |
        Where-Object {
            $_.actorUserId -ceq $Principal.userId -and
            $_.idempotencyKey -ceq $idempotencyKey
        } |
        Select-Object -First 1
    if ($null -ne $existingReceipt) {
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            batchId = $existingReceipt.batchId
            idempotentReplay = $true
            success = @($existingReceipt.success)
            skipped = @($existingReceipt.skipped)
            failed = @()
        })
    }

    $success = @()
    $skipped = @()
    $failed = @()
    $unitContext = $null
    $newTasks = @()
    $seenVisitIds = @{}

    foreach ($visitId in $visitIds) {
        if ($seenVisitIds.ContainsKey($visitId)) {
            $skipped += [ordered]@{
                visitId = $visitId
                code = "DUPLICATE_INPUT"
                message = "同一批次中重复的访视编号已跳过。"
            }
            continue
        }
        $seenVisitIds[$visitId] = $true

        $visit = Get-ItemById -Items $State.visits -Property "visitId" -Value $visitId
        if ($null -eq $visit -or -not (Test-CanAccessVisit -State $State -Principal $Principal -Visit $visit)) {
            $skipped += [ordered]@{
                visitId = $visitId
                code = "NOT_FOUND_OR_FORBIDDEN"
                message = "访视不存在或当前账号无权处理。"
            }
            continue
        }

        if ($null -eq $unitContext) {
            $unitContext = [pscustomobject]@{
                OrganizationId = $visit.organizationId
                DepartmentId = $visit.departmentId
                ClinicianId = $visit.clinicianId
            }
        }
        elseif (
            $visit.organizationId -cne $unitContext.OrganizationId -or
            $visit.departmentId -cne $unitContext.DepartmentId -or
            $visit.clinicianId -cne $unitContext.ClinicianId
        ) {
            $skipped += [ordered]@{
                visitId = $visitId
                code = "UNIT_MISMATCH"
                message = "一个批次只能包含同一医院、科室和医生的访视。"
            }
            continue
        }

        foreach ($item in @($template.items)) {
            $generationKey = "$idempotencyKey|$templateId|$visitId|$($item.itemId)"
            $alreadyExists = @($State.tasks) | Where-Object {
                $_.patientId -ceq $visit.patientId -and
                $_.visitId -ceq $visit.visitId -and
                $_.templateId -ceq $templateId -and
                $_.itemId -ceq $item.itemId
            } | Select-Object -First 1

            if ($null -ne $alreadyExists) {
                $success += [ordered]@{
                    visitId = $visitId
                    taskId = $alreadyExists.taskId
                    title = $alreadyExists.title
                    dueAt = $alreadyExists.dueAt
                    created = $false
                }
                continue
            }

            try {
                $task = [pscustomobject][ordered]@{
                    taskId = "TASK-" + [Guid]::NewGuid().ToString("N").Substring(0, 12)
                    patientId = $visit.patientId
                    visitId = $visit.visitId
                    templateId = $templateId
                    itemId = $item.itemId
                    title = $item.title
                    kind = $item.kind
                    dueAt = Add-DaysToDate -Date $visit.plannedAt -Days ([int]$item.dayOffset)
                    status = "pending"
                    completedAt = $null
                    organizationId = $unitContext.OrganizationId
                    departmentId = $unitContext.DepartmentId
                    clinicianId = $unitContext.ClinicianId
                    createdBy = $Principal.userId
                    createdAt = [DateTimeOffset]::UtcNow.ToString("o")
                    generationKey = $generationKey
                }
                $newTasks += $task
                $success += [ordered]@{
                    visitId = $visitId
                    taskId = $task.taskId
                    title = $task.title
                    dueAt = $task.dueAt
                    created = $true
                }
            }
            catch {
                $failed += [ordered]@{
                    visitId = $visitId
                    code = "TASK_CREATE_FAILED"
                    message = "任务创建失败。"
                }
            }
        }
    }

    $State.tasks = @($State.tasks) + @($newTasks)
    $batchId = "BATCH-" + [Guid]::NewGuid().ToString("N").Substring(0, 12)
    $receipt = [pscustomobject][ordered]@{
        batchId = $batchId
        actorUserId = $Principal.userId
        idempotencyKey = $idempotencyKey
        templateId = $templateId
        organizationId = if ($null -ne $unitContext) { $unitContext.OrganizationId } else { "" }
        departmentId = if ($null -ne $unitContext) { $unitContext.DepartmentId } else { "" }
        clinicianId = if ($null -ne $unitContext) { $unitContext.ClinicianId } else { "" }
        success = @($success)
        skipped = @($skipped)
        createdAt = [DateTimeOffset]::UtcNow.ToString("o")
    }
    $State.batchReceipts = @($State.batchReceipts) + $receipt

    Add-AuditEvent -State $State -Principal $Principal -Action "GENERATE_TASKS" `
        -ObjectType "task_batch" -ObjectId $batchId -OrganizationId $receipt.organizationId `
        -DepartmentId $receipt.departmentId

    return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
        batchId = $batchId
        idempotentReplay = $false
        success = @($success)
        skipped = @($skipped)
        failed = @($failed)
    })
}
