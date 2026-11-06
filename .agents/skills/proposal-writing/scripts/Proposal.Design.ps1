# Approved reference-v3 compositions. Pure specifications, no Office/media/network access.
function Get-ProposalDesignLayout($Stage) {
    $id=[string]$Stage.id;$panels=@($Stage.panels)
    if($id -notin @('problem','cause','actions','effects','rollout') -or -not $Stage.citation){throw 'REFERENCE_LAYOUT_UNSUPPORTED: missing stage/citation'}
    $c=@{navy='#092D63';blue='#216498';ink='#17304F';gray='#56677C';edge='#D4DDE7';pale='#F2F6FA';red='#BE2529';pink='#FFF3F2';green='#28784B';mint='#EDF7F0';gold='#A86C13'}
    $items=New-Object 'Collections.Generic.List[object]'
    function Measure-R3Text([string]$Text,[double]$Size) {
        $units=0.0;foreach($ch in $Text.ToCharArray()){if([char]::IsWhiteSpace($ch)){$units+=0.40}elseif([int]$ch -ge 0x2E80){$units+=1.04}elseif([char]::IsUpper($ch)){$units+=0.72}else{$units+=0.61}}
        return $units*$Size
    }
    function Wrap-R3Text([string]$Text,[double]$W,[double]$H,[double]$Font) {
        $rows=New-Object 'Collections.Generic.List[string]'
        foreach($paragraph in ($Text -split '\r\n|\r|\n')){
            $line='';foreach($word in ($paragraph -split ' ')){if(-not $word){continue}
                if((Measure-R3Text $word $Font) -gt $W-2){throw ('TEXT_NEEDS_SHORTEN: word exceeds component: '+$word)}
                $candidate=if($line){$line+' '+$word}else{$word}
                if((Measure-R3Text $candidate $Font) -gt $W-2){$rows.Add($line);$line=$word}else{$line=$candidate}
            };$rows.Add($line)
        }
        if($rows.Count*$Font*1.24 -gt $H+0.25){throw ('TEXT_NEEDS_SHORTEN: semantic lines exceed component: '+$Text)}
        return ($rows.ToArray() -join "`r")
    }
    function Add-R3Spec($Name,$Role,$Parent,$Kind,$X,$Y,$W,$H,$Text='',$Font=12,$Color='',$Fill='',$Line='',$Bold=$false,$Primitive='',$Align='left',$Stroke=1) {
        if(-not $Color){$Color=$c.ink}
        $items.Add([pscustomobject][ordered]@{id=[string]$Name;role=[string]$Role;parent=[string]$Parent;kind=[string]$Kind;x=[double]$X;y=[double]$Y;w=[double]$W;h=[double]$H;text=[string]$Text;font_size=[double]$Font;font_bold=[bool]$Bold;color=[string]$Color;fill=[string]$Fill;line_color=[string]$Line;primitive=[string]$Primitive;align=[string]$Align;line_width=[double]$Stroke;layout_revision='proposal-reference-r3'})
        if($Primitive -eq 'roundrect'){$items[$items.Count-1]|Add-Member -NotePropertyName corner_radius -NotePropertyValue 0.04}
    }
    function Add-R3Text($Name,$Parent,$X,$Y,$W,$H,$Text,$Font=12,$Color='',$Bold=$false,$Align='left',$Role='body'){
        Add-R3Spec $Name $Role $Parent 'text' $X $Y $W $H (Wrap-R3Text ([string]$Text) $W $H $Font) $Font $Color '' '' $Bold '' $Align
    }
    function Add-R3Shape($Name,$Parent,$Primitive,$X,$Y,$W,$H,$Fill='',$Line='',$Stroke=1,$Role='detail'){Add-R3Spec $Name $Role $Parent 'shape' $X $Y $W $H '' 12 '' $Fill $Line $false $Primitive 'left' $Stroke}
    function Add-R3Rect($Name,$Parent,$X,$Y,$W,$H,$Fill='',$Line='',$Role='detail'){Add-R3Spec $Name $Role $Parent 'rect' $X $Y $W $H '' 12 '' $Fill $Line $false '' 'left' 1}
    function Add-R3Line($Name,$Parent,$X,$Y,$W,$H,$Color,$Stroke=1.2){Add-R3Spec $Name 'detail' $Parent 'line' $X $Y $W $H '' 12 '' '' $Color $false '' 'left' $Stroke}
    function Panel($Name,$Box,$Title,$Accent) {
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        Add-R3Shape $Name 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $c.edge 1 'panel'
        Add-R3Rect ($Name+'-rail') $Name ($x+1) ($y+1) 4 ($h-2) $Accent ''
        Add-R3Text ($Name+'-heading') $Name ($x+14) ($y+10) ($w-28) $(if($h -le 115){20}else{35}) $Title 13.5 $Accent $true 'left' 'section'
    }
    function Icon($Prefix,$Parent,$Type,$X,$Y,$W,$H,$Color){
        if(-not $Type){$Type='check'}
        $state=@{i=0};$scaleX=$W/80.0;$scaleY=$H/64.0
        function IS($Primitive,$A,$B,$D,$E,$Fill='',$Edge=''){$state.i++;if(-not $Edge){$Edge=$Color};Add-R3Shape ($Prefix+'-'+$state.i) $Parent $Primitive ($X+$A*$scaleX) ($Y+$B*$scaleY) ($D*$scaleX) ($E*$scaleY) $Fill $Edge 1.3}
        function IR($A,$B,$D,$E,$Fill='',$Edge=''){$state.i++;if(-not $Edge){$Edge=$Color};Add-R3Rect ($Prefix+'-'+$state.i) $Parent ($X+$A*$scaleX) ($Y+$B*$scaleY) ($D*$scaleX) ($E*$scaleY) $Fill $Edge}
        function IL($A,$B,$D,$E){$state.i++;Add-R3Line ($Prefix+'-'+$state.i) $Parent ($X+$A*$scaleX) ($Y+$B*$scaleY) ($D*$scaleX) ($E*$scaleY) $Color 1.5}
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
            'cost' {IS 'ellipse' 15 7 50 50 '#FFF5E5';$state.i++;Add-R3Text ($Prefix+'-'+$state.i) $Parent ($X+25*$scaleX) ($Y+13*$scaleY) (30*$scaleX) (36*$scaleY) '$' ([math]::Max(11.5,[math]::Min(26,28*$scaleY))) $Color $true 'center' 'label'}
            'factory' {IR 10 24 60 32 '#F0F5FA';IR 15 5 9 20 $Color;IR 33 12 9 13 $Color;foreach($xx in @(20,37,54)){IR $xx 35 8 10 '#CADBE9'}}
            'check' {IS 'ellipse' 17 7 46 46 '#EFF7F1';$state.i++;Add-R3Text ($Prefix+'-'+$state.i) $Parent ($X+18*$scaleX) ($Y+13*$scaleY) (44*$scaleX) (36*$scaleY) '✓' ([math]::Max(11.5,[math]::Min(21,23*$scaleY))) $Color $true 'center' 'label'}
            default {throw ('REFERENCE_ICON_UNSUPPORTED: '+$Type)}
        }
    }

    function Bullets($Name,$Panel,$Box) {
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$lines=@($Panel.lines)
        if(-not $Panel.icon -or $lines.Count -lt 1){throw 'REFERENCE_LAYOUT_UNSUPPORTED: bullets require icon and business text'}
        $compact=$h -le 210
        if($compact){
            Icon ($Name+'-icon') $Name $Panel.icon ($x+14) ($y+49) 46 38 $c.blue
            $by=$y+49;$bw=$w-88;$bh=$h-56
            Add-R3Text ($Name+'-body') $Name ($x+73) $by $bw $bh ($lines -join "`r") 12.5 $c.ink
        }else{
            Icon ($Name+'-icon') $Name $Panel.icon ($x+($w-120)/2) ($y+50) 120 96 $c.blue
            $outH=if($Panel.outcome){50}else{0}
            Add-R3Text ($Name+'-body') $Name ($x+20) ($y+162) ($w-40) ($h-174-$outH) ($lines -join "`r") 14 $c.ink $true
            if($Panel.outcome){Add-R3Rect ($Name+'-note-bg') $Name ($x+14) ($y+$h-48) ($w-28) 34 $c.pale '';Add-R3Text ($Name+'-outcome') ($Name+'-note-bg') ($x+22) ($y+$h-42) ($w-44) 25 $Panel.outcome 10.5 $c.gray $false 'left' 'source'}
        }
    }
    function Photo($Name,$Panel,$Box) {
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$a=$Panel.asset
        if($a.reference_kind -ne 'picture' -or $null -eq $a.known_visible_aspect_ratio -or [double]$a.known_visible_aspect_ratio -le 0){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V3 photo requires visible ratio'}
        if($a.known_visible_aspect_ratio -isnot [ValueType] -or $a.known_visible_aspect_ratio -is [bool] -or [double]::IsNaN([double]$a.known_visible_aspect_ratio) -or [double]::IsInfinity([double]$a.known_visible_aspect_ratio)){throw 'REFERENCE_LAYOUT_UNSUPPORTED: invalid visible ratio'}
        $frame=$Name+'-photo-frame';$fy=$y+48;$fh=$h-109
        Add-R3Rect $frame $Name ($x+12) $fy ($w-24) $fh $c.pale $c.edge 'asset_frame'
        $labelH=if($a.origin -eq 'synthetic_test'){25.0}else{0.0}
        $aw=$w-36;$ah=$fh-12-$labelH;$ratio=[double]$a.known_visible_aspect_ratio;$pw=[math]::Min($aw,$ah*$ratio);$ph=$pw/$ratio
        Add-R3Spec ($Name+'-asset') 'evidence_asset' $frame 'asset' ($x+18+($aw-$pw)/2) ($fy+6+($ah-$ph)/2) $pw $ph
        $items[$items.Count-1]|Add-Member -NotePropertyName asset -NotePropertyValue $a
        if($labelH){Add-R3Text ($Name+'-asset-origin') $frame ($x+18) ($fy+$fh-24) ($w-36) 20 '가상 이미지 · 실제 사례 사진 아님' 10.5 $c.gray $false 'center' 'source'}
        Add-R3Text ($Name+'-asset-description') $Name ($x+14) ($y+$h-50) ($w-28) 39 $a.description 11.5 $c.ink $false 'left' 'detail'
    }
    function Flow($Name,$Panel,$Box,[bool]$Vertical=$false) {
        $x=$Box[0]+14;$y=$Box[1]+49;$w=$Box[2]-28;$h=$Box[3]-62;$steps=@($Panel.steps);$icons=@($Panel.step_icons)
        if($steps.Count -lt 2 -or $steps.Count -gt 4 -or $icons.Count -ne $steps.Count){throw 'REFERENCE_LAYOUT_UNSUPPORTED: flow requires two to four named illustrated nodes'}
        $accent=if($Panel.tone -eq 'danger'){$c.red}elseif($Panel.tone -eq 'success'){$c.green}elseif($id -eq 'rollout'){$c.gold}else{$c.blue}
        $fill=if($Panel.tone -eq 'danger'){$c.pink}else{$c.pale}
        $outH=if($Panel.outcome){30.0}else{0.0};$available=$h-$outH
        if($Panel.relationship -eq 'sum') {
            $y=$Box[1]+34;$gap=32.0;$nw=($w-2*$gap)/3;$nh=47.0
            for($i=0;$i -lt 3;$i++){
                $nx=$x+$i*($nw+$gap);$node=$Name+'-step-'+$i;$st=[string]$steps[$i];$currencyMatch=[regex]::Match($st,' (?:USD|KRW) -?\d');$marker=if($currencyMatch.Success){$currencyMatch.Index+1}else{-1}
                if($marker -lt 1){throw 'REFERENCE_LAYOUT_UNSUPPORTED: sum requires separated currency values'}
                $label=$st.Substring(0,$marker).Trim();$value=$st.Substring($marker).Trim()
                Add-R3Shape $node $Name 'roundrect' $nx $y $nw $nh $(if($i -eq 2){$c.mint}else{$c.pale}) ''
                Add-R3Text ($node+'-label') $node ($nx+9) ($y+1) ($nw-18) 17 $label 11.5 $c.ink $true 'center' 'label'
                Add-R3Text ($node+'-value') $node ($nx+5) ($y+20) ($nw-10) 27 $value 21 $c.green $true 'center' 'metric'
                if($i -lt 2){Add-R3Text ($Name+'-operator-'+$i) $Name ($nx+$nw+2) ($y+17) ($gap-4) 34 $(if($i -eq 0){'+'}else{'='}) 24 $c.navy $true 'center' 'metric'}
            };$used=$nh
        }elseif($Vertical){
            $gap=14.0;$nh=[math]::Min(64,($available-($steps.Count-1)*$gap)/$steps.Count)
            if($nh -lt 46){throw 'REFERENCE_LAYOUT_UNSUPPORTED: vertical flow too dense'}
            for($i=0;$i -lt $steps.Count;$i++){
                $ny=$y+$i*($nh+$gap);$node=$Name+'-step-'+$i
                Add-R3Shape $node $Name 'roundrect' $x $ny $w $nh $fill ''
                Icon ($node+'-icon') $node $icons[$i] ($x+10) ($ny+6) 52 ($nh-12) $accent
                Add-R3Text ($node+'-label') $node ($x+77) ($ny+9) ($w-91) ($nh-16) $steps[$i] 13 $c.ink $true
                if($i -lt $steps.Count-1){Add-R3Shape ($Name+'-arrow-'+$i) $Name 'downArrow' ($x+$w/2-5) ($ny+$nh+2) 10 ($gap-4) $accent ''}
            };$used=$steps.Count*$nh+($steps.Count-1)*$gap
        }else{
            $gap=21.0;$nw=($w-($steps.Count-1)*$gap)/$steps.Count;$nh=[math]::Min(150,$available)
            if($nw -lt 95 -or $nh -lt 113){throw 'REFERENCE_LAYOUT_UNSUPPORTED: horizontal flow too dense'}
            for($i=0;$i -lt $steps.Count;$i++){
                $nx=$x+$i*($nw+$gap);$node=$Name+'-step-'+$i
                Add-R3Shape $node $Name 'roundrect' $nx $y $nw $nh $fill ''
                Icon ($node+'-icon') $node $icons[$i] ($nx+($nw-64)/2) ($y+10) 64 52 $accent
                Add-R3Text ($node+'-label') $node ($nx+8) ($y+77) ($nw-16) ($nh-85) $steps[$i] 12.5 $c.ink $true 'center'
                if($i -lt $steps.Count-1){Add-R3Shape ($Name+'-arrow-'+$i) $Name 'rightArrow' ($nx+$nw+3) ($y+$nh/2-5) ($gap-6) 10 $accent ''}
            };$used=$nh
        }
        if($Panel.outcome){Add-R3Text ($Name+'-outcome') $Name $x ($y+$used+8) $w $(if($Panel.relationship -eq 'sum'){18}else{24}) $Panel.outcome 11 $c.gray $false 'left' 'detail'}
    }
    function Measure-R3TableHeight($Panel,[double]$Width) {
        $heads=@($Panel.table.headers);$rows=@($Panel.table.rows);$cw=($Width-28)/$heads.Count;$height=61.0
        for($r=0;$r -le $rows.Count;$r++){
            $vals=if($r -eq 0){$heads}else{@($rows[$r-1])};$rh=33.0
            foreach($v in $vals){$wrapped=Wrap-R3Text ([string]$v) ($cw-16) 130 12.5;$rh=[math]::Max($rh,($wrapped -split "`r").Count*15.5+16)}
            $height+=$rh
        };return $height
    }
    function Table($Name,$Panel,$Box) {
        $x=$Box[0]+14;$y=$Box[1]+49;$w=$Box[2]-28;$available=$Box[3]-61
        $heads=@($Panel.table.headers);$rows=@($Panel.table.rows);$colW=$w/$heads.Count;$cy=$y
        if($heads.Count -lt 2 -or $colW -lt 95){throw 'REFERENCE_LAYOUT_UNSUPPORTED: table too dense'}
        for($rr=0;$rr -le $rows.Count;$rr++){
            $vals=if($rr -eq 0){$heads}else{@($rows[$rr-1])};$rh=33.0
            for($cc=0;$cc -lt $heads.Count;$cc++){$wrapped=Wrap-R3Text ([string]$vals[$cc]) ($colW-16) 130 12.5;$rh=[math]::Max($rh,($wrapped -split "`r").Count*15.5+16)}
            if($cy+$rh -gt $y+$available){throw 'TEXT_NEEDS_SHORTEN: table rows exceed component'}
            for($cc=0;$cc -lt $heads.Count;$cc++){
                $cell=$Name+'-cell-'+$rr+'-'+$cc;$fill=if($rr -eq 0){$c.navy}elseif($rr%2){'#FFFFFF'}else{$c.pale}
                Add-R3Rect $cell $Name ($x+$cc*$colW) $cy $colW $rh $fill $c.edge
                Add-R3Text ($cell+'-text') $cell ($x+$cc*$colW+8) ($cy+7) ($colW-16) ($rh-12) $vals[$cc] 12.5 $(if($rr -eq 0){'#FFFFFF'}else{$c.ink}) ($rr -eq 0)
            };$cy+=$rh
        }
    }
    function Metrics($Name,$Panel,$Box) {
        $x=$Box[0]+14;$y=$Box[1]+49;$w=$Box[2]-28;$ms=@($Panel.metrics);$gap=10.0;$mw=($w-($ms.Count-1)*$gap)/$ms.Count
        if($ms.Count -lt 1 -or $ms.Count -gt 3){throw 'REFERENCE_LAYOUT_UNSUPPORTED: metrics count'}
        $nh=[math]::Min(218,$Box[3]-62)
        for($i=0;$i -lt $ms.Count;$i++){
            $mx=$x+$i*($mw+$gap);$node=$Name+'-metric-'+$i
            Add-R3Shape $node $Name 'roundrect' $mx $y $mw $nh $c.mint ''
            Add-R3Text ($node+'-label') $node ($mx+10) ($y+15) ($mw-20) 48 $ms[$i].label 12.5 $c.ink $true 'center' 'label'
            Add-R3Text ($node+'-value') $node ($mx+7) ($y+68) ($mw-14) 43 $ms[$i].value_text 29 $c.green $true 'center' 'metric'
            if($ms[$i].detail){Add-R3Text ($node+'-detail') $node ($mx+10) ($y+125) ($mw-20) ($nh-135) $ms[$i].detail 11.5 $c.gray $false 'center' 'detail'}
        }
    }
    function Bars($Name,$Panel,$Box) {
        $x=$Box[0]+14;$y=$Box[1]+49;$w=$Box[2]-28;$bars=@($Panel.bars)
        if($bars.Count -lt 1 -or $bars.Count -gt 4){throw 'REFERENCE_LAYOUT_UNSUPPORTED: bar count'}
        foreach($i in 0..($bars.Count-1)){
            $b=$bars[$i];$by=$y+70*$i
            if($by+50 -gt $Box[1]+$Box[3]-12){throw 'REFERENCE_LAYOUT_UNSUPPORTED: bars too dense'}
            Add-R3Text ($Name+'-bar-label-'+$i) $Name $x $by $w 31 (([string]$b.label)+'  '+([string]$b.value_text)) 12.5 $c.ink $true
            Add-R3Rect ($Name+'-bar-bg-'+$i) $Name $x ($by+38) $w 10 $c.pale ''
            if([double]$b.ratio -gt 0){Add-R3Rect ($Name+'-bar-value-'+$i) $Name $x ($by+38) ($w*[double]$b.ratio) 10 $c.green ''}
        }
    }
    Add-R3Rect 'canvas' '' 0 0 960 540 '#FFFFFF' '' 'panel'
    Add-R3Rect 'page-band' 'canvas' 0 0 74 74 $c.navy ''
    $labels=@{problem='문제 현상';cause='원인 분석';actions='개선 사항';effects='효과 파악';rollout='횡전개'};$nums=@{problem='02';cause='03';actions='04';effects='05';rollout='06'}
    Add-R3Text 'page-number' 'page-band' 10 17 54 38 $nums[$id] 28 '#FFFFFF' $true 'center' 'metric'
    Add-R3Text 'section-name' 'canvas' 90 17 128 31 $labels[$id] 21 $c.navy $true 'left' 'section'
    Add-R3Line 'title-separator' 'canvas' 222 22 0 23 $c.navy 1.5
    Add-R3Text 'page-title' 'canvas' 238 15 706 37 $Stage.title 23.5 $c.navy $true 'left' 'title'
    Add-R3Text 'page-subtitle' 'canvas' 90 56 854 30 $Stage.subtitle 11.5 $c.gray
    $boxes=@()
if($id -eq 'actions'){
        if($panels.Count -lt 3 -or $panels.Count -gt 6){throw 'REFERENCE_LAYOUT_UNSUPPORTED: actions count'}
        $grid=$panels.Count -ge 5;$cols=if($grid){3}else{$panels.Count}
        $gap=12.0;$w=(928-($cols-1)*$gap)/$cols
        for($i=0;$i -lt $panels.Count;$i++){
            $p=$panels[$i];$name='panel-'+($i+1);$x=16+($i%$cols)*($w+$gap);$y=100+([math]::Floor($i/$cols)*182);$h=if($grid){170.0}else{304.0}
            if($p.role -ne 'action' -or $p.kind -ne 'bullets' -or -not $p.icon -or -not $p.outcome){throw 'REFERENCE_LAYOUT_UNSUPPORTED: action card contract'}
            Add-R3Shape $name 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $c.edge 1 'panel'
            Add-R3Rect ($name+'-head-bg') $name ($x+1) ($y+1) ($w-2) 42 $c.pale ''
            Add-R3Shape ($name+'-number-bg') $name 'ellipse' ($x+10) ($y+11) 20 20 $c.navy ''
            Add-R3Text ($name+'-number') ($name+'-number-bg') ($x+11) ($y+13) 18 16 ([string]($i+1)) 11.5 '#FFFFFF' $true 'center' 'label'
            Add-R3Text ($name+'-heading') $name ($x+42) ($y+11) ($w-52) 27 $p.title 13 $c.navy $true 'left' 'section'
            if($grid){
                Icon ($name+'-icon') $name $p.icon ($x+12) ($y+58) 58 48 $c.blue
                Add-R3Text ($name+'-body') $name ($x+84) ($y+53) ($w-98) 65 (@($p.lines) -join "`r") 12 $c.ink
                Add-R3Rect ($name+'-outcome-bg') $name ($x+7) ($y+$h-42) ($w-14) 35 $c.mint ''
                Add-R3Text ($name+'-outcome') ($name+'-outcome-bg') ($x+14) ($y+$h-35) ($w-28) 23 $p.outcome 11.5 $c.green $true 'center' 'detail'
            }else{
                Icon ($name+'-icon') $name $p.icon ($x+($w-86)/2) ($y+58) 86 71 $c.blue
                Add-R3Text ($name+'-body') $name ($x+18) ($y+150) ($w-36) 90 (@($p.lines) -join "`r") 13 $c.ink
                Add-R3Rect ($name+'-outcome-bg') $name ($x+7) ($y+$h-53) ($w-14) 46 $c.mint ''
                Add-R3Text ($name+'-outcome') ($name+'-outcome-bg') ($x+14) ($y+$h-45) ($w-28) 31 $p.outcome 11.5 $c.green $true 'center' 'detail'
            }
        }

    }else{
        switch($id){
            'problem'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'context' -or $panels[1].role -ne 'phenomenon'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: problem roles'}
                $lw=334.0
                if($panels[0].kind -eq 'asset'){$ratio=[double]$panels[0].asset.known_visible_aspect_ratio;$lw=if($ratio -ge 1.25){418.0}elseif($ratio -lt 0.85){270.0}else{346.0}}
                $rx=30+$lw;$rw=944-$rx
                $boxes+=,@(16,100,$lw,352)
                $boxes+=,@($rx,100,$rw,$(if($panels.Count -eq 3){217}else{306}))
                if($panels.Count -eq 3){$boxes+=,@($rx,331,$rw,121)}
            }
            'cause'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'evidence' -or $panels[1].role -ne 'causal'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: cause roles'}
                $th=if($panels[0].kind -eq 'table'){Measure-R3TableHeight $panels[0] 430}else{352}
                if($panels.Count -eq 3 -and $th -le 210){
                    $boxes+=,@(16,100,430,$th);$boxes+=,@(460,100,484,352)
                    $by=100+$th+14;$boxes+=,@(16,$by,430,([math]::Min(150,452-$by)))
                }else{
                    $h=if($panels.Count -eq 3){278}else{352};$boxes+=,@(16,100,430,([math]::Min($h,$th)));$boxes+=,@(460,100,484,$h)
                    if($panels.Count -eq 3){$boxes+=,@(16,392,928,68)}
                }
            }
            'effects'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'outcomes' -or $panels[1].role -ne 'details'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: effects roles'}
                $h=if($panels.Count -eq 3){238}else{352};$boxes+=,@(16,100,440,$h);$boxes+=,@(470,100,474,$h)
                if($panels.Count -eq 3){$boxes+=,@(16,352,928,108)}
            }
            'rollout'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'coverage' -or $panels[1].role -ne 'expansion'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: rollout roles'}
                $th=Measure-R3TableHeight $panels[0] 450
                if($panels.Count -eq 3 -and $th -le 228){
                    $boxes+=,@(16,100,450,$th);$boxes+=,@(480,100,464,352)
                    $by=100+$th+14;$boxes+=,@(16,$by,450,(452-$by))
                }else{
                    $h=if($panels.Count -eq 3){278}else{352};$boxes+=,@(16,100,450,([math]::Min($h,$th)));$boxes+=,@(480,100,464,$h)
                    if($panels.Count -eq 3){$boxes+=,@(16,392,928,68)}
                }
            }
        }
        $allowed=@{context=@('bullets','asset');phenomenon=@('flow');impact=@('bullets');evidence=@('table','asset');causal=@('flow','bullets');boundary=@('bullets');outcomes=@('metrics');details=@('table','bars','bullets');calculation=@('flow');coverage=@('table');expansion=@('flow');checks=@('bullets')}
        for($i=0;$i -lt $panels.Count;$i++){
            $p=$panels[$i];$name='panel-'+($i+1);$box=$boxes[$i]
            if(-not $allowed.ContainsKey([string]$p.role) -or $p.kind -notin $allowed[[string]$p.role]){throw 'REFERENCE_LAYOUT_UNSUPPORTED: role/kind'}
            if($p.role -eq 'calculation' -and $p.relationship -ne 'sum'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: calculation relationship'}
            $accent=if($p.tone -eq 'danger'){$c.red}elseif($p.tone -eq 'success'){$c.green}else{$c.navy}
            if($box[3] -le 75){
                Add-R3Rect $name 'canvas' $box[0] $box[1] $box[2] $box[3] $c.pale '' 'panel'
                Add-R3Text ($name+'-heading') $name ($box[0]+14) ($box[1]+12) 154 35 $p.title 13 $c.navy $true 'left' 'section'
                Add-R3Text ($name+'-body') $name ($box[0]+184) ($box[1]+12) ($box[2]-200) ($box[3]-22) (@($p.lines)-join ' · ') 12 $c.gray
                continue
            }
            Panel $name $box $p.title $accent
            switch($p.kind){
                'bullets'{Bullets $name $p $box}
                'asset'{Photo $name $p $box}
                'flow'{Flow $name $p $box ($p.role -in @('causal','expansion'))}
                'table'{Table $name $p $box}
                'metrics'{Metrics $name $p $box}
                'bars'{Bars $name $p $box}
                default{throw 'REFERENCE_LAYOUT_UNSUPPORTED: component'}
            }
        }
    }
    Add-R3Text 'page-citation' 'canvas' 20 477 920 18 $Stage.citation 10.5 $c.gray $false 'left' 'source'
    Add-R3Rect 'footer-band' 'canvas' 12 501 936 31 $c.navy ''
    Add-R3Text 'page-takeaway' 'footer-band' 24 506 912 22 $Stage.takeaway 12.5 '#FFFFFF' $true 'left' 'conclusion'
    $map=@{};foreach($s in $items){if($map.ContainsKey($s.id)){throw ('REFERENCE_DUPLICATE_ID: '+$s.id)};$map[$s.id]=$s}
    foreach($s in $items){
        if($s.x -lt 0 -or $s.y -lt 0 -or $s.w -lt 0 -or $s.h -lt 0 -or $s.x+$s.w -gt 960.01 -or $s.y+$s.h -gt 540.01){throw ('REFERENCE_GEOMETRY: '+$s.id)}
        if($s.parent){$p=$map[$s.parent];if($null -eq $p -or $s.x -lt $p.x-0.1 -or $s.y -lt $p.y-0.1 -or $s.x+$s.w -gt $p.x+$p.w+0.1 -or $s.y+$s.h -gt $p.y+$p.h+0.1){throw ('REFERENCE_PARENT: '+$s.id)}}
    }
    $texts=@($items|Where-Object {$_.kind -eq 'text'})
    for($i=0;$i -lt $texts.Count;$i++){for($j=$i+1;$j -lt $texts.Count;$j++){
        $a=$texts[$i];$b=$texts[$j];$ow=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x);$oh=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
        if($ow -gt 0.5 -and $oh -gt 0.5){throw ('REFERENCE_TEXT_OVERLAP: '+$a.id+' / '+$b.id)}
    }}
    return $items.ToArray()
}
