function Convert-JsonBody {
    param([string]$Body)

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }
    return $Body | ConvertFrom-Json
}

function Invoke-ApiRequest {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        [string]$Method,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [hashtable]$Query,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        [string]$RawBody = ""
    )

    if ($Path -ceq "/health" -and $Method -ceq "GET") {
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            status = "ok"
            service = "poi-demo-backend"
            version = $State.version
            storage = "synthetic-in-memory"
            generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
        })
    }

    $principal = Resolve-DemoPrincipal -State $State -Headers $Headers
    if ($null -eq $principal) {
        return New-ApiResponse -StatusCode 401 -Body (New-ApiError "UNAUTHORIZED" "缺少有效的演示身份令牌。")
    }

    $body = $null
    if (-not [string]::IsNullOrWhiteSpace($RawBody)) {
        try {
            $body = Convert-JsonBody -Body $RawBody
        }
        catch {
            return New-ApiResponse -StatusCode 400 -Body (New-ApiError "INVALID_JSON" "请求体不是有效的 JSON。")
        }
    }

    if ($Path -ceq "/api/v1/me") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        return New-ApiResponse -StatusCode 200 -Body (Get-PrincipalSummary -Principal $principal)
    }

    if ($Path -ceq "/api/v1/metadata") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            apiVersion = "v1"
            backendVersion = $State.version
            seedDate = $State.seedDate
            storageMode = "synthetic-in-memory"
            productionStorageRequired = "PostgreSQL"
            dataClasses = @($State.metadata.dataClasses)
            roles = @($State.metadata.roles)
            resources = @(
                "patients",
                "careRelationships",
                "visits",
                "tasks",
                "questionnaires",
                "audit"
            )
        })
    }

    if ($Path -ceq "/api/v1/patients") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        if ($principal.role -ceq "patient") {
            return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "患者不能访问患者目录。")
        }

        $patients = Find-Patients -State $State -Principal $principal -Query $Query
        $page = Get-PageValues -Query $Query
        $pageResult = Select-Page -Items $patients -Page $page.Page -PageSize $page.PageSize
        $items = @(
            $pageResult.items |
                ForEach-Object { Get-PatientSummary -State $State -Principal $principal -Patient $_ }
        )
        $result = [ordered]@{
            items = @($items)
            meta = $pageResult.meta
        }
        Add-AuditEvent -State $State -Principal $principal -Action "LIST_PATIENTS" `
            -ObjectType "patient_catalog" -ObjectId "" -OrganizationId $principal.organizationId `
            -DepartmentId $principal.departmentId
        return New-ApiResponse -StatusCode 200 -Body $result
    }

    if ($principal.role -ceq "researcher" -and $Path -match "^/api/v1/patients/[^/]+") {
        return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "研究角色只能访问去标识化患者摘要。")
    }

    if ($Path -match "^/api/v1/patients/([^/]+)$") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        $patientId = $Matches[1]
        $patient = Get-ItemById -Items $State.patients -Property "patientId" -Value $patientId
        if ($null -eq $patient -or -not (Test-CanAccessPatient -State $State -Principal $principal -PatientId $patientId)) {
            return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到患者或无权访问。")
        }
        $relationship = Get-CurrentRelationship -State $State -PatientId $patientId
        Add-AuditEvent -State $State -Principal $principal -Action "VIEW_PATIENT" `
            -ObjectType "patient" -ObjectId $patientId `
            -OrganizationId $(if ($null -ne $relationship) { $relationship.organizationId } else { "" }) `
            -DepartmentId $(if ($null -ne $relationship) { $relationship.departmentId } else { "" })
        return New-ApiResponse -StatusCode 200 -Body (Get-PatientDetail -State $State -Principal $principal -Patient $patient)
    }

    if ($Path -match "^/api/v1/patients/([^/]+)/visits$") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        $patientId = $Matches[1]
        if (-not (Test-CanAccessPatient -State $State -Principal $principal -PatientId $patientId)) {
            return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到患者或无权访问。")
        }
        $visits = @(
            Get-VisibleVisitsForPatient -State $State -Principal $principal -PatientId $patientId |
                Sort-Object plannedAt -Descending
        )
        $page = Get-PageValues -Query $Query
        $pageResult = Select-Page -Items $visits -Page $page.Page -PageSize $page.PageSize
        $items = @(
            $pageResult.items |
                ForEach-Object { Get-VisitProjection -State $State -Principal $principal -Visit $_ }
        )
        Add-AuditEvent -State $State -Principal $principal -Action "LIST_VISITS" `
            -ObjectType "patient" -ObjectId $patientId
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            items = @($items)
            meta = $pageResult.meta
        })
    }

    if ($Path -match "^/api/v1/patients/([^/]+)/tasks$") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        $patientId = $Matches[1]
        if (-not (Test-CanAccessPatient -State $State -Principal $principal -PatientId $patientId)) {
            return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到患者或无权访问。")
        }
        $taskQuery = @{}
        foreach ($key in $Query.Keys) {
            $taskQuery[$key] = $Query[$key]
        }
        $taskQuery["patientId"] = $patientId
        $tasks = Find-Tasks -State $State -Principal $principal -Query $taskQuery
        $page = Get-PageValues -Query $Query
        $pageResult = Select-Page -Items $tasks -Page $page.Page -PageSize $page.PageSize
        $items = @(
            $pageResult.items |
                ForEach-Object { Get-TaskProjection -State $State -Principal $principal -Task $_ }
        )
        Add-AuditEvent -State $State -Principal $principal -Action "LIST_PATIENT_TASKS" `
            -ObjectType "patient" -ObjectId $patientId
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            items = @($items)
            meta = $pageResult.meta
        })
    }

    if ($Path -ceq "/api/v1/tasks") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        if ($principal.role -ceq "researcher") {
            return New-ApiResponse -StatusCode 403 -Body (New-ApiError "FORBIDDEN" "研究角色不能访问真实业务任务。")
        }
        $tasks = Find-Tasks -State $State -Principal $principal -Query $Query
        $page = Get-PageValues -Query $Query
        $pageResult = Select-Page -Items $tasks -Page $page.Page -PageSize $page.PageSize
        $items = @(
            $pageResult.items |
                ForEach-Object { Get-TaskProjection -State $State -Principal $principal -Task $_ }
        )
        return New-ApiResponse -StatusCode 200 -Body ([ordered]@{
            items = @($items)
            meta = $pageResult.meta
        })
    }

    if ($Path -match "^/api/v1/tasks/([^/]+)/complete$") {
        if ($Method -ne "POST") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 POST。")
        }
        return Complete-TaskForPrincipal -State $State -Principal $principal -TaskId $Matches[1]
    }

    if ($Path -match "^/api/v1/questionnaires/([^/]+)/submit$") {
        if ($Method -ne "POST") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 POST。")
        }
        return Submit-QuestionnaireForPrincipal -State $State -Principal $principal -BundleId $Matches[1] -Body $body
    }

    if ($Path -match "^/api/v1/questionnaires/([^/]+)$") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        $bundleId = $Matches[1]
        $bundle = Get-ItemById -Items $State.questionnaires -Property "bundleId" -Value $bundleId
        if ($null -ne $bundle) {
            Add-AuditEvent -State $State -Principal $principal -Action "VIEW_QUESTIONNAIRE" `
                -ObjectType "questionnaire_bundle" -ObjectId $bundleId `
                -OrganizationId $bundle.organizationId -DepartmentId $bundle.departmentId
        }
        return Get-QuestionnaireForPrincipal -State $State -Principal $principal -BundleId $bundleId
    }

    if ($Path -match "^/api/v1/visits/([^/]+)$") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        $visitId = $Matches[1]
        $visit = Get-ItemById -Items $State.visits -Property "visitId" -Value $visitId
        if ($null -eq $visit -or -not (Test-CanAccessVisit -State $State -Principal $principal -Visit $visit)) {
            return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "未找到访视或无权访问。")
        }
        Add-AuditEvent -State $State -Principal $principal -Action "VIEW_VISIT" `
            -ObjectType "study_visit" -ObjectId $visitId -OrganizationId $visit.organizationId `
            -DepartmentId $visit.departmentId
        return New-ApiResponse -StatusCode 200 -Body (Get-VisitProjection -State $State -Principal $principal -Visit $visit)
    }

    if ($Path -ceq "/api/v1/batches/task-generation") {
        if ($Method -ne "POST") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 POST。")
        }
        return Invoke-TaskGenerationBatch -State $State -Principal $principal -Body $body
    }

    if ($Path -ceq "/api/v1/audit") {
        if ($Method -ne "GET") {
            return New-ApiResponse -StatusCode 405 -Body (New-ApiError "METHOD_NOT_ALLOWED" "该接口仅支持 GET。")
        }
        return Get-AuditEventsForPrincipal -State $State -Principal $principal -Query $Query
    }

    return New-ApiResponse -StatusCode 404 -Body (New-ApiError "NOT_FOUND" "接口不存在。")
}
