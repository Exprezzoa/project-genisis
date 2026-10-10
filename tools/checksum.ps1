# Prints "<file> <bytes> <adler32>" for the local .lua files, to compare with the Studio sources (D-014).
# Line endings are normalized to LF before counting, like the sources stored in Studio.
# Usage: tools\checksum.ps1 [<regex filter on the relative path>]   (default: every .lua under src/ and builders/)
param([string]$Filter = ".")
$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -Recurse -File -Filter *.lua (Join-Path $root "src"), (Join-Path $root "builders")
foreach ($file in $files) {
    $rel = $file.FullName.Substring($root.Length + 1)
    if ($rel -notmatch $Filter) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    [uint32]$a = 1; [uint32]$b = 0; $n = 0
    foreach ($byte in $bytes) {
        if ($byte -eq 13) { continue }
        $a = ($a + $byte) % 65521
        $b = ($b + $a) % 65521
        $n++
    }
    "{0} {1} {2}" -f $rel, $n, ([uint64]$b * 65536 + $a)
}
