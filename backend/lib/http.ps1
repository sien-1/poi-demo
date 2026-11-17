function New-ApiError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return [ordered]@{
        error = [ordered]@{
            code = $Code
            message = $Message
        }
    }
}

function New-ApiResponse {
    param(
        [Parameter(Mandatory = $true)]
        [int]$StatusCode,
        $Body
    )

    return [pscustomobject]@{
        StatusCode = $StatusCode
        Body = $Body
    }
}

function Get-StatusText {
    param([int]$StatusCode)

    switch ($StatusCode) {
        200 { return "OK" }
        201 { return "Created" }
        204 { return "No Content" }
        400 { return "Bad Request" }
        401 { return "Unauthorized" }
        403 { return "Forbidden" }
        404 { return "Not Found" }
        405 { return "Method Not Allowed" }
        409 { return "Conflict" }
        413 { return "Payload Too Large" }
        500 { return "Internal Server Error" }
        default { return "Error" }
    }
}

function Get-QueryParameters {
    param([string]$QueryString)

    $result = @{}
    if ([string]::IsNullOrWhiteSpace($QueryString)) {
        return $result
    }

    foreach ($part in $QueryString.TrimStart("?").Split("&")) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }
        $pair = $part.Split("=", 2)
        $name = [Uri]::UnescapeDataString($pair[0].Replace("+", " "))
        $value = if ($pair.Count -gt 1) {
            [Uri]::UnescapeDataString($pair[1].Replace("+", " "))
        }
        else {
            ""
        }
        $result[$name] = $value
    }

    return $result
}

function Read-HttpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.Sockets.TcpClient]$Client
    )

    $stream = $Client.GetStream()
    $stream.ReadTimeout = 5000
    $stream.WriteTimeout = 5000

    $received = New-Object "System.Collections.Generic.List[byte]"
    $buffer = New-Object byte[] 4096
    $headerEnd = -1
    $headerText = ""

    while ($headerEnd -lt 0) {
        $read = $stream.Read($buffer, 0, $buffer.Length)
        if ($read -le 0) {
            throw "客户端在请求头完成前关闭连接。"
        }
        for ($index = 0; $index -lt $read; $index++) {
            $received.Add($buffer[$index])
        }
        if ($received.Count -gt 65536) {
            throw "请求头过大。"
        }
        $headerText = [Text.Encoding]::ASCII.GetString($received.ToArray())
        $headerEnd = $headerText.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
    }

    $headerBlock = $headerText.Substring(0, $headerEnd)
    $lines = $headerBlock -split "`r`n"
    $requestParts = $lines[0].Split(" ")
    if ($requestParts.Count -lt 2) {
        throw "无效的 HTTP 请求行。"
    }

    $headers = @{}
    for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        $separator = $lines[$lineIndex].IndexOf(":")
        if ($separator -lt 1) {
            continue
        }
        $name = $lines[$lineIndex].Substring(0, $separator).Trim().ToLowerInvariant()
        $value = $lines[$lineIndex].Substring($separator + 1).Trim()
        $headers[$name] = $value
    }

    $contentLength = 0
    if ($headers.ContainsKey("content-length")) {
        if (-not [int]::TryParse($headers["content-length"], [ref]$contentLength)) {
            throw "Content-Length 无效。"
        }
    }
    if ($contentLength -gt 1048576) {
        throw "请求体超过 1 MB 限制。"
    }

    $allBytes = $received.ToArray()
    $bodyStart = $headerEnd + 4
    $alreadyReceived = [Math]::Max(0, $allBytes.Length - $bodyStart)
    $bodyBytes = New-Object byte[] $contentLength
    if ($alreadyReceived -gt 0) {
        [Array]::Copy($allBytes, $bodyStart, $bodyBytes, 0, [Math]::Min($alreadyReceived, $contentLength))
    }

    $bodyRead = [Math]::Min($alreadyReceived, $contentLength)
    while ($bodyRead -lt $contentLength) {
        $read = $stream.Read($bodyBytes, $bodyRead, $contentLength - $bodyRead)
        if ($read -le 0) {
            throw "请求体不完整。"
        }
        $bodyRead += $read
    }

    $target = $requestParts[1]
    $queryIndex = $target.IndexOf("?")
    $path = if ($queryIndex -ge 0) { $target.Substring(0, $queryIndex) } else { $target }
    $queryString = if ($queryIndex -ge 0) { $target.Substring($queryIndex + 1) } else { "" }
    $bodyText = if ($contentLength -gt 0) {
        [Text.Encoding]::UTF8.GetString($bodyBytes)
    }
    else {
        ""
    }

    return [pscustomobject]@{
        Method = $requestParts[0].ToUpperInvariant()
        Path = [Uri]::UnescapeDataString($path)
        Query = Get-QueryParameters $queryString
        Headers = $headers
        Body = $bodyText
        RemoteAddress = $Client.Client.RemoteEndPoint.ToString()
    }
}

function Send-HttpResponse {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory = $true)]
        [int]$StatusCode,
        $Body
    )

    $json = if ($null -eq $Body) {
        ""
    }
    else {
        $Body | ConvertTo-Json -Depth 20 -Compress
    }
    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($json)
    $headers = @(
        "HTTP/1.1 $StatusCode $(Get-StatusText $StatusCode)",
        "Content-Type: application/json; charset=utf-8",
        "Content-Length: $($bodyBytes.Length)",
        "Cache-Control: no-store",
        "X-Content-Type-Options: nosniff",
        "Connection: close",
        "",
        ""
    ) -join "`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
    $stream = $Client.GetStream()
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($bodyBytes.Length -gt 0) {
        $stream.Write($bodyBytes, 0, $bodyBytes.Length)
    }
    $stream.Flush()
}
