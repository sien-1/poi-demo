param(
    [int]$Port = 8765,
    [string]$DataPath = ""
)

$ErrorActionPreference = "Stop"

$libPath = Join-Path $PSScriptRoot "lib"
. (Join-Path $libPath "http.ps1")
. (Join-Path $libPath "auth.ps1")
. (Join-Path $libPath "data.ps1")
. (Join-Path $libPath "access.ps1")
. (Join-Path $libPath "resources.ps1")
. (Join-Path $libPath "batches.ps1")
. (Join-Path $libPath "api.ps1")

if ([string]::IsNullOrWhiteSpace($DataPath)) {
    $DataPath = Join-Path $PSScriptRoot "data\demo-seed.json"
}
$state = Initialize-DemoState -DataPath $DataPath

$listener = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
$listener.Server.SetSocketOption(
    [System.Net.Sockets.SocketOptionLevel]::Socket,
    [System.Net.Sockets.SocketOptionName]::ReuseAddress,
    $true
)

try {
    $listener.Start()
    Write-Host "POI backend MVP listening on http://127.0.0.1:$Port"
    Write-Host "Storage is synthetic-in-memory. Press Ctrl+C to stop."

    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.NoDelay = $true
            $request = Read-HttpRequest -Client $client
            $response = Invoke-ApiRequest -State $state -Method $request.Method -Path $request.Path `
                -Query $request.Query -Headers $request.Headers -RawBody $request.Body
            Send-HttpResponse -Client $client -StatusCode $response.StatusCode -Body $response.Body
        }
        catch {
            $safeError = New-ApiError "INTERNAL_ERROR" "服务处理请求时发生错误。"
            try {
                Send-HttpResponse -Client $client -StatusCode 500 -Body $safeError
            }
            catch {
                # The client may already be disconnected.
            }
            Write-Warning $_.Exception.Message
        }
        finally {
            $client.Close()
            $client.Dispose()
        }
    }
}
finally {
    $listener.Stop()
}
