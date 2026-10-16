$out=@()
foreach ($name in @(Get-ChildItem $PSScriptRoot -Filter '*.ps1' | Select-Object -ExpandProperty Name)) {
 $tokens=$null; $errors=$null
 [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name),[ref]$tokens,[ref]$errors)
 $out+=@{file=$name;errors=@($errors | ForEach-Object { @{message=$_.Message;line=$_.Extent.StartLineNumber} })}
}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($out | ConvertTo-Json -Depth 8 -Compress)))
