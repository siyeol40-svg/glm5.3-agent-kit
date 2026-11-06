# Dense, fixed stage compositions. Pure specifications, no Office/media/model calls.
. (Join-Path $PSScriptRoot 'Proposal.Graphics.ps1')
function Get-ProposalDenseV6Layout($Stage) {
    $sid=[string]$Stage.id;$panels=@($Stage.panels)
    $roles=@{cause=@('system','evidence','causal','boundary');actions=@('action')*6;effects=@('outcomes','details','operation','boundary');rollout=@('coverage','expansion','checks','acceptance')}
    $kinds=@{cause=@(@('bullets'),@('table'),@('flow','bullets'),@('bullets'));actions=@(@('bullets'),@('bullets'),@('bullets'),@('bullets'),@('bullets'),@('bullets'));effects=@(@('metrics'),@('table','bullets'),@('bullets'),@('bullets'));rollout=@(@('table'),@('flow'),@('bullets'),@('bullets'))}
    if($Stage.layout_profile -cne 'reference-v6' -or -not $roles.ContainsKey($sid) -or $panels.Count -ne $roles[$sid].Count){throw 'DENSE_LAYOUT_UNSUPPORTED: stage/profile/fixed panel count'}
    for($i=0;$i -lt $panels.Count;$i++){
        $p=$panels[$i]
        if($p.role -cne $roles[$sid][$i] -or $p.kind -cnotin @($kinds[$sid][$i])){throw 'DENSE_LAYOUT_UNSUPPORTED: fixed panel role/kind'}
        if($sid -cne 'actions' -and $null -ne $p.outcome){throw 'DENSE_LAYOUT_UNSUPPORTED: outcome belongs to action cards only'}
        if($p.kind -ceq 'bullets' -and @($p.lines).Count -notin @(1,2,3,4,5,6)){throw 'DENSE_LAYOUT_UNSUPPORTED: one to six bullet lines'}
        if($p.kind -ceq 'flow' -and @($p.steps).Count -notin @(2,3,4)){throw 'DENSE_LAYOUT_UNSUPPORTED: two to four flow steps'}
        if($p.kind -ceq 'table'){
            if(@($p.table.headers).Count -notin @(2,3,4) -or @($p.table.rows).Count -notin @(1,2,3,4,5)){throw 'DENSE_LAYOUT_UNSUPPORTED: two to four table columns and one to five rows'}
            foreach($row in @($p.table.rows)){if(@($row).Count -ne @($p.table.headers).Count){throw 'DENSE_LAYOUT_UNSUPPORTED: table row dimensions'}}
        }
        if($p.kind -ceq 'metrics' -and @($p.metrics).Count -notin @(1,2,3)){throw 'DENSE_LAYOUT_UNSUPPORTED: one to three metrics'}
        if($sid -ceq 'actions' -and (-not $p.icon -or [string]::IsNullOrWhiteSpace([string]$p.outcome))){throw 'DENSE_LAYOUT_UNSUPPORTED: action icon/outcome required'}
    }
    $items=[Collections.Generic.List[object]]::new()
    $c=@{navy='#0C315F';blue='#27669C';ink='#1C314B';muted='#596A7F';edge='#D6E1EB';light='#F3F7FB';red='#BE3540';pink='#FFF4F3';green='#207C59';mint='#EDF6F0';gold='#A87221';sand='#FBF6EC'}
    function Measure-D6Text([string]$Value,[double]$Size){
        $units=0.0;foreach($ch in $Value.ToCharArray()){if([char]::IsWhiteSpace($ch)){$units+=.39}elseif([int]$ch -ge 0x2E80){$units+=1.03}elseif([char]::IsUpper($ch)){$units+=.71}else{$units+=.60}};return $units*$Size
    }
    function Wrap([string]$Value,[double]$W,[double]$H,[double]$Size){
        if([string]::IsNullOrWhiteSpace($Value)){throw 'DENSE_LAYOUT_EMPTY: required business text is empty'}
        $out=[Collections.Generic.List[string]]::new()
        foreach($para in ($Value -split '\r\n|\r|\n')){
            $line=''
            foreach($word in @($para -split '\s+'|Where-Object {$_ -ne ''})){
                if((Measure-D6Text $word $Size) -gt $W-2){throw ('TEXT_NEEDS_SHORTEN: V6 unbroken word exceeds fixed slot: '+$word)}
                $candidate=if($line){$line+' '+$word}else{$word}
                if((Measure-D6Text $candidate $Size) -gt $W-2){$out.Add($line);$line=$word}else{$line=$candidate}
            };$out.Add($line)
        }
        if($out.Count*$Size*1.25 -gt $H+.1){throw ('TEXT_NEEDS_SHORTEN: V6 text exceeds fixed slot: '+$Value)}
        return ($out.ToArray()-join "`r")
    }
    function Spec($Id,$Role,$Parent,$Kind,$X,$Y,$W,$H,$Text='',$Font=11.5,$Color='',$Fill='',$Edge='',$Bold=$false,$Primitive='',$Align='left',$Stroke=.8){
        if(-not $Color){$Color=$c.ink}
        $items.Add([pscustomobject][ordered]@{id=[string]$Id;role=[string]$Role;parent=[string]$Parent;kind=[string]$Kind;x=[double]$X;y=[double]$Y;w=[double]$W;h=[double]$H;text=[string]$Text;font_size=[double]$Font;font_bold=[bool]$Bold;color=[string]$Color;fill=[string]$Fill;line_color=[string]$Edge;primitive=[string]$Primitive;align=[string]$Align;line_width=[double]$Stroke;layout_revision='proposal-reference-r6'})
        if($Primitive -ceq 'roundrect'){$items[$items.Count-1]|Add-Member corner_radius .04}
    }
    function Text($Id,$Parent,$X,$Y,$W,$H,$Value,$Size=11.5,$Color='',$Bold=$false,$Align='left',$Role='body'){
        Spec $Id $Role $Parent 'text' $X $Y $W $H (Wrap ([string]$Value) $W $H $Size) $Size $Color '' '' $Bold '' $Align
    }
    function Rect($Id,$Parent,$X,$Y,$W,$H,$Fill='',$Edge='',$Role='detail') {Spec $Id $Role $Parent 'rect' $X $Y $W $H '' 11.5 '' $Fill $Edge}
    function Shape($Id,$Parent,$Type,$X,$Y,$W,$H,$Fill='',$Edge='',$Role='detail') {Spec $Id $Role $Parent 'shape' $X $Y $W $H '' 11.5 '' $Fill $Edge $false $Type}
    function Rule($Id,$Parent,$X,$Y,$W,$H,$Color,$Arrow=$false){Spec $Id $(if($Arrow){'connector'}else{'detail'}) $Parent 'line' $X $Y $W $H '' 11.5 '' '' $Color $false '' 'left' 1.1}
    function Figure($Id,$Parent,$Type,$X,$Y,$W,$H,$Color){
        if(-not $Type){$Type='check'}
        foreach($spec in @(Get-ProposalIllustrationSpecs -Prefix $Id -Parent $Parent -Type $Type -X $X -Y $Y -W $W -H $H -Color $Color -Revision 'proposal-reference-r6')){$items.Add($spec)}
    }
    function Panel($Id,$Box,$Heading,$Accent){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        Shape $Id 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $c.edge
        Rect ($Id+'-heading-band') $Id $x $y $w 25 $Accent
        Text ($Id+'-heading') $Id ($x+10) ($y+3) ($w-20) 19 $Heading 13 '#FFFFFF' $true 'left' 'section'
    }
    function Bullets($Id,$Panel,$Box,$Accent,$WithIcons=$false){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$lines=@($Panel.lines)
        $row=($h-36)/$lines.Count
        if($WithIcons){
            Figure ($Id+'-system-figure') $Id ([string]$Panel.icon) ($x+13) ($y+61) 74 97 $Accent
            Rule ($Id+'-system-divider') $Id ($x+97) ($y+34) 0 ($h-44) $c.edge
        }
        for($i=0;$i -lt $lines.Count;$i++){
            $ry=$y+30+$i*$row
            $ink=$c.ink;$fill=$c.light;$stateLabel=''
            if($Panel.line_states -and $i -lt @($Panel.line_states).Count){
                switch($Panel.line_states[$i]){
                    'supported'{$ink=$c.green;$fill=$c.mint}
                    'hypothesis'{$ink=$c.gold;$fill=$c.sand;$stateLabel='가설'}
                    'boundary'{$ink=$c.blue;$fill=$c.light;$stateLabel='적용 범위'}
                    'unknown'{$ink=$c.muted;$fill=$c.light;$stateLabel='미확인'}
                    default {throw 'DENSE_LAYOUT_UNSUPPORTED: line state'}
                }
            }
            $tight=$row -lt 25
            $gap=if($tight){1.0}else{3.0};$pad=if($tight){.5}else{2.0};$textH=if($tight){$row-2}else{$row-7}
            $rowX=if($WithIcons){$x+105}else{$x+9};$rowW=($x+$w-9)-$rowX
            Rect ($Id+'-row-'+$i) $Id $rowX $ry $rowW ($row-$gap) $fill
            $left=if($WithIcons){$x+116}else{$x+22}
            Rect ($Id+'-marker-'+$i) ($Id+'-row-'+$i) ($rowX+5) ($ry+5) 3 ([math]::Min(12,$row-10)) $Accent
            if($stateLabel){
                Text ($Id+'-state-'+$i) ($Id+'-row-'+$i) $left ($ry+$pad) 58 $textH $stateLabel 11.5 $ink $true 'left' 'label'
                $left+=64
            }
            Text ($Id+'-line-'+$i) ($Id+'-row-'+$i) $left ($ry+$pad) ($x+$w-17-$left) $textH $lines[$i] 11.5 $ink
        }
    }
    function Table($Id,$Panel,$Box){
        $x=$Box[0]+10;$y=$Box[1]+33;$w=$Box[2]-20;$h=$Box[3]-43
        $heads=@($Panel.table.headers);$rows=@($Panel.table.rows);$colCount=$heads.Count
        $headerH=24.0;$rowH=($h-$headerH)/$rows.Count
        $fractions=if($colCount -eq 2){@(.36,.64)}elseif($colCount -eq 3){@(.24,.38,.38)}else{@(.22,.26,.26,.26)}
        $cx=$x
        for($ci=0;$ci -lt $colCount;$ci++){
            $cw=$w*$fractions[$ci]
            Rect ($Id+'-header-'+$ci) $Id $cx $y $cw $headerH $c.navy $c.edge
            Text ($Id+'-header-text-'+$ci) ($Id+'-header-'+$ci) ($cx+6) ($y+3) ($cw-12) ($headerH-6) $heads[$ci] 11.5 '#FFFFFF' $true
            for($ri=0;$ri -lt $rows.Count;$ri++){
                $ry=$y+$headerH+$ri*$rowH;$fill=if($ri%2){'#FFFFFF'}else{$c.light}
                Rect ($Id+'-cell-'+$ri+'-'+$ci) $Id $cx $ry $cw $rowH $fill $c.edge
                Text ($Id+'-cell-text-'+$ri+'-'+$ci) ($Id+'-cell-'+$ri+'-'+$ci) ($cx+6) ($ry+3) ($cw-12) ($rowH-6) ([string]$rows[$ri][$ci]) 11.5 $c.ink ($ci -eq 0)
            };$cx+=$cw
        }
    }
    function Flow($Id,$Panel,$Box,$Accent){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$steps=@($Panel.steps);$gap=15.0;$cw=($w-20-$gap*($steps.Count-1))/$steps.Count
        for($i=0;$i -lt $steps.Count;$i++){
            $sx=$x+10+$i*($cw+$gap);$sy=$y+33;$sh=$h-43
            Rect ($Id+'-step-'+$i) $Id $sx $sy $cw $sh $c.light $c.edge
            $icon=if($Panel.step_icons -and $i -lt @($Panel.step_icons).Count){$Panel.step_icons[$i]}else{'check'}
            $iconH=[math]::Min(38,($sh-12)*.42)
            Figure ($Id+'-figure-'+$i) ($Id+'-step-'+$i) $icon ($sx+($cw-40)/2) ($sy+7) 40 $iconH $Accent
            Text ($Id+'-step-text-'+$i) ($Id+'-step-'+$i) ($sx+6) ($sy+$iconH+15) ($cw-12) ($sh-$iconH-20) $steps[$i] 11.5 $c.ink $true 'center'
            if($i -lt $steps.Count-1){Rule ($Id+'-arrow-'+$i) $Id ($sx+$cw+2) ($sy+$sh/2) ($gap-4) 0 $Accent $true}
        }
    }
    function MetricStrip($Id,$Panel,$Box){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$metrics=@($Panel.metrics);$cw=($w-20-12*($metrics.Count-1))/$metrics.Count
        for($i=0;$i -lt $metrics.Count;$i++){
            $m=$metrics[$i];$mx=$x+10+$i*($cw+12);$my=$y+32
            Rect ($Id+'-metric-'+$i) $Id $mx $my $cw ($h-41) $c.mint
            Text ($Id+'-label-'+$i) ($Id+'-metric-'+$i) ($mx+12) ($my+1) ($cw-24) 17 $m.label 11.5 $c.green $true 'left' 'label'
            Text ($Id+'-value-'+$i) ($Id+'-metric-'+$i) ($mx+12) ($my+19) ($cw-24) 32 $m.value_text 25 $c.navy $true 'left' 'metric'
            if($m.detail){Text ($Id+'-metric-detail-'+$i) ($Id+'-metric-'+$i) ($mx+12) ($my+51) ($cw-24) 16 $m.detail 11 $c.muted $false 'left' 'detail'}
        }
    }
    function ActionCard($Id,$Panel,$Box,[int]$Index){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        Shape $Id 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $c.edge
        Rect ($Id+'-header-band') $Id $x $y $w 56 $c.light
        Text ($Id+'-index') $Id ($x+9) ($y+7) 19 20 ([string]($Index+1)) 13 $c.blue $true 'center' 'section'
        Text ($Id+'-title') $Id ($x+32) ($y+6) ($w-40) 43 $Panel.title 13 $c.navy $true 'left' 'section'
        Figure ($Id+'-figure') $Id $Panel.icon ($x+($w-70)/2) ($y+68) 70 55 $c.blue
        Rule ($Id+'-rule') $Id ($x+12) ($y+137) ($w-24) 0 $c.edge
        $lines=@($Panel.lines);$row=150.0/$lines.Count
        for($i=0;$i -lt $lines.Count;$i++){
            $ry=$y+148+$i*$row
            Rect ($Id+'-bullet-'+$i) $Id ($x+10) ($ry+4) 3 9 $c.blue
            Text ($Id+'-line-'+$i) $Id ($x+20) $ry ($w-30) ($row-6) $lines[$i] 11.5
        }
        Rect ($Id+'-outcome-box') $Id ($x+8) ($y+$h-48) ($w-16) 40 $c.mint
        Text ($Id+'-outcome') ($Id+'-outcome-box') ($x+15) ($y+$h-44) ($w-30) 31 $Panel.outcome 11.5 $c.green $true 'center'
    }
    $labels=@{cause='원인 분석';actions='개선 사항';effects='효과 파악';rollout='횡전개'};$nums=@{cause='03';actions='04';effects='05';rollout='06'}
    Rect 'canvas' '' 0 0 960 540 '#FFFFFF'
    Shape 'page-band' 'canvas' 'roundrect' 0 0 74 69 $c.navy
    Text 'page-number' 'page-band' 15 14 50 39 $nums[$sid] 28 '#FFFFFF' $true 'center' 'title'
    Text 'section-name' 'canvas' 90 16 127 33 $labels[$sid] 23 $c.navy $true 'left' 'title'
    Rule 'header-divider' 'canvas' 222 21 0 24 $c.navy
    Text 'page-title' 'canvas' 238 15 702 36 $Stage.title 25 $c.navy $true 'left' 'title'
    Text 'page-subtitle' 'canvas' 90 57 844 21 $Stage.subtitle 11.5 $c.muted
    Rule 'header-rule' 'canvas' 20 88 920 0 $c.edge
    Text 'page-citation' 'canvas' 20 475 920 20 $Stage.citation 10 $c.muted $false 'left' 'source'
    Rect 'footer-band' 'canvas' 12 503 936 29 $c.navy
    Text 'page-takeaway' 'footer-band' 24 508 912 19 $Stage.takeaway 12.5 '#FFFFFF' $true 'left' 'conclusion'
    if($sid -ceq 'actions'){
        for($i=0;$i -lt 6;$i++){
            ActionCard ('panel-'+$i) $panels[$i] @((20+$i*155),104,145,358) $i
        }
    }else{
        $boxes=switch($sid){
            'cause' {@(@(20,104,343,200),@(377,104,563,200),@(20,316,530,146),@(564,316,376,146))}
            'effects' {@(@(20,104,920,113),@(20,229,420,233),@(454,229,243,233),@(711,229,229,233))}
            'rollout' {@(@(20,104,412,210),@(446,104,494,210),@(20,326,454,136),@(488,326,452,136))}
        }
        for($i=0;$i -lt $panels.Count;$i++){
            $p=$panels[$i];$id='panel-'+$i;$box=$boxes[$i]
            $accent=if($sid -ceq 'rollout'){$c.gold}elseif($p.role -ceq 'outcomes'){$c.green}elseif($p.role -ceq 'causal'){$c.red}else{$c.navy}
            Panel $id $box $p.title $accent
            switch($p.kind){
                'bullets' {Bullets $id $p $box $accent ($p.role -ceq 'system')}
                'table' {Table $id $p $box}
                'flow' {Flow $id $p $box $accent}
                'metrics' {MetricStrip $id $p $box}
            }
        }
    }
    # No input leaf may disappear merely because a renderer branch forgot it.
    $leaves=[Collections.Generic.List[string]]::new()
    foreach($field in @('title','subtitle','takeaway','citation')){$leaves.Add([string]$Stage.$field)}
    foreach($p in $panels){
        $leaves.Add([string]$p.title)
        if($p.outcome){$leaves.Add([string]$p.outcome)}
        switch($p.kind){
            'bullets' {foreach($v in $p.lines){$leaves.Add([string]$v)}}
            'flow' {foreach($v in $p.steps){$leaves.Add([string]$v)}}
            'table' {foreach($v in $p.table.headers){$leaves.Add([string]$v)};foreach($row in $p.table.rows){foreach($v in $row){$leaves.Add([string]$v)}}}
            'metrics' {foreach($m in $p.metrics){foreach($key in @('label','value_text','detail')){if($m.$key){$leaves.Add([string]$m.$key)}}}}
        }
    }
    $display=@($items|Where-Object {$_.kind -ceq 'text'}|ForEach-Object {([string]$_.text)-replace '\s+',''})
    foreach($leaf in $leaves){if((($leaf-replace '\s+','') -cnotin $display)){throw ('DENSE_LAYOUT_CONTENT_MISSING: '+$leaf)}}
    return $items.ToArray()
}
