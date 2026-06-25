Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
    $lines = (Get-Content $_.FullName | Measure-Object -Line).Lines
    if ($lines -ge 500) {
        [PSCustomObject]@{
            Lines = $lines
            File = $_.FullName.Substring((Get-Location).Path.Length + 1)
        }
    }
} | Sort-Object Lines -Descending | ForEach-Object { '{0,5}  {1}' -f $_.Lines, $_.File }
