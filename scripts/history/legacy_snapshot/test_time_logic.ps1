# 测试时段判断逻辑
function Test-TimeSlot {
  param([int]$Hour, [int]$Minute, [string]$Expected)

  $min = $Hour * 60 + $Minute
  $isQuiet = (($min -ge 760 -and $min -lt 840) -or ($min -ge 1260) -or ($min -lt 480))
  $mode = if ($isQuiet) {"Quiet"} else {"Game"}

  $status = if ($mode -eq $Expected) {"PASS"} else {"FAIL"}
  Write-Host "$($Hour.ToString('00')):$($Minute.ToString('00')) => $mode (min=$min) $status"
}

Write-Host "`n=== 时段判断逻辑测试 ===" -ForegroundColor Cyan
Test-TimeSlot -Hour 7 -Minute 59 -Expected "Quiet"
Test-TimeSlot -Hour 8 -Minute 0 -Expected "Game"
Test-TimeSlot -Hour 12 -Minute 39 -Expected "Game"
Test-TimeSlot -Hour 12 -Minute 40 -Expected "Quiet"
Test-TimeSlot -Hour 13 -Minute 59 -Expected "Quiet"
Test-TimeSlot -Hour 14 -Minute 0 -Expected "Game"
Test-TimeSlot -Hour 20 -Minute 59 -Expected "Game"
Test-TimeSlot -Hour 21 -Minute 0 -Expected "Quiet"
Test-TimeSlot -Hour 23 -Minute 59 -Expected "Quiet"
Test-TimeSlot -Hour 0 -Minute 0 -Expected "Quiet"
