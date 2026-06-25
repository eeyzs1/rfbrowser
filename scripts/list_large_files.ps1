$files = Get-ChildItem -Path 'lib' -Recurse -Filter '*.dart'
$results = @()
foreach ($f in $files) {
    $lines = (Get-Content $f.FullName | Measure-Object -Line).Lines
    if ($lines -gt 400) {
        $results += [PSCustomObject]@{
            Lines = $lines
            Path = $f.FullName.Replace('e:\AI_Generated_Projects\rfbrowser\','')
        }
    }
}
$results | Sort-Object Lines -Descending | ForEach-Object { Write-Output ('{0,5}  {1}' -f $_.Lines, $_.Path) }
