$ErrorActionPreference = 'Stop'

$files = @(
    'a:\HHHHHHHHHH\resthouse_app\lib\pages\main_shell.dart',
    'a:\HHHHHHHHHH\resthouse_app\lib\pages\booking_manager_page.dart',
    'a:\HHHHHHHHHH\resthouse_app\lib\pages\ultimate_dashboard_page.dart',
    'a:\HHHHHHHHHH\resthouse_app\lib\pages\settings_page.dart',
    'a:\HHHHHHHHHH\resthouse_app\lib\pages\finance_page.dart'
)

$importLine = "import '../utils/responsive.dart';"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($file in $files) {
    Write-Host "Processing: $file"
    $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
    $originalLength = $content.Length

    # 1. Add import after flutter/material.dart if not already present
    if (-not $content.Contains("responsive.dart")) {
        $content = $content.Replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';`nimport '../utils/responsive.dart';"
        )
        Write-Host "  + Added import"
    }

    # 2. Replace fontSize: <number> with fontSize: <number>.sp(context)
    #    Negative lookahead prevents double-processing
    $pattern = 'fontSize: (\d+(?:\.\d+)?)(?!\.sp)'
    $replacement = 'fontSize: $1.sp(context)'
    $matchCount = ([regex]::Matches($content, $pattern)).Count
    $content = [regex]::Replace($content, $pattern, $replacement)
    Write-Host "  + Replaced $matchCount fontSize references"

    # 3. Remove 'const' from TextStyle( declarations that now contain .sp
    #    Safe: TextStyle is lightweight, negligible perf impact from removing const
    $constTsCount = ([regex]::Matches($content, 'const TextStyle\(')).Count
    $content = $content.Replace('const TextStyle(', 'TextStyle(')
    Write-Host "  + Removed const from $constTsCount TextStyle declarations"

    # 4. Write back
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
    $newLength = $content.Length
    Write-Host "  Done ($originalLength -> $newLength chars)"
    Write-Host ""
}

Write-Host "=== All files processed ==="
