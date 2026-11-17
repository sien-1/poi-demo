function Resolve-DemoPrincipal {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    if (-not $Headers.ContainsKey("x-demo-token")) {
        return $null
    }

    $token = [string]$Headers["x-demo-token"]
    if ([string]::IsNullOrWhiteSpace($token)) {
        return $null
    }

    return $State.users | Where-Object { $_.token -ceq $token } | Select-Object -First 1
}

function Get-PrincipalSummary {
    param(
        [Parameter(Mandatory = $true)]
        $Principal
    )

    return [ordered]@{
        userId = $Principal.userId
        displayName = $Principal.displayName
        role = $Principal.role
        organizationId = $Principal.organizationId
        departmentId = $Principal.departmentId
        clinicianId = $Principal.clinicianId
        patientId = $Principal.patientId
        dataScope = switch ($Principal.role) {
            "patient" { "self" }
            "clinician" { "active_care_relationship" }
            "department_admin" { "department" }
            "hospital_admin" { "organization" }
            "researcher" { "deidentified_study_view" }
            default { "none" }
        }
    }
}

function Test-ClinicalStaffRole {
    param($Principal)

    return $Principal.role -in @("clinician", "department_admin", "hospital_admin")
}

function Test-AdministrativeRole {
    param($Principal)

    return $Principal.role -in @("department_admin", "hospital_admin")
}
