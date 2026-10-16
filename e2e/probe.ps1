[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
$ErrorActionPreference = 'Continue'
$out = [ordered]@{identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name; userProfile=$env:USERPROFILE; path=$env:PATH; policy=([string](Get-ExecutionPolicy)); policies=@(Get-ExecutionPolicy -List | Select-Object @{n='scope';e={[string]$_.Scope}},@{n='policy';e={[string]$_.ExecutionPolicy}}); processPolicy=$env:PSExecutionPolicyPreference; tools=[ordered]@{}}
foreach ($name in @('git','node','npm','npx','gh','supabase','vercel','claude','codex','code','cx','cc')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    $where = @(& where.exe $name 2>&1 | ForEach-Object { "$_" }); $wc=$LASTEXITCODE
    $row=[ordered]@{path=$cmd.Source; where=$where; whereExit=$wc; exit=$null; output=''; ok=$false}
    if ($name -in 'cx','cc') { $row.ok=($wc -eq 0) }
    elseif ($cmd) {
        try { $LASTEXITCODE=-999; $v=@(& $name --version 2>&1 | ForEach-Object { "$_" }); $row.exit=$LASTEXITCODE; $row.output=$v -join "`n"; $row.ok=($LASTEXITCODE -eq 0 -and $v.Count -gt 0) }
        catch { $row.output=$_.Exception.Message }
    }
    $out.tools[$name]=$row
}
try { $out.extensions=@(& code --list-extensions 2>&1 | ForEach-Object { "$_" }); $out.extensionsExit=$LASTEXITCODE } catch { $out.extensions=@($_.Exception.Message); $out.extensionsExit=-1 }
$out | ConvertTo-Json -Depth 10
