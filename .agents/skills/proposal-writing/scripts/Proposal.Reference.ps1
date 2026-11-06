# Approved engineering compositions. Native editable primitives; no Office, media or network calls.
function Get-ProposalReferenceLayout($Stage) {
    $id=[string]$Stage.id;$panels=@($Stage.panels)
    if([string]::IsNullOrWhiteSpace([string]$Stage.citation)){throw 'REFERENCE_SOURCE_REQUIRED: provide a human-readable business source caption'}
    foreach($panel in $panels){
        if($panel.kind -eq 'bullets' -and -not $panel.icon){throw 'REFERENCE_ICON_REQUIRED: choose an approved illustrative icon'}
        if($panel.kind -eq 'flow' -and @($panel.step_icons).Count -ne @($panel.steps).Count){throw 'REFERENCE_ICON_REQUIRED: supply an approved icon for every flow node'}
    }
    $required=@{problem=4;cause=4;effects=3;rollout=3}
    if(($id -eq 'actions' -and ($panels.Count -lt 3 -or $panels.Count -gt 6)) -or ($id -ne 'actions' -and (-not $required.ContainsKey($id) -or $panels.Count -ne $required[$id]))){throw 'REFERENCE_LAYOUT_UNSUPPORTED: use a documented panel count or prepare a new tested component'}
    $patterns=@{problem=@('bullets','flow','bullets','bullets');cause=@('bullets','table','bullets','flow');effects=@('metrics','table','flow');rollout=@('table','flow','bullets')}
    if($id -ne 'actions'){
        for($slot=0;$slot -lt $panels.Count;$slot++){if($panels[$slot].kind -ne $patterns[$id][$slot]){throw 'REFERENCE_LAYOUT_UNSUPPORTED: component order differs from the verified page profile'}}
    }
    if($id -eq 'effects' -and $panels[2].relationship -ne 'sum'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: this effects profile requires a verified additive cost strip; do not invent financial inputs'}
    $items=New-Object 'Collections.Generic.List[object]'
    $c=@{navy='#092D63';blue='#195A91';ink='#17304F';gray='#56677C';edge='#D4DDE7';pale='#F2F6FA';red='#BE2529';pink='#FFF2F1';green='#28784B';mint='#EDF7F0';gold='#A86C13'}
    function Measure-R2Text([string]$Text,[double]$Size){
        $units=0.0;foreach($ch in $Text.ToCharArray()){
            if([char]::IsWhiteSpace($ch)){$units+=0.40}elseif([int]$ch -ge 0x2E80){$units+=1.04}elseif([char]::IsUpper($ch)){$units+=0.72}else{$units+=0.61}
        };return $units*$Size
    }
    function Wrap-R2Text([string]$Text,[double]$W,[double]$H,[double]$Font){
        $rows=New-Object 'Collections.Generic.List[string]'
        foreach($paragraph in ($Text -split '\r\n|\r|\n')){
            $line='';foreach($word in ($paragraph -split ' ')){
                if(-not $word){continue}
                if((Measure-R2Text $word $Font) -gt $W-2){throw ('TEXT_NEEDS_SHORTEN: a word does not fit the approved font/width: '+$word)}
                $candidate=if($line){$line+' '+$word}else{$word}
                if((Measure-R2Text $candidate $Font) -gt $W-2){$rows.Add($line);$line=$word}else{$line=$candidate}
            };$rows.Add($line)
        }
        if($rows.Count*$Font*1.24 -gt $H+0.25){throw ('TEXT_NEEDS_SHORTEN: too many semantic lines for the fixed component: '+$Text)}
        return ($rows.ToArray() -join "`r")
    }
    function Add-R2Spec($Name,$Role,$Parent,$Kind,$X,$Y,$W,$H,$Text='',$Font=12,$Color='',$Fill='',$Line='',$Bold=$false,$Primitive='',$Align='left',$Stroke=1){
        if(-not $Color){$Color=$c.ink}
        $items.Add([pscustomobject][ordered]@{id=[string]$Name;role=[string]$Role;parent=[string]$Parent;kind=[string]$Kind;x=[double]$X;y=[double]$Y;w=[double]$W;h=[double]$H;text=[string]$Text;font_size=[double]$Font;font_bold=[bool]$Bold;color=[string]$Color;fill=[string]$Fill;line_color=[string]$Line;primitive=[string]$Primitive;align=[string]$Align;line_width=[double]$Stroke;layout_revision='proposal-reference-r2'})
        if($Primitive -eq 'roundrect'){$items[$items.Count-1]|Add-Member -NotePropertyName corner_radius -NotePropertyValue 0.04}
    }
    function Add-R2Text($Name,$Parent,$X,$Y,$W,$H,$Text,$Font=12,$Color='',$Bold=$false,$Align='left',$Role='body'){
        $wrapped=Wrap-R2Text ([string]$Text) $W $H $Font
        Add-R2Spec $Name $Role $Parent 'text' $X $Y $W $H $wrapped $Font $Color '' '' $Bold '' $Align
    }
    function Add-R2Shape($Name,$Parent,$Primitive,$X,$Y,$W,$H,$Fill='',$Line='',$Stroke=1,$Role='detail'){
        Add-R2Spec $Name $Role $Parent 'shape' $X $Y $W $H '' 12 '' $Fill $Line $false $Primitive 'left' $Stroke
    }
    function Add-R2Rect($Name,$Parent,$X,$Y,$W,$H,$Fill='',$Line='',$Role='detail'){
        Add-R2Spec $Name $Role $Parent 'rect' $X $Y $W $H '' 12 '' $Fill $Line $false '' 'left' 1
    }
    function Add-R2Line($Name,$Parent,$X,$Y,$W,$H,$Color,$Stroke=1.2){Add-R2Spec $Name 'detail' $Parent 'line' $X $Y $W $H '' 12 '' '' $Color $false '' 'left' $Stroke}
    function Panel($Name,$Box,$Title,$Accent){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        Add-R2Shape $Name 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $c.edge 1 'panel'
        $chip=[math]::Min($w-14,[math]::Max(126,(Measure-R2Text $Title 13)+24))
        Add-R2Shape ($Name+'-heading-bg') $Name 'roundrect' ($x+6) ($y+4) $chip 23 $Accent '' 1
        Add-R2Text ($Name+'-heading') ($Name+'-heading-bg') ($x+13) ($y+7) ($chip-14) 18 $Title 13 '#FFFFFF' $true 'left' 'section'
    }
    function Icon($Prefix,$Parent,$Type,$X,$Y,$W,$H,$Color){
        if(-not $Type){$Type='check'}
        $state=@{i=0};$scaleX=$W/80.0;$scaleY=$H/64.0
        function IS($Primitive,$A,$B,$D,$E,$Fill='',$Edge=''){$state.i++;if(-not $Edge){$Edge=$Color};Add-R2Shape ($Prefix+'-'+$state.i) $Parent $Primitive ($X+$A*$scaleX) ($Y+$B*$scaleY) ($D*$scaleX) ($E*$scaleY) $Fill $Edge 1.3}
        function IR($A,$B,$D,$E,$Fill='',$Edge=''){$state.i++;if(-not $Edge){$Edge=$Color};Add-R2Rect ($Prefix+'-'+$state.i) $Parent ($X+$A*$scaleX) ($Y+$B*$scaleY) ($D*$scaleX) ($E*$scaleY) $Fill $Edge}
        function IL($A,$B,$D,$E){$state.i++;Add-R2Line ($Prefix+'-'+$state.i) $Parent ($X+$A*$scaleX) ($Y+$B*$scaleY) ($D*$scaleX) ($E*$scaleY) $Color 1.5}
        switch($Type){
            'heat_exchanger' {
                IS 'roundrect' 8 7 64 50 '#F5F8FC'
                IR 1 20 8 12 $Color;IR 71 34 8 12 $Color
                foreach($yy in @(18,26,34,42)){IL 17 $yy 46 0}
                if($Color -ne $c.green){foreach($yy in @(21,36,46)){IS 'ellipse' 50 $yy 7 5 '#F2B3A8' '#C6574B'}}
                IL 17 14 0 34;IL 63 14 0 34
            }
            'oil' {IS 'ellipse' 22 8 36 44 '#F5E6C8';IS 'ellipse' 29 31 8 9 '#C69B45';IS 'ellipse' 44 21 7 7 '#C69B45'}
            'water' {IS 'ellipse' 22 8 36 44 '#E5F2FA';foreach($yy in @(29,36,43)){IL 29 $yy 23 0}}
            'microbe' {IS 'ellipse' 22 12 36 36 '#F7DFDD';foreach($pair in @(@(12,19),@(13,39),@(34,3),@(59,18),@(59,40),@(35,51))){IS 'ellipse' $pair[0] $pair[1] 7 7 '#F1B3AA'};IS 'ellipse' 31 23 5 5 $Color;IS 'ellipse' 43 33 5 5 $Color}
            'clean' {IR 36 5 9 29 '#E5EFF8';IR 19 32 43 13 '#D7E8F2';foreach($xx in @(24,33,42,51,59)){IL $xx 45 0 10};IS 'ellipse' 9 10 9 11 '#CAE4F4'}
            'training' {IR 8 7 64 36 '#F4F7FB';IL 18 17 40 0;IL 18 26 29 0;IL 18 34 34 0;IR 38 44 5 13 $Color;IL 23 58 35 0}
            'rotation' {IS 'ellipse' 3 19 25 25 '#E7F1F9';IS 'ellipse' 51 19 25 25 '#EEF6ED';IS 'rightArrow' 29 9 21 10 $Color $Color;IL 30 51 20 0}
            'shield' {IS 'roundrect' 19 6 42 49 '#EAF4EE';IS 'ellipse' 30 22 20 20 '#FFFFFF';IL 40 27 0 10;IL 35 32 10 0}
            'monitor' {IR 7 7 66 40 '#F4F8FC';IL 16 20 20 0;IL 16 28 43 0;IL 16 36 32 0;IR 36 48 8 9 $Color;IL 23 58 35 0}
            'cost' {IS 'ellipse' 15 7 50 50 '#FFF5E5';$state.i++;Add-R2Text ($Prefix+'-'+$state.i) $Parent ($X+25*$scaleX) ($Y+13*$scaleY) (30*$scaleX) (36*$scaleY) '$' ([math]::Max(11.5,[math]::Min(26,28*$scaleY))) $Color $true 'center' 'label'}
            'factory' {IR 10 24 60 32 '#F0F5FA';IR 15 5 9 20 $Color;IR 33 12 9 13 $Color;foreach($xx in @(20,37,54)){IR $xx 35 8 10 '#CADBE9'}}
            'check' {IS 'ellipse' 17 7 46 46 '#EFF7F1';$state.i++;Add-R2Text ($Prefix+'-'+$state.i) $Parent ($X+23*$scaleX) ($Y+13*$scaleY) (34*$scaleX) (34*$scaleY) '✓' ([math]::Max(11.5,[math]::Min(24,26*$scaleY))) $Color $true 'center' 'label'}
            default {throw ('REFERENCE_ICON_UNSUPPORTED: '+$Type)}
        }
    }
    function Outcome($Name,$Parent,$X,$Y,$W,$H,$Text){
        Add-R2Shape ($Name+'-bg') $Parent 'roundrect' $X $Y $W $H $c.pale ''
        Add-R2Text $Name ($Name+'-bg') ($X+7) ($Y+5) ($W-14) ($H-10) $Text 11.5 $c.gray $false 'center' 'detail'
    }
    function Bullets($Name,$Panel,$Box){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$lines=@($Panel.lines)
        if($w -gt 700 -and $h -lt 170 -and $lines.Count -eq 3){
            $cw=($w-48)/3
            for($i=0;$i -lt 3;$i++){
                $px=$x+12+$i*($cw+12);Add-R2Shape ($Name+'-checkcard-'+$i) $Name 'roundrect' $px ($y+38) $cw ($h-49) $c.pale ''
                Icon ($Name+'-icon-'+$i) ($Name+'-checkcard-'+$i) $Panel.icon ($px+10) ($y+52) 40 34 $c.green
                Add-R2Text ($Name+'-body-'+$i) ($Name+'-checkcard-'+$i) ($px+57) ($y+56) ($cw-67) 40 $lines[$i] 12 $c.ink $true
            };return
        }
        if($h -gt 200){
            if($id -eq 'problem' -and $Panel.icon -eq 'heat_exchanger'){
                $iw=($w-34)/2;$ih=82.0
                Add-R2Text ($Name+'-clean-label') $Name ($x+12) ($y+39) $iw 19 '오염막 없음' 11.5 $c.green $true 'center' 'label'
                Add-R2Text ($Name+'-fouled-label') $Name ($x+22+$iw) ($y+39) $iw 19 '생물막 형성' 11.5 $c.red $true 'center' 'label'
                Icon ($Name+'-icon-clean') $Name 'heat_exchanger' ($x+12) ($y+64) $iw $ih $c.green
                Icon ($Name+'-icon-fouled') $Name 'heat_exchanger' ($x+22+$iw) ($y+64) $iw $ih $c.red
            }else{
                $iw=[math]::Min(210,$w-50);$ih=94.0
                Icon ($Name+'-icon') $Name $Panel.icon ($x+($w-$iw)/2) ($y+39) $iw $ih $c.blue
            }
            $ty=$y+153;$row=23.0
            for($i=0;$i -lt $lines.Count;$i++){Add-R2Text ($Name+'-body-'+$i) $Name ($x+15) ($ty+$row*$i) ($w-30) 20 $lines[$i] 12.5 $c.ink ($i -eq 0)}
            if($Panel.outcome){Outcome ($Name+'-outcome') $Name ($x+10) ($y+$h-37) ($w-20) 27 $Panel.outcome}
        } else {
            Icon ($Name+'-icon') $Name $Panel.icon ($x+13) ($y+40) 53 45 $c.blue
            Add-R2Text ($Name+'-body') $Name ($x+78) ($y+38) ($w-92) ($h-45) ($lines -join "`r") 12 $c.ink $false
        }
    }
    function Table($Name,$Panel,$Box){
        $x=$Box[0]+10;$y=$Box[1]+37;$w=$Box[2]-20;$available=$Box[3]-49
        $heads=@($Panel.table.headers);$rows=@($Panel.table.rows);$rowH=[math]::Min(49,$available/($rows.Count+1));$colW=$w/$heads.Count
        if($rowH -lt 25 -or $colW -lt 80){throw 'REFERENCE_LAYOUT_UNSUPPORTED: dense table'}
        for($rr=0;$rr -le $rows.Count;$rr++){
            $vals=if($rr -eq 0){$heads}else{@($rows[$rr-1])}
            for($cc=0;$cc -lt $heads.Count;$cc++){
                $cell=$Name+'-cell-'+$rr+'-'+$cc;$fill=if($rr -eq 0){$c.navy}elseif($rr -eq $rows.Count -and $id -eq 'effects'){$c.pink}elseif($rr%2){'#FFFFFF'}else{$c.pale}
                Add-R2Rect $cell $Name ($x+$cc*$colW) ($y+$rr*$rowH) $colW $rowH $fill $c.edge
                $ink=if($rr -eq 0){'#FFFFFF'}elseif($rr -eq $rows.Count -and $id -eq 'effects'){$c.red}else{$c.ink}
                Add-R2Text ($cell+'-text') $cell ($x+$cc*$colW+7) ($y+$rr*$rowH+7) ($colW-14) ($rowH-12) $vals[$cc] 12 $ink ($rr -eq 0 -or ($id -eq 'effects' -and $rr -eq $rows.Count))
            }
        }
    }
    function Flow($Name,$Panel,$Box){
        $steps=@($Panel.steps);$icons=@($Panel.step_icons);$x=$Box[0]+12;$y=$Box[1]+37;$w=$Box[2]-24;$h=$Box[3]-49
        $cost=$Panel.relationship -eq 'sum';$gap=if($cost){34.0}else{21.0};$nw=($w-($steps.Count-1)*$gap)/$steps.Count
        if($cost){$y=$Box[1]+29;$h=$Box[3]-35}
        if($nw -lt 95){throw 'REFERENCE_LAYOUT_UNSUPPORTED: flow label needs a wider column'}
        $outH=if($Panel.outcome){$(if($cost){16.0}else{28.0})}else{0.0};$nh=$h-$outH
        if(-not $cost){$nh=[math]::Min(148,$nh)}
        for($i=0;$i -lt $steps.Count;$i++){
            $nx=$x+$i*($nw+$gap);$node=$Name+'-step-'+$i;$accent=if($Panel.tone -eq 'danger'){$c.red}else{$c.blue}
            $fill=if($cost -and $i -eq $steps.Count-1){$c.pink}elseif($Panel.tone -eq 'danger'){$c.pink}else{$c.pale}
            Add-R2Shape $node $Name 'roundrect' $nx $y $nw $nh $fill $c.edge
            $icon=if($icons.Count -eq $steps.Count){$icons[$i]}elseif($Panel.icon){$Panel.icon}else{'check'}
            if($cost){
                $firstSpace=([string]$steps[$i]).IndexOf(' ')
                $marker=([string]$steps[$i]).IndexOf('USD ')
                if($marker -lt 0){$marker=$firstSpace}
                $label=([string]$steps[$i]).Substring(0,$marker).Trim();$value=([string]$steps[$i]).Substring($marker).Trim()
                Add-R2Text ($node+'-label') $node ($nx+8) ($y+1) ($nw-16) 14 $label 10.5 $c.ink $true 'center' 'source'
                Add-R2Text ($node+'-value') $node ($nx+4) ($y+17) ($nw-8) 25 $value 20 $(if($i -eq 2){$c.red}else{$c.navy}) $true 'center' 'metric'
            } else {
                $ih=if($nh -gt 135){72.0}else{45.0};$iw=[math]::Min(90,$nw-14)
                Icon ($node+'-icon') $node $icon ($nx+($nw-$iw)/2) ($y+12) $iw $ih $accent
                Add-R2Text ($node+'-label') $node ($nx+7) ($y+$ih+22) ($nw-14) ($nh-$ih-26) $steps[$i] 12 $c.ink $true 'center'
            }
            if($i -lt $steps.Count-1){
                if($cost){Add-R2Text ($Name+'-operator-'+$i) $Name ($nx+$nw+3) ($y+15) ($gap-6) 28 $(if($i -eq 0){'+'}else{'='}) 22 $c.navy $true 'center' 'metric'}
                else {Add-R2Shape ($Name+'-arrow-'+$i) $Name 'rightArrow' ($nx+$nw+3) ($y+$nh/2-6) ($gap-6) 12 $accent ''}
            }
        }
        if($Panel.outcome){Add-R2Text ($Name+'-outcome') $Name $x ($y+$nh+3) $w $(if($cost){14}else{22}) $Panel.outcome $(if($cost){10}else{11}) $c.gray $false 'center' $(if($cost){'source'}else{'detail'})}
    }
    function Metrics($Name,$Panel,$Box){
        $ms=@($Panel.metrics);$x=$Box[0]+10;$y=$Box[1]+38;$w=$Box[2]-20;$h=$Box[3]-50;$mw=($w-12*($ms.Count-1))/$ms.Count
        foreach($i in 0..($ms.Count-1)){
            $mx=$x+$i*($mw+12);$node=$Name+'-metric-'+$i;$ink=if($i -eq 0){$c.red}elseif($i -eq 1){$c.green}else{$c.blue}
            Add-R2Shape $node $Name 'roundrect' $mx $y $mw $h $c.pale ''
            Icon ($node+'-icon') $node $(if($i -eq 1){'check'}else{'heat_exchanger'}) ($mx+($mw-64)/2) ($y+10) 64 52 $ink
            Add-R2Text ($node+'-label') $node ($mx+8) ($y+70) ($mw-16) 40 $ms[$i].label 11.5 $c.ink $true 'center' 'label'
            Add-R2Text ($node+'-value') $node ($mx+5) ($y+119) ($mw-10) 36 $ms[$i].value_text 24 $ink $true 'center' 'metric'
            if($ms[$i].detail){Add-R2Text ($node+'-detail') $node ($mx+8) ($y+165) ($mw-16) ($h-172) $ms[$i].detail 11 $c.gray $false 'center' 'detail'}
        }
    }
    Add-R2Rect 'canvas' '' 0 0 960 540 '#FFFFFF' '' 'panel'
    Add-R2Shape 'page-band' 'canvas' 'roundrect' 0 0 74 74 $c.navy ''
    $labels=@{problem='문제 현상';cause='원인 분석';actions='개선 사항';effects='효과 파악';rollout='횡전개'};$nums=@{problem='02';cause='03';actions='04';effects='05';rollout='06'}
    Add-R2Text 'page-number' 'page-band' 10 18 54 37 $nums[$id] 28 '#FFFFFF' $true 'center' 'metric'
    Add-R2Text 'section-name' 'canvas' 90 17 128 31 $labels[$id] 21 $c.navy $true 'left' 'section'
    Add-R2Line 'title-separator' 'canvas' 222 22 0 23 $c.navy 1.5
    Add-R2Text 'page-title' 'canvas' 238 15 706 34 $Stage.title 24 $c.navy $true 'left' 'title'
    Add-R2Text 'page-subtitle' 'canvas' 90 55 854 20 $Stage.subtitle 11.5 $c.navy
    if($id -eq 'actions'){
        $count=$panels.Count;$gap=10.0;$w=(928-($count-1)*$gap)/$count
        for($i=0;$i -lt $count;$i++){
            $name='panel-'+($i+1);$p=$panels[$i];if($p.kind -ne 'bullets' -or -not $p.icon -or -not $p.outcome){throw 'REFERENCE_LAYOUT_UNSUPPORTED: action cards require bullets, icon and outcome'}
            $x=16+$i*($w+$gap);$y=96;$h=305
            Add-R2Shape $name 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $c.edge 1 'panel'
            Add-R2Rect ($name+'-top') $name ($x+1) ($y+1) ($w-2) 48 $c.pale ''
            Add-R2Shape ($name+'-number-bg') $name 'ellipse' ($x+8) ($y+10) 18 18 $c.navy ''
            Add-R2Text ($name+'-number') ($name+'-number-bg') ($x+9) ($y+12) 16 15 ([string]($i+1)) 11.5 '#FFFFFF' $true 'center' 'label'
            Add-R2Text ($name+'-heading') $name ($x+31) ($y+10) ($w-39) 33 $p.title 13 $c.navy $true 'left' 'section'
            Icon ($name+'-icon') $name $p.icon ($x+($w-72)/2) ($y+67) 72 61 $c.navy
            $lines=@($p.lines);for($j=0;$j -lt $lines.Count;$j++){Add-R2Text ($name+'-body-'+$j) $name ($x+11) ($y+148+36*$j) ($w-22) 34 $lines[$j] 12 $c.ink $false}
            Add-R2Shape ($name+'-effect-title-bg') $name 'roundrect' ($x+8) ($y+233) ($w-16) 18 $c.green ''
            Add-R2Text ($name+'-effect-title') ($name+'-effect-title-bg') ($x+10) ($y+235) ($w-20) 14 '관리 목적' 10.5 '#FFFFFF' $true 'center' 'source'
            Add-R2Text ($name+'-outcome') $name ($x+9) ($y+262) ($w-18) 33 $p.outcome 11.5 $c.green $true 'center' 'detail'
        }
        Add-R2Shape 'action-summary' 'canvas' 'roundrect' 16 418 928 57 $c.pale $c.edge
        for($i=0;$i -lt $count;$i++){$x=25+$i*(910/$count);Icon ('action-summary-icon-'+$i) 'action-summary' $panels[$i].icon $x 430 35 29 $c.blue;Add-R2Text ('action-summary-label-'+$i) 'action-summary' ($x+42) 431 (910/$count-51) 32 $panels[$i].outcome 10.5 $c.navy $true 'left' 'source'}
    } else {
        $boxes=switch($id){
            'problem' {@(@(16,94,316,244),@(346,94,598,244),@(16,352,370,122),@(400,352,544,122))}
            'cause' {@(@(16,94,310,246),@(342,94,602,172),@(16,354,310,120),@(342,280,602,194))}
            'effects' {@(@(16,94,520,273),@(550,94,394,273),@(16,381,928,93))}
            'rollout' {@(@(16,94,444,220),@(476,94,468,220),@(16,328,928,146))}
        }
        for($i=0;$i -lt $panels.Count;$i++){
            $p=$panels[$i];$box=$boxes[$i];$name='panel-'+($i+1);$accent=if($p.tone -eq 'danger'){$c.red}else{$c.navy}
            Panel $name $box $p.title $accent
            switch($p.kind){'bullets' {Bullets $name $p $box};'table' {Table $name $p $box};'flow' {Flow $name $p $box};'metrics' {Metrics $name $p $box};default{throw ('REFERENCE_LAYOUT_UNSUPPORTED: '+$id+' / '+$p.kind)}}
        }
    }
    Add-R2Text 'page-citation' 'canvas' 20 480 920 14 ([string]$Stage.citation) 10 $c.gray $false 'left' 'source'
    Add-R2Shape 'footer-band' 'canvas' 'roundrect' 12 501 936 31 $c.navy ''
    Add-R2Text 'page-takeaway' 'footer-band' 24 506 912 22 $Stage.takeaway 12.5 '#FFFFFF' $true 'left' 'conclusion'
    $map=@{};foreach($item in $items){if($map.ContainsKey($item.id)){throw ('REFERENCE_DUPLICATE_ID: '+$item.id)};$map[$item.id]=$item}
    foreach($item in $items){
        if($item.x -lt 0 -or $item.y -lt 0 -or $item.w -lt 0 -or $item.h -lt 0 -or $item.x+$item.w -gt 960.01 -or $item.y+$item.h -gt 540.01){throw ('REFERENCE_GEOMETRY: '+$item.id)}
        if($item.parent){$p=$map[$item.parent];if($null -eq $p -or $item.x -lt $p.x-0.1 -or $item.y -lt $p.y-0.1 -or $item.x+$item.w -gt $p.x+$p.w+0.1 -or $item.y+$item.h -gt $p.y+$p.h+0.1){throw ('REFERENCE_PARENT: '+$item.id)}}
    }
    $text=@($items|Where-Object {$_.kind -eq 'text'})
    for($i=0;$i -lt $text.Count;$i++){for($j=$i+1;$j -lt $text.Count;$j++){
        $a=$text[$i];$b=$text[$j];$ow=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x);$oh=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
        if($ow -gt 0.5 -and $oh -gt 0.5){throw ('REFERENCE_TEXT_OVERLAP: '+$a.id+' / '+$b.id)}
    }}
    return $items.ToArray()
}
