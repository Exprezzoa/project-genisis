# Serves the project's .lua files to the Studio session on this machine only (127.0.0.1), so a push through
# the MCP can read a file instead of having its text retyped (D-043). Read-only; .lua under src/ and builders/ only.
# Usage: tools\serve.ps1 [-Port 8123]      Stop it with Ctrl+C or by ending the process.
param([int]$Port = 8123)
$root = Split-Path -Parent $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
"serving $root on http://127.0.0.1:$Port/"
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $rel = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
        $status = 404
        $body = [byte[]]@()
        if ($rel -match '^(src|builders)/[A-Za-z0-9_./-]+\.lua$' -and $rel -notmatch '\.\.') {
            $path = Join-Path $root $rel
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $text = [System.IO.File]::ReadAllText($path) -replace "`r", ""
                $body = [System.Text.Encoding]::UTF8.GetBytes($text)
                $status = 200
            }
        }
        $context.Response.StatusCode = $status
        $context.Response.ContentType = "text/plain; charset=utf-8"
        $context.Response.ContentLength64 = $body.Length
        $context.Response.OutputStream.Write($body, 0, $body.Length)
        $context.Response.Close()
    }
} finally {
    $listener.Stop()
}
