# Shared fixed canvas and native primitives. No Office/model/media/network calls.
. (Join-Path $PSScriptRoot 'Proposal.Graphics.ps1')
function Measure-PV7Text([string]$Text,[double]$Size){
    $n=0.0;foreach($ch in $Text.ToCharArray()){if([char]::IsWhiteSpace($ch)){$n+=.39}elseif([int]$ch -ge 0x2E80){$n+=1.03}elseif([char]::IsUpper($ch)){$n+=.71}else{$n+=.60}};return $n*$Size
}
function ConvertTo-PV7WrappedText([string]$Text,[double]$W,[double]$H,[double]$Size){
    if([string]::IsNullOrWhiteSpace($Text)){throw 'V7_TEXT_EMPTY: business text required'}
    $result=[Collections.Generic.List[string]]::new()
    foreach($paragraph in ($Text -split '\r\n|\r|\n')){
        $line='';foreach($word in @($paragraph -split '\s+'|Where-Object {$_ -ne ''})){
            if((Measure-PV7Text $word $Size) -gt $W-2){throw ('TEXT_NEEDS_SHORTEN: V7 word exceeds slot: '+$word)}
            $candidate=if($line){$line+' '+$word}else{$word}
            if((Measure-PV7Text $candidate $Size) -gt $W-2){$result.Add($line);$line=$word}else{$line=$candidate}
        };$result.Add($line)
    }
    # Rebalance a short final word instead of leaving a Korean action alone.
    # Fixed size/line count are preserved; words and their order never change.
    for($i=1;$i -lt $result.Count;$i++){
        $tail=@($result[$i] -split '\s+')
        if($tail.Count -ne 1 -or (Measure-PV7Text $result[$i] $Size) -gt $W*.3){continue}
        $prior=@($result[$i-1] -split '\s+')
        if($prior.Count -lt 2){continue}
        $head=($prior[0..($prior.Count-2)] -join ' ')
        $candidate=$prior[-1]+' '+$result[$i]
        if((Measure-PV7Text $head $Size) -ge $W*.4 -and (Measure-PV7Text $candidate $Size) -le $W-2){$result[$i-1]=$head;$result[$i]=$candidate}
    }
    if($result.Count*$Size*1.25 -gt $H+.1){throw ('TEXT_NEEDS_SHORTEN: V7 text exceeds slot: '+$Text)}
    return ($result.ToArray()-join "`r")
}
function Add-PV7Spec($Scene,[string]$Id,[string]$Role,[string]$Parent,[string]$Kind,[double]$X,[double]$Y,[double]$W,[double]$H,[string]$Text='',[double]$Font=11.5,[string]$Color='',[string]$Fill='',[string]$Line='',[bool]$Bold=$false,[string]$Primitive='',[string]$Align='left',[double]$Stroke=.8){
    if(-not $Color){$Color=$Scene.theme.ink}
    foreach($v in @($X,$Y,$W,$H)){if([double]::IsNaN($v) -or [double]::IsInfinity($v)){throw 'V7_GEOMETRY: finite values required'}}
    if($X -lt 0 -or $Y -lt 0 -or $W -lt 0 -or $H -lt 0 -or $X+$W -gt 960.01 -or $Y+$H -gt 540.01){throw ('V7_GEOMETRY: canvas overflow '+$Id)}
    $spec=[pscustomobject][ordered]@{id=$Id;role=$Role;parent=$Parent;kind=$Kind;x=$X;y=$Y;w=$W;h=$H;text=$Text;font_size=$Font;font_bold=$Bold;color=$Color;fill=$Fill;line_color=$Line;primitive=$Primitive;align=$Align;line_width=$Stroke;layout_revision='proposal-reference-r7'}
    if($Primitive -ceq 'roundrect'){$spec|Add-Member corner_radius .035}
    $Scene.shapes.Add($spec)
}
function Add-PV7Text($Scene,[string]$Id,[string]$Parent,[double]$X,[double]$Y,[double]$W,[double]$H,[string]$Text,[double]$Size=11.5,[string]$Color='',[bool]$Bold=$false,[string]$Align='left',[string]$Role='body'){
    $wrapped=ConvertTo-PV7WrappedText $Text $W $H $Size
    Add-PV7Spec $Scene $Id $Role $Parent 'text' $X $Y $W $H $wrapped $Size $Color '' '' $Bold '' $Align
}
function Add-PV7Box($Scene,[string]$Id,[string]$Parent,[double]$X,[double]$Y,[double]$W,[double]$H,[string]$Fill,[string]$Line='',[string]$Primitive='rect'){
    $kind=if($Primitive -ceq 'rect'){'rect'}else{'shape'}
    Add-PV7Spec $Scene $Id 'detail' $Parent $kind $X $Y $W $H '' 11.5 '' $Fill $Line $false $(if($kind -ceq 'shape'){$Primitive}else{''})
}
function Add-PV7Line($Scene,[string]$Id,[string]$Parent,[double]$X,[double]$Y,[double]$W,[double]$H,[string]$Color,[bool]$Arrow=$false,[double]$Stroke=1){
    if(($W -eq 0 -and $H -eq 0) -or ($W -ne 0 -and $H -ne 0)){throw 'V7_LINE: only horizontal or vertical positive lines'}
    Add-PV7Spec $Scene $Id $(if($Arrow){'connector'}else{'detail'}) $Parent 'line' $X $Y $W $H '' 11.5 '' '' $Color $false '' 'left' $Stroke
}
function Add-PV7Figure($Scene,[string]$Id,[string]$Parent,[string]$Type,[double]$X,[double]$Y,[double]$W,[double]$H,[string]$Color){
    foreach($v in @(Get-ProposalIllustrationSpecs -Prefix $Id -Parent $Parent -Type $Type -X $X -Y $Y -W $W -H $H -Color $Color -Revision 'proposal-reference-r7')){$Scene.shapes.Add($v)}
}
function Add-PV7Section($Scene,[string]$Id,[string]$Parent,[double]$X,[double]$Y,[double]$W,[string]$Heading,[string]$Color=''){
    if(-not $Color){$Color=$Scene.theme.navy}
    Add-PV7Box $Scene ($Id+'-mark') $Parent $X ($Y+3) 3 13 $Color
    Add-PV7Text $Scene ($Id+'-title') $Parent ($X+10) $Y ($W-10) 20 $Heading 13 $Color $true 'left' 'section'
}
function New-ProposalV7Scene($Stage){
    $t=@{navy='#0D2A46';blue='#176EA5';cyan='#0B9AB2';green='#208562';amber='#AC752B';ink='#203349';muted='#5D7084';edge='#D7E1E9';light='#F2F6F9';white='#FFFFFF';red='#B94A4A';mint='#EAF5F0';sand='#FAF3E8'}
    $s=[pscustomobject]@{shapes=[Collections.Generic.List[object]]::new();theme=$t;stage=$Stage}
    $labels=@{cause='원인 분석';actions='개선 사항';effects='효과 파악';rollout='횡전개'};$numbers=@{cause='03';actions='04';effects='05';rollout='06'}
    if(-not $labels.ContainsKey([string]$Stage.id)){throw 'V7_STAGE_UNSUPPORTED'}
    Add-PV7Box $s 'canvas' '' 0 0 960 540 $t.white
    Add-PV7Box $s 'page-band' 'canvas' 20 14 44 42 $t.navy '' 'roundrect'
    Add-PV7Text $s 'page-number' 'page-band' 23 18 38 32 $numbers[$Stage.id] 24 $t.white $true 'center' 'title'
    Add-PV7Text $s 'section-name' 'canvas' 79 14 132 28 $labels[$Stage.id] 18 $t.navy $true 'left' 'section'
    Add-PV7Line $s 'header-divider' 'canvas' 210 20 0 22 $t.edge $false .8
    Add-PV7Text $s 'page-title' 'canvas' 225 12 715 32 $Stage.title 23 $t.navy $true 'left' 'title'
    Add-PV7Text $s 'page-subtitle' 'canvas' 79 49 861 20 $Stage.subtitle 11.5 $t.muted
    Add-PV7Line $s 'header-rule' 'canvas' 20 78 920 0 $t.edge $false .8
    Add-PV7Text $s 'page-citation' 'canvas' 20 481 920 16 $Stage.citation 10 $t.muted $false 'left' 'source'
    Add-PV7Box $s 'footer-band' 'canvas' 20 507 920 26 $t.navy
    Add-PV7Text $s 'page-takeaway' 'footer-band' 31 511 898 18 $Stage.takeaway 12.5 $t.white $true 'left' 'conclusion'
    return $s
}
function Complete-ProposalV7Scene($Scene,$Stage){
    $leaves=[Collections.Generic.List[string]]::new()
    foreach($f in @('title','subtitle','takeaway','citation')){$leaves.Add([string]$Stage.$f)}
    foreach($p in @($Stage.panels)){
        $leaves.Add([string]$p.title)
        if($p.outcome){$leaves.Add([string]$p.outcome)}
        switch($p.kind){
            'bullets' {foreach($v in $p.lines){$leaves.Add([string]$v)}}
            'flow' {foreach($v in $p.steps){$leaves.Add([string]$v)}}
            'table' {foreach($v in $p.table.headers){$leaves.Add([string]$v)};foreach($r in $p.table.rows){foreach($v in $r){$leaves.Add([string]$v)}}}
            'metrics' {foreach($m in $p.metrics){foreach($f in @('label','value_text','detail')){if($m.$f){$leaves.Add([string]$m.$f)}}}}
            default {throw 'V7_CONTENT_UNSUPPORTED: native semantic panel kind'}
        }
    }
    $text=@($Scene.shapes|Where-Object kind -eq text|ForEach-Object {([string]$_.text)-replace '\s+',''})
    foreach($v in $leaves){if(($v-replace '\s+','') -cnotin $text){throw ('V7_CONTENT_MISSING: '+$v)}}
    $ids=@{}
    foreach($v in $Scene.shapes){if($ids.ContainsKey($v.id)){throw ('V7_DUPLICATE_SHAPE: '+$v.id)};$ids[$v.id]=$true}
    return $Scene.shapes.ToArray()
}
