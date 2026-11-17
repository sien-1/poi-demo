function Get-AccessibleRelationships {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal
    )

    $relationships = @($State.careRelationships)
    switch ($Principal.role) {
        "patient" {
            return @($relationships | Where-Object { $_.patientId -ceq $Principal.patientId })
        }
        "clinician" {
            return @(
                $relationships |
                    Where-Object {
                        $_.status -ceq "active" -and
                        $_.clinicianId -ceq $Principal.clinicianId
                    }
            )
        }
        "department_admin" {
            return @(
                $relationships |
                    Where-Object {
                        $_.status -ceq "active" -and
                        $_.organizationId -ceq $Principal.organizationId -and
                        $_.departmentId -ceq $Principal.departmentId
                    }
            )
        }
        "hospital_admin" {
            return @(
                $relationships |
                    Where-Object {
                        $_.status -ceq "active" -and
                        $_.organizationId -ceq $Principal.organizationId
                    }
            )
        }
        "researcher" {
            return @($relationships | Where-Object { $_.status -ceq "active" })
        }
        default {
            return @()
        }
    }
}

function Get-AuthorizedPatientIds {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal
    )

    return @(
        Get-AccessibleRelationships -State $State -Principal $Principal |
            ForEach-Object { $_.patientId } |
            Sort-Object -Unique
    )
}

function Test-CanAccessPatient {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$PatientId
    )

    if ($Principal.role -ceq "patient") {
        return $Principal.patientId -ceq $PatientId
    }

    $patientIds = Get-AuthorizedPatientIds -State $State -Principal $Principal
    return $PatientId -in $patientIds
}

function Test-CanAccessVisit {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        $Visit
    )

    if (-not (Test-CanAccessPatient -State $State -Principal $Principal -PatientId $Visit.patientId)) {
        return $false
    }

    switch ($Principal.role) {
        "patient" { return $true }
        "clinician" {
            return $Visit.clinicianId -ceq $Principal.clinicianId -and
                $Visit.organizationId -ceq $Principal.organizationId -and
                $Visit.departmentId -ceq $Principal.departmentId
        }
        "department_admin" {
            return $Visit.organizationId -ceq $Principal.organizationId -and
                $Visit.departmentId -ceq $Principal.departmentId
        }
        "hospital_admin" {
            return $Visit.organizationId -ceq $Principal.organizationId
        }
        default { return $false }
    }
}

function Get-VisibleRelationshipsForPatient {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$PatientId
    )

    $relationships = @($State.careRelationships) | Where-Object { $_.patientId -ceq $PatientId }
    switch ($Principal.role) {
        "patient" {
            return @($relationships | Where-Object { $_.status -ceq "active" })
        }
        "clinician" {
            return @(
                $relationships |
                    Where-Object {
                        $_.organizationId -ceq $Principal.organizationId -and
                        ($_.departmentId -ceq $Principal.departmentId -or $_.clinicianId -ceq $Principal.clinicianId)
                    }
            )
        }
        "department_admin" {
            return @(
                $relationships |
                    Where-Object {
                        $_.organizationId -ceq $Principal.organizationId -and
                        $_.departmentId -ceq $Principal.departmentId
                    }
            )
        }
        "hospital_admin" {
            return @($relationships | Where-Object { $_.organizationId -ceq $Principal.organizationId })
        }
        "researcher" {
            return @()
        }
        default {
            return @()
        }
    }
}

function Get-VisibleVisitsForPatient {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal,
        [Parameter(Mandatory = $true)]
        [string]$PatientId
    )

    $visits = @($State.visits) | Where-Object { $_.patientId -ceq $PatientId }
    switch ($Principal.role) {
        "patient" { return @($visits) }
        "clinician" {
            return @(
                $visits |
                    Where-Object {
                        $_.organizationId -ceq $Principal.organizationId -and
                        $_.departmentId -ceq $Principal.departmentId
                    }
            )
        }
        "department_admin" {
            return @(
                $visits |
                    Where-Object {
                        $_.organizationId -ceq $Principal.organizationId -and
                        $_.departmentId -ceq $Principal.departmentId
                    }
            )
        }
        "hospital_admin" {
            return @($visits | Where-Object { $_.organizationId -ceq $Principal.organizationId })
        }
        "researcher" { return @($visits) }
        default { return @() }
    }
}

function Get-VisibleTasks {
    param(
        [Parameter(Mandatory = $true)]
        $State,
        [Parameter(Mandatory = $true)]
        $Principal
    )

    $tasks = @($State.tasks)
    switch ($Principal.role) {
        "patient" {
            return @($tasks | Where-Object { $_.patientId -ceq $Principal.patientId })
        }
        "clinician" {
            $patientIds = Get-AuthorizedPatientIds -State $State -Principal $Principal
            return @(
                $tasks |
                    Where-Object {
                        $_.patientId -in $patientIds -and
                        $_.clinicianId -ceq $Principal.clinicianId -and
                        $_.organizationId -ceq $Principal.organizationId -and
                        $_.departmentId -ceq $Principal.departmentId
                    }
            )
        }
        "department_admin" {
            return @(
                $tasks |
                    Where-Object {
                        $_.organizationId -ceq $Principal.organizationId -and
                        $_.departmentId -ceq $Principal.departmentId
                    }
            )
        }
        "hospital_admin" {
            return @($tasks | Where-Object { $_.organizationId -ceq $Principal.organizationId })
        }
        default {
            return @()
        }
    }
}
