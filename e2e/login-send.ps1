# 로그인 E2E 키 입력 — base64(UTF-8) 글자를 샌드박스 콘솔 다리의 입력함에 넣는다. 줄바꿈 = Enter.
# -Shot 이면 화면 캡처 요청만 넣는다.
# -Request again|finish 이면 로그인 창을 다시 열거나(again) 마무리 점검으로 넘어간다(finish).
param([Parameter(Mandatory)][string]$RunId,[string]$B64='',[string]$Shot='',[ValidateSet('','again','finish')][string]$Request='')
$o=Join-Path 'C:\AutoFrogE2E' "$RunId\L1\out\L1"
if ($Shot) { [IO.File]::WriteAllText((Join-Path $o "shot-$Shot.req"),'1'); 'shot requested'; exit 0 }
if ($Request) { [IO.File]::WriteAllText((Join-Path $o "$Request.req"),'1'); "$Request requested"; exit 0 }
$text=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($B64))
$name=(Get-Date).ToString('HHmmssfff')+'.txt'
[IO.File]::WriteAllText((Join-Path $o "in\$name"),$text,(New-Object Text.UTF8Encoding $false))
"queued $name"
