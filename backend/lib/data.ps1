function Initialize-DemoState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataPath
    )

    if (-not (Test-Path -LiteralPath $DataPath)) {
        throw "演示种子文件不存在：$DataPath"
    }

    $json = Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8
    $state = $json | ConvertFrom-Json
    if ($null -eq $state -or $null -eq $state.users -or $null -eq $state.patients) {
        throw "演示种子文件结构无效。"
    }

    return $state
}

function Get-ItemById {
    param(
        [object[]]$Items,
        [Parameter(Mandatory = $true)]
        [string]$Property,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return @($Items) | Where-Object { [string]$_.$Property -ceq $Value } | Select-Object -First 1
}

function Get-CurrentRelationship {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        [string]$PatientId
    )

    return @($State.careRelationships) |
        Where-Object { $_.patientId -ceq $PatientId -and $_.status -ceq "active" } |
        Sort-Object startAt |
        Select-Object -First 1
}

function Get-NextVisitDate {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        [string]$PatientId
    )

    $nextVisit = @($State.visits) |
        Where-Object {
            $_.patientId -ceq $PatientId -and
            $_.status -in @("planned", "pending", "overdue")
        } |
        Sort-Object plannedAt |
        Select-Object -First 1

    if ($null -eq $nextVisit) {
        return $null
    }
    return $nextVisit.plannedAt
}

function Add-AuditEvent {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [Parameter(Mandatory = $true)]
        [string]$ObjectType,
        [string]$ObjectId = "",
        [string]$Result = "success",
        [string]$OrganizationId = "",
        [string]$DepartmentId = ""
    )

    $event = [pscustomobject][ordered]@{
        auditId = "AUD-" + [Guid]::NewGuid().ToString("N")
        actorUserId = $Principal.userId
        action = $Action
        objectType = $ObjectType
        objectId = $ObjectId
        result = $Result
        organizationId = $OrganizationId
        departmentId = $DepartmentId
        occurredAt = [DateTimeOffset]::UtcNow.ToString("o")
        source = "api"
    }
    $State.auditLog = @($State.auditLog) + $event
}

function Add-DaysToDate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Date,
        [Parameter(Mandatory = $true)]
        [int]$Days
    )

    $parsed = [DateTime]::ParseExact($Date, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
    return $parsed.AddDays($Days).ToString("yyyy-MM-dd")
}

function Get-PageValues {
    param(
        [hashtable]$Query,
        [int]$DefaultPageSize = 20,
        [int]$MaximumPageSize = 100
    )

    $page = 1
    $pageSize = $DefaultPageSize
    if ($Query.ContainsKey("page")) {
        [void][int]::TryParse([string]$Query["page"], [ref]$page)
    }
    if ($Query.ContainsKey("pageSize")) {
        [void][int]::TryParse([string]$Query["pageSize"], [ref]$pageSize)
    }
    $page = [Math]::Max(1, $page)
    $pageSize = [Math]::Max(1, [Math]::Min($MaximumPageSize, $pageSize))

    return [pscustomobject]@{
        Page = $page
        PageSize = $pageSize
    }
}

function Select-Page {
    param(
        [object[]]$Items,
        [int]$Page,
        [int]$PageSize
    )

    $materialized = @($Items)
    $total = $materialized.Count
    $skip = ($Page - 1) * $PageSize
    $pageItems = if ($skip -ge $total) {
        @()
    }
    else {
        @($materialized | Select-Object -Skip $skip -First $PageSize)
    }

    return [ordered]@{
        items = @($pageItems)
        meta = [ordered]@{
            page = $Page
            pageSize = $PageSize
            total = $total
            totalPages = if ($total -eq 0) { 0 } else { [int][Math]::Ceiling($total / [double]$PageSize) }
        }
    }
}
