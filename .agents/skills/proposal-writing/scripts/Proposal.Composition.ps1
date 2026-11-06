# Fixed reference-v4 compositions. Pure specs only; no Office/media/model/network access.
. (Join-Path $PSScriptRoot 'Proposal.Graphics.ps1')
function Get-ProposalCompositionLayout($Stage) {
    $sid=[string]$Stage.id;$panels=@($Stage.panels)
    if($sid -notin @('problem','cause','actions','effects','rollout') -or [string]::IsNullOrWhiteSpace([string]$Stage.citation)){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 stage/citation missing'}
    $items=New-Object 'Collections.Generic.List[object]'
    $c=@{navy='#0C315F';blue='#27669C';ink='#1C314B';muted='#596A7F';edge='#D6E1EB';light='#F3F7FB';red='#BE3540';pink='#FFF4F3';green='#207C59';mint='#EDF6F0';gold='#A87221';sand='#FBF6EC'}
    function MeasureText([string]$Text,[double]$Size) {
        $u=0.0;foreach($ch in $Text.ToCharArray()){if([char]::IsWhiteSpace($ch)){$u+=0.39}elseif([int]$ch -ge 0x2E80){$u+=1.03}elseif([char]::IsUpper($ch)){$u+=0.71}else{$u+=0.60}}
        return $u*$Size
    }
    function WrapText([string]$Text,[double]$W,[double]$H,[double]$Font) {
        $out=New-Object 'Collections.Generic.List[string]'
        foreach($para in ($Text -split '\r\n|\r|\n')){
            $line='';foreach($word in ($para -split ' ')){
                if(-not $word){continue}
                if((MeasureText $word $Font) -gt $W-2){throw ('TEXT_NEEDS_SHORTEN: word exceeds V4 slot: '+$word)}
                $candidate=if($line){$line+' '+$word}else{$word}
                if((MeasureText $candidate $Font) -gt $W-2){$out.Add($line);$line=$word}else{$line=$candidate}
            };$out.Add($line)
        }
        if($out.Count*$Font*1.25 -gt $H+0.25){throw ('TEXT_NEEDS_SHORTEN: V4 semantic lines exceed slot: '+$Text)}
        return ($out.ToArray()-join "`r")
    }
    function Spec($Id,$Role,$Parent,$Kind,$X,$Y,$W,$H,$Text='',$Font=12,$Color='',$Fill='',$Line='',$Bold=$false,$Primitive='',$Align='left',$Stroke=1.0) {
        if(-not $Color){$Color=$c.ink}
        $items.Add([pscustomobject][ordered]@{id=[string]$Id;role=[string]$Role;parent=[string]$Parent;kind=[string]$Kind;x=[double]$X;y=[double]$Y;w=[double]$W;h=[double]$H;text=[string]$Text;font_size=[double]$Font;font_bold=[bool]$Bold;color=[string]$Color;fill=[string]$Fill;line_color=[string]$Line;primitive=[string]$Primitive;align=[string]$Align;line_width=[double]$Stroke;layout_revision='proposal-reference-r4'})
        if($Primitive -eq 'roundrect'){$items[$items.Count-1]|Add-Member -NotePropertyName corner_radius -NotePropertyValue 0.04}
    }
    function Text($Id,$Parent,$X,$Y,$W,$H,$Content,$Font=12,$Color='',$Bold=$false,$Align='left',$Role='body') {Spec $Id $Role $Parent 'text' $X $Y $W $H (WrapText ([string]$Content) $W $H $Font) $Font $Color '' '' $Bold '' $Align}
    function Rect($Id,$Parent,$X,$Y,$W,$H,$Fill='',$Line='',$Role='detail') {Spec $Id $Role $Parent 'rect' $X $Y $W $H '' 12 '' $Fill $Line $false '' 'left' 0.8}
    function Shape($Id,$Parent,$Type,$X,$Y,$W,$H,$Fill='',$Line='',$Role='detail') {Spec $Id $Role $Parent 'shape' $X $Y $W $H '' 12 '' $Fill $Line $false $Type 'left' 1.0}
    function Rule($Id,$Parent,$X,$Y,$W,$H,$Color,$Stroke=1.0) {Spec $Id 'detail' $Parent 'line' $X $Y $W $H '' 12 '' '' $Color $false '' 'left' $Stroke}
    function Picture($Id,$Parent,$Panel,$X,$Y,$W,$H) {
        $a=$Panel.asset;$r=$a.known_visible_aspect_ratio
        if($a.reference_kind -ne 'picture' -or $r -isnot [ValueType] -or $r -is [bool] -or [double]::IsNaN([double]$r) -or [double]::IsInfinity([double]$r) -or [double]$r -le 0){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 picture requires finite COM ratio'}
        $aw=$W-16;$ah=$H-16;$label=if($a.origin -eq 'synthetic_test'){24.0}else{0.0};$ah-=$label
        Rect $Parent 'panel-1' $X $Y $W $H $c.light $c.edge 'asset_frame'
        $pw=[math]::Min($aw,$ah*[double]$r);$ph=$pw/[double]$r
        Spec $Id 'evidence_asset' $Parent 'asset' ($X+8+($aw-$pw)/2) ($Y+8+($ah-$ph)/2) $pw $ph
        $items[$items.Count-1]|Add-Member -NotePropertyName asset -NotePropertyValue $a
        if($label){Text ($Id+'-origin') $Parent ($X+8) ($Y+$H-24) ($W-16) 18 '가상 이미지 · 실제 사례 사진 아님' 10.5 $c.muted $false 'center' 'source'}
    }
    function Figure($Id,$Parent,$Type,$X,$Y,$W,$H,$Accent) {
        foreach($g in @(Get-ProposalIllustrationSpecs -Prefix $Id -Parent $Parent -Type $Type -X $X -Y $Y -W $W -H $H -Color $Accent -Revision 'proposal-reference-r4')){$items.Add($g)}
    }
    function Panel($Id,$Box,$Heading,$Accent=$c.navy,[bool]$Border=$true) {
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        Shape $Id 'canvas' 'roundrect' $x $y $w $h '#FFFFFF' $(if($Border){$c.edge}else{''}) 'panel'
        Shape ($Id+'-tab') $Id 'roundrect' $x $y $w 25 $Accent ''
        Text ($Id+'-heading') ($Id+'-tab') ($x+12) ($y+4) ($w-24) 20 $Heading 13 $([string]'#FFFFFF') $true 'left' 'section'
    }
    function ListHeight($Lines,[double]$W,[double]$Font=12.3) {
        $h=0.0
        foreach($line in @($Lines)){$wr=WrapText ([string]$line) $W 180 $Font;$h+=($wr-split "`r").Count*$Font*1.25+9}
        return $h
    }
    function BulletRows($Id,$Parent,$Lines,$X,$Y,$W,$H,$Accent=$c.blue,$Font=12.3,$Gap=9.0) {
        $cy=$Y;$i=0
        foreach($line in @($Lines)){
            $wr=WrapText ([string]$line) ($W-17) 180 $Font;$hh=($wr-split "`r").Count*$Font*1.25+2
            if($cy+$hh -gt $Y+$H+0.1){throw ('TEXT_NEEDS_SHORTEN: V4 list exceeds available rows: '+$Id)}
            Shape ($Id+'-dot-'+$i) $Parent 'ellipse' $X ($cy+6) 4 4 $Accent ''
            Text ($Id+'-line-'+$i) $Parent ($X+15) $cy ($W-15) $hh $line $Font $c.ink ([string]$line -match '\d')
            $cy+=$hh+$Gap;$i++
        }
    }
    function Context($Id,$P,$Box) {
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        if($P.kind -eq 'asset'){
            $photoH=$h-92
            Picture ($Id+'-asset') ($Id+'-photo-frame') $P ($x+10) ($y+35) ($w-20) $photoH
            Text ($Id+'-description') $Id ($x+12) ($y+$h-48) ($w-24) 38 $P.asset.description 11.5 $c.muted $false 'left' 'detail'
        }else{
            if(-not $P.icon){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 context icon required'}
            $fw=[math]::Min(160,$w*0.23);$fh=[math]::Min(104,$h-48)
            Figure ($Id+'-figure') $Id $P.icon ($x+15) ($y+36) $fw $fh $c.blue
            $lh=ListHeight $P.lines ($w-$fw-60) 13
            $note=if($P.outcome){28.0}else{0.0};$captionW=[math]::Max(94,$fw)
            BulletRows ($Id+'-facts') $Id $P.lines ($x+$fw+35) ($y+42) ($w-$fw-50) ($h-52-$note) $c.blue 13
            Text ($Id+'-concept') $Id ($x+15) ($y+$h-19) $captionW 14 '설명용 개념도' 10 $c.muted $false 'center' 'source'
            if($P.outcome){Text ($Id+'-outcome') $Id ($x+$captionW+35) ($y+$h-30) ($w-$captionW-50) 21 $P.outcome 11 $c.muted $false 'left' 'detail'}
        }
    }
    function Bullets($Id,$P,$Box,[bool]$Horizontal=$false) {
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3]
        if(-not $P.icon){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 bullet illustration required'}
        $outH=if($P.outcome){25.0}else{0.0};$fw=if($w -ge 700){95.0}else{80.0};$fh=[math]::Min(78,$h-44-$outH)
        Figure ($Id+'-figure') $Id $P.icon ($x+14) ($y+37) $fw $fh $c.blue
        BulletRows ($Id+'-facts') $Id $P.lines ($x+$fw+32) ($y+38) ($w-$fw-46) ($h-47-$outH) $c.blue 12.3
        if($P.outcome){Text ($Id+'-outcome') $Id ($x+13) ($y+$h-27) ($w-26) 21 $P.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function TableH($P,[double]$W) {
        $heads=@($P.table.headers);$rows=@($P.table.rows);$height=36.0
        if($heads.Count -lt 2 -or $heads.Count -gt 4){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 table columns'}
        $widths=if($heads.Count -eq 2){@((($W-20)*0.38),(($W-20)*0.62))}else{@(($W-20)/$heads.Count)*$heads.Count}
        for($r=0;$r -le $rows.Count;$r++){
            $vals=if($r -eq 0){$heads}else{@($rows[$r-1])};$rh=38.0
            for($j=0;$j -lt $heads.Count;$j++){$wr=WrapText ([string]$vals[$j]) ($widths[$j]-16) 130 13;$rh=[math]::Max($rh,($wr-split "`r").Count*16.25+14)}
            $height+=$rh
        };return $height+8
    }
    function Table($Id,$P,$Box,[bool]$Stretch=$false) {
        $x=$Box[0]+10;$y=$Box[1]+35;$w=$Box[2]-20;$limit=$Box[1]+$Box[3]-9
        $heads=@($P.table.headers);$rows=@($P.table.rows)
        $widths=if($heads.Count -eq 2){@(($w*0.38),($w*0.62))}else{@($w/$heads.Count)*$heads.Count}
        if($heads.Count -lt 2 -or $heads.Count -gt 4){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 table columns'}
        $extra=if($Stretch){[math]::Max([double]0,([double]$Box[3]-(TableH $P $Box[2]))/[double]($rows.Count+1))}else{0.0}
        for($r=0;$r -le $rows.Count;$r++){
            $vals=if($r -eq 0){$heads}else{@($rows[$r-1])};$rh=38.0
            for($j=0;$j -lt $heads.Count;$j++){$wr=WrapText ([string]$vals[$j]) ($widths[$j]-16) 130 13;$rh=[math]::Max($rh,($wr-split "`r").Count*16.25+14)}
            $rh+=$extra
            if($y+$rh -gt $limit+0.1){throw 'TEXT_NEEDS_SHORTEN: V4 table too tall'}
            $cx=$x
            for($j=0;$j -lt $heads.Count;$j++){
                $cell=$Id+'-cell-'+$r+'-'+$j;$isTotal=$sid -eq 'effects' -and $r -eq $rows.Count
                $fill=if($r -eq 0){$c.navy}elseif($isTotal){$c.mint}elseif($r%2){'#FFFFFF'}else{$c.light}
                Rect $cell $Id $cx $y $widths[$j] $rh $fill $c.edge
                $ink=if($r -eq 0){'#FFFFFF'}elseif($isTotal){$c.green}else{$c.ink}
                $textH=((WrapText ([string]$vals[$j]) ($widths[$j]-16) 130 13)-split "`r").Count*16.25+2
                Text ($cell+'-text') $cell ($cx+8) ($y+$(if($Stretch){($rh-$textH)/2}else{7})) ($widths[$j]-16) $(if($Stretch){$textH}else{$rh-12}) $vals[$j] 13 $ink ($r -eq 0 -or $isTotal)
                $cx+=$widths[$j]
            };$y+=$rh
        }
    }
    function Flow($Id,$P,$Box,[bool]$Vertical=$false,[bool]$Caption=$false) {
        $x=$Box[0]+12;$y=$Box[1]+$(if($Caption){54}else{38});$w=$Box[2]-24;$h=$Box[3]-$(if($Caption){65}else{49})
        if($Caption){Text ($Id+'-concept') $Id ($Box[0]+12) ($Box[1]+31) ($Box[2]-24) 18 '설명용 개념도' 11 $c.muted $false 'left' 'detail'}
        $steps=@($P.steps);$icons=@($P.step_icons);$n=$steps.Count
        if($n -lt 2 -or $n -gt 4 -or $icons.Count -ne $n){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 two to four illustrated flow nodes required'}
        $accent=if($P.tone -eq 'danger' -or $sid -eq 'problem'){$c.red}elseif($sid -eq 'rollout'){$c.gold}else{$c.blue}
        $tint=if($accent -eq $c.red){$c.pink}elseif($sid -eq 'rollout'){$c.sand}else{$c.light}
        $note=if($P.outcome){27.0}else{0.0}
        if($Vertical){
            $gap=10.0;$nh=[math]::Min(63,($h-$note-($n-1)*$gap)/$n)
            if($nh -lt 46){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 vertical flow too dense'}
            for($i=0;$i -lt $n;$i++){
                $ny=$y+$i*($nh+$gap);$node=$Id+'-step-'+$i
                Shape $node $Id 'roundrect' $x $ny $w $nh $tint ''
                Figure ($node+'-figure') $node $icons[$i] ($x+12) ($ny+7) 55 ($nh-14) $accent
                Text ($node+'-label') $node ($x+84) ($ny+12) ($w-98) ($nh-20) $steps[$i] 12.5 $c.ink $true
                if($i -lt $n-1){Shape ($Id+'-arrow-'+$i) $Id 'downArrow' ($x+$w/2-5) ($ny+$nh+1) 10 ($gap-2) $accent ''}
            };$used=$n*$nh+($n-1)*$gap
        }else{
            $gap=25.0;$nw=($w-($n-1)*$gap)/$n;$nh=[math]::Min(165,$h-$note)
            if($nw -lt 95 -or $nh -lt 110){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 horizontal flow too dense'}
            for($i=0;$i -lt $n;$i++){
                $nx=$x+$i*($nw+$gap);$node=$Id+'-step-'+$i
                Shape $node $Id 'roundrect' $nx $y $nw $nh '#FFFFFF' $c.edge
                Rect ($node+'-label-bg') $node ($nx+1) ($y+$nh-48) ($nw-2) 47 $tint ''
                $fw=[math]::Min(118,$nw-26);$fh=$nh-62
                Figure ($node+'-figure') $node $icons[$i] ($nx+($nw-$fw)/2) ($y+6) $fw $fh $accent
                Text ($node+'-label') ($node+'-label-bg') ($nx+8) ($y+$nh-41) ($nw-16) 38 $steps[$i] $(if($sid -eq 'problem' -and $i -eq $n-1){14}else{12.5}) $(if($sid -eq 'problem' -and $i -eq $n-1){$c.red}else{$c.ink}) $true 'center'
                if($i -lt $n-1){Shape ($Id+'-arrow-'+$i) $Id 'rightArrow' ($nx+$nw+5) ($y+$nh/2-5) ($gap-10) 10 $accent ''}
            };$used=$nh
        }
        if($P.outcome){Text ($Id+'-outcome') $Id $x ($y+$used+7) $w 22 $P.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function IsRange($Ms) {
        if(@($Ms).Count -ne 2){return $false}
        $a=[regex]::Match([string]$Ms[0].label,'^(.+?)\s*하한$');$b=[regex]::Match([string]$Ms[1].label,'^(.+?)\s*상한$')
        $va=[regex]::Match([string]$Ms[0].value_text,'^([0-9,]+(?:\.[0-9]+)?)([^0-9]+)$');$vb=[regex]::Match([string]$Ms[1].value_text,'^([0-9,]+(?:\.[0-9]+)?)([^0-9]+)$')
        return $a.Success -and $b.Success -and $a.Groups[1].Value.Trim() -ceq $b.Groups[1].Value.Trim() -and $va.Success -and $vb.Success -and $va.Groups[2].Value -ceq $vb.Groups[2].Value -and $va.Groups[2].Value -notmatch '이상|이하|초과|미만|약' -and [decimal]($va.Groups[1].Value.Replace(',','')) -le [decimal]($vb.Groups[1].Value.Replace(',',''))
    }
    function Metrics($Id,$P,$Box,[bool]$Stack=$false) {
        $x=$Box[0]+12;$y=$Box[1]+36;$w=$Box[2]-24;$h=$Box[3]-47;$ms=@($P.metrics);$n=$ms.Count
        if($n -lt 1 -or $n -gt 3){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 metrics count'}
        if(-not $Stack -and (IsRange $ms)){
            Shape ($Id+'-range') $Id 'roundrect' $x $y $w $h $c.mint ''
            $cw=($w-56)/2
            Text ($Id+'-range-value-0') ($Id+'-range') ($x+14) ($y+10) $cw 46 $ms[0].value_text 34 $c.green $true 'center' 'metric'
            Text ($Id+'-range-join') ($Id+'-range') ($x+$cw+14) ($y+17) 28 34 '~' 24 $c.green $true 'center' 'metric'
            Text ($Id+'-range-value-1') ($Id+'-range') ($x+$cw+42) ($y+10) $cw 46 $ms[1].value_text 34 $c.green $true 'center' 'metric'
            for($i=0;$i -lt 2;$i++){
                $mx=$x+14+$i*($cw+28)
                Text ($Id+'-metric-label-'+$i) ($Id+'-range') $mx ($y+64) $cw 31 $ms[$i].label 11.5 $c.ink $true 'center' 'label'
                if($ms[$i].detail){Text ($Id+'-metric-detail-'+$i) ($Id+'-range') $mx ($y+101) $cw ($h-107) $ms[$i].detail 11 $c.muted $false 'center' 'detail'}
            };return
        }
        $gap=9.0
        for($i=0;$i -lt $n;$i++){
            $node=$Id+'-metric-'+$i
            if($Stack){
                $nh=($h-($n-1)*$gap)/$n;$nx=$x;$ny=$y+$i*($nh+$gap);$nw=$w
                if($nh -lt 80){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 stacked metric density'}
                Shape $node $Id 'roundrect' $nx $ny $nw $nh $c.mint ''
                Text ($node+'-label') $node ($nx+12) ($ny+8) ($nw*0.55-18) ($nh-18) $ms[$i].label 12 $c.ink $true 'left' 'label'
                Text ($node+'-value') $node ($nx+$nw*0.55) ($ny+10) ($nw*0.45-9) 39 $ms[$i].value_text 26 $c.green $true 'right' 'metric'
                if($ms[$i].detail){Text ($node+'-detail') $node ($nx+$nw*0.55) ($ny+54) ($nw*0.45-9) ($nh-59) $ms[$i].detail 11 $c.muted $false 'right' 'detail'}
            }else{
                $nw=($w-($n-1)*$gap)/$n;$nx=$x+$i*($nw+$gap);$ny=$y;$nh=$h
                Shape $node $Id 'roundrect' $nx $ny $nw $nh $c.mint ''
                Text ($node+'-value') $node ($nx+12) ($ny+9) ($nw-24) 46 $ms[$i].value_text 32 $c.green $true 'left' 'metric'
                Text ($node+'-label') $node ($nx+12) ($ny+65) ($nw-24) 35 $ms[$i].label 12 $c.ink $true 'left' 'label'
                if($ms[$i].detail){Text ($node+'-detail') $node ($nx+12) ($ny+106) ($nw-24) ($nh-112) $ms[$i].detail 11 $c.muted $false 'left' 'detail'}
            }
        }
    }
    function Sum($Id,$P,$Box) {
        $steps=@($P.steps)
        if($P.relationship -ne 'sum' -or $steps.Count -ne 3){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 verified monetary sum only'}
        $x=$Box[0]+12;$y=$Box[1]+34;$w=$Box[2]-24;$gap=28.0;$cw=($w-2*$gap)/3
        for($i=0;$i -lt 3;$i++){
            $s=[string]$steps[$i];$m=[regex]::Match($s,' (?:USD|KRW) -?\d')
            if(-not $m.Success){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 sum currency marker missing'}
            $pos=$m.Index+1;$label=$s.Substring(0,$pos).Trim();$value=$s.Substring($pos)
            $node=$Id+'-sum-'+$i;$nx=$x+$i*($cw+$gap)
            Shape $node $Id 'roundrect' $nx $y $cw 51 $(if($i -eq 2){$c.mint}else{$c.light}) ''
            Text ($node+'-label') $node ($nx+7) ($y+1) ($cw-14) 17 $label 11.5 $c.ink $true 'center' 'label'
            Text ($node+'-value') $node ($nx+7) ($y+23) ($cw-14) 28 $value 22 $c.green $true 'center' 'metric'
            if($i -lt 2){Text ($Id+'-operator-'+$i) $Id ($nx+$cw+2) ($y+16) ($gap-4) 29 $(if($i -eq 0){'+'}else{'='}) 22 $c.navy $true 'center' 'metric'}
        }
        if($P.outcome){Text ($Id+'-outcome') $Id $x ($y+58) $w 18 $P.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function Bars($Id,$P,$Box) {
        $x=$Box[0]+12;$y=$Box[1]+36;$w=$Box[2]-24;$i=0
        foreach($b in @($P.bars)){
            if($null -eq $b.ratio -or [double]$b.ratio -lt 0 -or [double]$b.ratio -gt 1){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 bounded supplied bar ratio'}
            $ny=$y+56*$i
            Text ($Id+'-bar-label-'+$i) $Id $x $ny ($w-150) 26 $b.label 12 $c.ink $true
            Text ($Id+'-bar-number-'+$i) $Id ($x+$w-140) $ny 140 26 $b.value_text 20 $c.green $true 'right' 'metric'
            Rect ($Id+'-bar-track-'+$i) $Id $x ($ny+31) $w 8 $c.light ''
            if([double]$b.ratio -gt 0){Rect ($Id+'-bar-value-'+$i) $Id $x ($ny+31) ($w*[double]$b.ratio) 8 $c.green ''}
            $i++
        }
    }
    function HasLinks($P){return $null -ne $P.evidence_links -and @($P.evidence_links).Count -gt 0}
    function LinkPeers($P){return @($P.evidence_links|ForEach-Object {[int]$_.panel_index}|Select-Object -Unique)}
    function LinkedFlow($Id,$P,$Box) {
        $x=$Box[0]+12;$y=$Box[1]+54;$w=$Box[2]-24;$h=$Box[3]-65;$steps=@($P.steps);$n=$steps.Count
        $links=@{};$peerNames=New-Object 'Collections.Generic.List[string]';$notes=New-Object 'Collections.Generic.List[string]'
        if($P.outcome){$notes.Add([string]$P.outcome)}
        foreach($l in @($P.evidence_links)){
            $peer=$panels[[int]$l.panel_index];$k=[int]$l.step_index
            if(-not $links.ContainsKey($k)){$links[$k]=New-Object 'Collections.Generic.List[object]'}
            if(-not $peerNames.Contains([string]$peer.title)){$peerNames.Add([string]$peer.title);if($peer.outcome){$notes.Add(([string]$peer.title)+' · '+([string]$peer.outcome))}}
            foreach($j in @($l.item_indices)){
                if($peer.kind -eq 'table'){$value=(@($peer.table.rows[[int]$j])-join ' : ');$headers=@($peer.table.headers)-join ' / '}
                else{$value=[string]$peer.lines[[int]$j];$headers=''}
                $links[$k].Add(@{text=$value;headers=$headers;kind=$peer.kind;values=$(if($peer.kind -eq 'table'){@($peer.table.rows[[int]$j])}else{@()})})
            }
        }
        $noteH=0.0;foreach($note in $notes){$wrapped=WrapText $note $w 160 11;$noteH+=($wrapped-split "`r").Count*13.75+6}
        $h-=$noteH
        Text ($Id+'-evidence-caption') $Id ($Box[0]+12) ($Box[1]+31) ($Box[2]-24) 18 (($peerNames.ToArray()-join ' · ')+' · 설명용 개념도') 11 $c.muted $false 'left' 'detail'
        $gap=22.0;$units=0.0;$weights=@()
        for($i=0;$i -lt $n;$i++){$count=if($links.ContainsKey($i)){$links[$i].Count}else{0};$wt=1+0.4*$count;$weights+=,$wt;$units+=$wt}
        $usable=$w-($n-1)*$gap;$nx=$x
        $accent=if($sid -eq 'rollout'){$c.gold}else{$c.red};$tint=if($sid -eq 'rollout'){$c.sand}else{$c.pink}
        for($i=0;$i -lt $n;$i++){
            $nw=$usable*$weights[$i]/$units;$node=$Id+'-linked-step-'+$i
            Shape $node $Id 'roundrect' $nx $y $nw $h '#FFFFFF' $c.edge
            Rect ($node+'-heading-bg') $node ($nx+1) ($y+1) ($nw-2) 43 $tint ''
            $impact=$sid -eq 'problem' -and $i -eq $n-1
            Text ($node+'-heading') ($node+'-heading-bg') ($nx+9) ($y+8) ($nw-18) 33 $(if($impact -and -not $links.ContainsKey($i)){'관찰된 영향'}else{$steps[$i]}) 12.5 $c.ink $true 'center'
            $data=@(if($links.ContainsKey($i)){$links[$i].ToArray()})
            if($impact -and $data.Count -eq 0){
                Figure ($node+'-figure') $node $P.step_icons[$i] ($nx+($nw-104)/2) ($y+54) 104 70 $c.red
                Text ($node+'-impact-text') $node ($nx+12) ($y+125) ($nw-24) ($h-137) $steps[$i] 17 $c.red $true 'center'
            }elseif($data.Count -gt 0){
                $allTable=@($data|Where-Object {$_.kind -ne 'table'}).Count -eq 0
                $fh=if($allTable){45.0}else{64.0};$fw=if($allTable){68.0}else{98.0}
                if($allTable -and $data.Count -ge 2){$ty=$y+58}
                else{Figure ($node+'-figure') $node $P.step_icons[$i] ($nx+($nw-$fw)/2) ($y+50) $fw $fh $accent;$ty=$y+$fh+57}
                if($allTable){Text ($node+'-headers') $node ($nx+10) $ty ($nw-20) 18 $data[0].headers 10.5 $c.muted $false 'left' 'source';$ty+=23}
                foreach($z in 0..($data.Count-1)){
                    if($allTable){
                        $vv=@($data[$z].values);$label=[string]$vv[0];$body=@($vv|Select-Object -Skip 1)-join ' · '
                        $lw=[math]::Min(105,($nw-32)*0.32);$bw=$nw-39-$lw
                        $labelText=WrapText $label $lw 160 11.5;$bodyText=WrapText $body $bw 160 12.5
                        $hh=[math]::Max(($labelText-split "`r").Count*14.375,($bodyText-split "`r").Count*15.625)+16
                        if($ty+$hh -gt $y+$h-7){throw 'TEXT_NEEDS_SHORTEN: linked table evidence does not fit'}
                        Shape ($node+'-evidence-row-'+$z) $node 'roundrect' ($nx+9) $ty ($nw-18) $hh $c.light ''
                        Text ($node+'-evidence-label-'+$z) ($node+'-evidence-row-'+$z) ($nx+16) ($ty+7) $lw ($hh-12) $label 11.5 $accent $true
                        Text ($node+'-evidence-value-'+$z) ($node+'-evidence-row-'+$z) ($nx+25+$lw) ($ty+7) $bw ($hh-12) $body 12.5 $c.ink $false
                    }else{
                        $wr=WrapText ([string]$data[$z].text) ($nw-24) 160 13;$hh=($wr-split "`r").Count*16.25+3
                        if($ty+$hh -gt $y+$h-7){throw 'TEXT_NEEDS_SHORTEN: linked node evidence does not fit'}
                        Text ($node+'-evidence-'+$z) $node ($nx+12) $ty ($nw-24) $hh $data[$z].text 13 $c.ink $false
                    }
                    $ty+=$hh+7
                }
            }else{
                $fw=[math]::Min(128,$nw-30);$fh=[math]::Min(110,$h-66)
                Figure ($node+'-figure') $node $P.step_icons[$i] ($nx+($nw-$fw)/2) ($y+44+($h-44-$fh)/2) $fw $fh $accent
            }
            if($i -lt $n-1){Shape ($Id+'-linked-arrow-'+$i) $Id 'rightArrow' ($nx+$nw+4) ($y+$h/2-6) ($gap-8) 12 $accent ''}
            $nx+=$nw+$gap
        }
        $ny=$y+$h+5;for($j=0;$j -lt $notes.Count;$j++){
            $wr=WrapText $notes[$j] $w 160 11;$nh=($wr-split "`r").Count*13.75+1
            Text ($Id+'-note-'+$j) $Id $x $ny $w $nh $notes[$j] 11 $c.muted $false 'left' 'detail';$ny+=$nh+5
        }
    }
    function CompactCoverage($Id,$P,$Box){
        $x=$Box[0]+10;$y=$Box[1]+34;$w=$Box[2]-20;$rows=@($P.table.rows);$n=$rows.Count;$gap=8.0;$cw=($w-($n-1)*$gap)/$n
        Text ($Id+'-headers') $Id $x $y $w 16 (@($P.table.headers)-join ' / ') 10 $c.muted $false 'left' 'source'
        for($i=0;$i -lt $n;$i++){
            $nx=$x+$i*($cw+$gap);$node=$Id+'-coverage-'+$i
            Shape $node $Id 'roundrect' $nx ($y+18) $cw ($Box[3]-60) $c.light ''
            Text ($node+'-label') $node ($nx+10) ($y+24) ($cw-20) 18 ([string]$rows[$i][0]) 11.5 $c.ink $true 'left' 'label'
            Text ($node+'-status') $node ($nx+10) ($y+47) ($cw-20) 22 ([string]$rows[$i][1]) 12 $c.gold $true
        }
    }
    function CanJoinFinance($A,$B){
        if($A.kind -ne 'table' -or $B.relationship -ne 'sum' -or @($A.table.headers).Count -ne 2 -or @($A.table.rows).Count -ne 3 -or @($B.steps).Count -ne 3){return $false}
        for($j=0;$j -lt 3;$j++){if((([string]$A.table.rows[$j][0])+' '+([string]$A.table.rows[$j][1])) -cne [string]$B.steps[$j]){return $false}}
        return $true
    }
    function JoinedFinance($Id,$TableP,$SumP,$Box){
        $x=$Box[0]+12;$y=$Box[1]+53;$w=$Box[2]-24;$gap=30.0;$cw=($w-2*$gap)/3
        Text ($Id+'-source-heading') $Id $x ($Box[1]+31) $w 17 (([string]$SumP.title)+' · '+(@($TableP.table.headers)-join ' / ')) 10.5 $c.muted $false 'left' 'source'
        for($i=0;$i -lt 3;$i++){
            $nx=$x+$i*($cw+$gap);$node=$Id+'-term-'+$i
            Shape $node $Id 'roundrect' $nx $y $cw 69 $(if($i -eq 2){$c.mint}else{$c.light}) ''
            Text ($node+'-label') $node ($nx+8) ($y+6) ($cw-16) 19 ([string]$TableP.table.rows[$i][0]) 11.5 $c.ink $true 'center' 'label'
            Text ($node+'-value') $node ($nx+8) ($y+32) ($cw-16) 35 ([string]$TableP.table.rows[$i][1]) 26 $c.green $true 'center' 'metric'
            if($i -lt 2){Text ($Id+'-operator-'+$i) $Id ($nx+$cw+2) ($y+25) ($gap-4) 32 $(if($i -eq 0){'+'}else{'='}) 24 $c.navy $true 'center' 'metric'}
        }
        if($SumP.outcome){Text ($Id+'-outcome') $Id $x ($y+78) $w 18 $SumP.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function ActionRows(){
        $n=$panels.Count;$gap=10.0;$rh=(338-($n-1)*$gap)/$n;$dense=$n -ge 5
        for($i=0;$i -lt $n;$i++){
            $p=$panels[$i];$name='panel-'+($i+1);$x=20;$y=104+$i*($rh+$gap);$w=920
            Shape $name 'canvas' 'roundrect' $x $y $w $rh '#FFFFFF' $c.edge 'panel'
            Rect ($name+'-title-bg') $name ($x+1) ($y+1) 191 ($rh-2) $c.navy ''
            Text ($name+'-heading') ($name+'-title-bg') ($x+13) ($y+$(if($dense){8}else{17})) 167 ($rh-$(if($dense){16}else{30})) $p.title 13 $([string]'#FFFFFF') $true 'left' 'section'
            Figure ($name+'-figure') $name $p.icon ($x+207) ($y+$(if($dense){7}else{13})) 68 ($rh-$(if($dense){14}else{26})) $c.blue
            BulletRows ($name+'-facts') $name $p.lines ($x+294) ($y+$(if($dense){5}else{17})) 372 ($rh-$(if($dense){10}else{25})) $c.blue 12 $(if($dense){3}else{9})
            Shape ($name+'-purpose-arrow') $name 'rightArrow' ($x+675) ($y+$rh/2-6) 18 12 $c.green ''
            Shape ($name+'-purpose-bg') $name 'roundrect' ($x+710) ($y+8) 198 ($rh-16) $c.mint ''
            if(-not $dense){Text ($name+'-purpose-label') ($name+'-purpose-bg') ($x+720) ($y+14) 178 15 '조치 목적' 10 $c.green $false 'left' 'source'}
            Text ($name+'-purpose') ($name+'-purpose-bg') ($x+720) ($y+$(if($dense){12}else{37})) 178 ($rh-$(if($dense){24}else{49})) $p.outcome 12.5 $c.green $true
        }
    }
    function ScopeRows($Id,$P,$Box){
        $x=$Box[0]+12;$y=$Box[1]+36;$w=$Box[2]-24;$lines=@($P.lines);$n=$lines.Count
        $note=if($P.outcome){23.0}else{0.0};$gap=9.0;$rh=($Box[3]-48-$note-($n-1)*$gap)/$n
        $states=@($P.line_states);$hasStates=$null -ne $P.line_states;$referenceMode=@($P.statement_links).Count -gt 1
        for($i=0;$i -lt $n;$i++){
            $node=$Id+'-scope-'+$i;$ny=$y+$i*($rh+$gap)
            $state=if($hasStates){[string]$states[$i]}else{''}
            $accent=switch($state){'supported'{$c.green};'hypothesis'{$c.gold};'unknown'{$c.muted};default{$c.blue}}
            $tint=if($state -eq 'supported'){$c.mint}elseif($state -eq 'hypothesis'){$c.sand}else{$c.light}
            Shape $node $Id 'roundrect' $x $ny $w $rh $tint ''
            Rect ($node+'-mark') $node ($x+1) ($ny+1) 4 ($rh-2) $accent ''
            if($hasStates){
                $label=switch($state){'supported'{'자료 기반'};'hypothesis'{'가설'};'unknown'{'추가 확인'};'boundary'{'적용 범위'}}
                Text ($node+'-state') $node ($x+12) ($ny+12) 83 21 $label 11.5 $accent $true 'left' 'source'
            }
            $tx=if($hasStates){$x+110}else{$x+14};$tw=if($hasStates){$w-124}else{$w-28};$refText='';$refH=0.0
            if($referenceMode){
                $labels=@();foreach($link in @($P.statement_links|Where-Object {$_.line_index -eq $i})){foreach($row in @($link.row_indices)){$labels+=,[string]$panels[0].table.rows[[int]$row][0]}}
                if($labels.Count){$refText='연결 근거 · '+($labels -join ' / ');$refH=((WrapText $refText $tw 160 10.5)-split "`r").Count*13.125+1}
            }
            Text ($node+'-text') $node $tx ($ny+11) $tw ($rh-20-$(if($refH){$refH+5}else{0})) $lines[$i] 14 $c.ink $false
            if($refH){Text ($node+'-references') $node $tx ($ny+$rh-8-$refH) $tw $refH $refText 10.5 $c.muted $false 'left' 'source'}
        }
        if($P.outcome){Text ($Id+'-outcome') $Id $x ($Box[1]+$Box[3]-26) $w 19 $P.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function StateColumns($Id,$P,$Box){
        $groups=@(@($P.line_states)|Select-Object -Unique)
        if($groups.Count -gt 2){throw 'REFERENCE_LAYOUT_UNSUPPORTED: multiple effect states require the compact classified composition'}
        $gap=12.0;$w=($Box[2]-24-$gap*($groups.Count-1))/$groups.Count
        for($g=0;$g -lt $groups.Count;$g++){
            $state=[string]$groups[$g];$lines=@();for($i=0;$i -lt @($P.lines).Count;$i++){if($P.line_states[$i] -ceq $state){$lines+=,[string]$P.lines[$i]}}
            $x=$Box[0]+12+$g*($w+$gap);$y=$Box[1]+36;$node=$Id+'-state-group-'+$g
            $label=switch($state){supported{'공개된 효과'};unknown{'추가 확인·미산출'};hypothesis{'검증할 가설'};boundary{'적용 범위'}}
            $accent=if($state -ceq 'supported'){$c.green}else{$c.gold};$tint=if($state -ceq 'supported'){$c.mint}else{$c.sand}
            Shape $node $Id 'roundrect' $x $y $w ($Box[3]-46) $tint ''
            Text ($node+'-heading') $node ($x+12) ($y+8) ($w-24) 22 $label 13 $accent $true 'left' 'section'
            BulletRows ($node+'-facts') $node $lines ($x+12) ($y+39) ($w-24) ($Box[3]-94) $accent 13 10
        }
    }
    function CompactMetrics($Id,$P,$Box){
        $ms=@($P.metrics);$n=$ms.Count;$gap=9.0;$w=($Box[2]-24-($n-1)*$gap)/$n;$y=$Box[1]+35;$h=$Box[3]-44
        if($n -lt 1 -or $n -gt 3){throw 'REFERENCE_LAYOUT_UNSUPPORTED: compact metric count'}
        for($i=0;$i -lt $n;$i++){
            $x=$Box[0]+12+$i*($w+$gap);$node=$Id+'-compact-metric-'+$i
            Shape $node $Id 'roundrect' $x $y $w $h $c.mint ''
            Text ($node+'-value') $node ($x+12) ($y+6) ($w-24) 36 $ms[$i].value_text 28 $c.green $true 'left' 'metric'
            Text ($node+'-label') $node ($x+12) ($y+45) ($w-24) 30 $ms[$i].label 11.5 $c.ink $true 'left' 'label'
            if($ms[$i].detail){Text ($node+'-detail') $node ($x+12) ($y+80) ($w-24) ($h-85) $ms[$i].detail 11 $c.muted $false 'left' 'detail'}
        }
    }
    function CompactStateRows($Id,$P,$Box){
        $lines=@($P.lines);$n=$lines.Count;$gap=7.0;$note=if($P.outcome){23.0}else{0.0}
        if($n -gt 4){throw 'REFERENCE_LAYOUT_UNSUPPORTED: compact classified effects support up to four statements'}
        $x=$Box[0]+12;$y=$Box[1]+36;$w=$Box[2]-24;$rh=($Box[3]-48-$note-($n-1)*$gap)/$n
        if($rh -lt 30){throw 'TEXT_NEEDS_SHORTEN: classified effect rows and optional outcome exceed supported density'}
        for($i=0;$i -lt $n;$i++){
            $ny=$y+$i*($rh+$gap);$node=$Id+'-classified-'+$i;$state=[string]$P.line_states[$i]
            $label=switch($state){supported{'자료 기반'};unknown{'추가 확인'};hypothesis{'가설'};boundary{'적용 범위'}}
            $accent=switch($state){supported{$c.green};hypothesis{$c.gold};unknown{$c.muted};default{$c.blue}}
            $tint=if($state -eq 'supported'){$c.mint}elseif($state -eq 'hypothesis'){$c.sand}else{$c.light}
            Shape $node $Id 'roundrect' $x $ny $w $rh $tint ''
            Rect ($node+'-mark') $node ($x+1) ($ny+1) 4 ($rh-2) $accent ''
            Text ($node+'-state') $node ($x+12) ($ny+8) 86 18 $label 11.5 $accent $true 'left' 'source'
            Text ($node+'-text') $node ($x+112) ($ny+7) ($w-126) ($rh-14) $lines[$i] 12.3 $c.ink $false
        }
        if($P.outcome){Text ($Id+'-outcome') $Id $x ($Box[1]+$Box[3]-25) $w 18 $P.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function Strip($Id,$P,$Box,$Accent=$c.navy){
        $x=$Box[0];$y=$Box[1];$w=$Box[2];$h=$Box[3];$on=if($P.outcome){23.0}else{0.0}
        Rect $Id 'canvas' $x $y $w $h $c.light '' 'panel'
        Text ($Id+'-heading') $Id ($x+12) ($y+9) 164 26 $P.title 13 $Accent $true 'left' 'section'
        Text ($Id+'-body') $Id ($x+190) ($y+9) ($w-204) ($h-17-$on) (@($P.lines)-join ' · ') 11.5 $c.muted
        if($P.outcome){Text ($Id+'-outcome') $Id ($x+190) ($y+$h-24) ($w-204) 19 $P.outcome 11 $c.muted $false 'left' 'detail'}
    }
    function StatementConnections($P){
        $map=@{};foreach($s in $items){$map[$s.id]=$s};$i=0
        foreach($link in @($P.statement_links)){
            $target=$map['panel-2-scope-'+[int]$link.line_index]
            if(-not $target){throw 'REFERENCE_LAYOUT_UNSUPPORTED: statement target is not compiled'}
            $ty=$target.y+$target.h/2;$bus=420+4*$i;$ys=@($ty)
            $state=if($P.line_states){[string]$P.line_states[[int]$link.line_index]}else{''}
            $accent=if($state -ceq 'supported'){$c.green}elseif($state -ceq 'hypothesis'){$c.gold}else{$c.blue}
            foreach($row in @($link.row_indices)){
                $source=$map['panel-1-cell-'+([int]$row+1)+'-'+(@($panels[0].table.headers).Count-1)]
                if(-not $source){throw 'REFERENCE_LAYOUT_UNSUPPORTED: statement source row is not compiled'}
                $sy=$source.y+$source.h/2;$sx=$source.x+$source.w;$ys+=,$sy
                Rule ('statement-'+$i+'-row-'+$row) 'canvas' $sx $sy ($bus-$sx) 0 $accent 1.1
                Shape ('statement-'+$i+'-anchor-'+$row) 'canvas' 'ellipse' ($sx-2) ($sy-2) 4 4 $accent ''
            }
            $min=($ys|Measure-Object -Minimum).Minimum;$max=($ys|Measure-Object -Maximum).Maximum
            if($max -gt $min){Rule ('statement-'+$i+'-bus') 'canvas' $bus $min 0 ($max-$min) $accent 1.1}
            Shape ('statement-'+$i+'-arrow') 'canvas' 'rightArrow' ($bus+2) ($ty-4) ($target.x-$bus-4) 8 $accent ''
            $i++
        }
    }
    # Header and footer retain the reference's engineering-report hierarchy.
    Rect 'canvas' '' 0 0 960 540 '#FFFFFF' '' 'panel'
    Shape 'page-band' 'canvas' 'roundrect' 0 0 74 69 $c.navy ''
    $labels=@{problem='문제 현상';cause='원인 분석';actions='개선 사항';effects='효과 파악';rollout='횡전개'};$nums=@{problem='02';cause='03';actions='04';effects='05';rollout='06'}
    Text 'page-number' 'page-band' 12 18 50 36 $nums[$sid] 28 '#FFFFFF' $true 'center' 'metric'
    Text 'section-name' 'canvas' 90 17 128 30 $labels[$sid] 21 $c.navy $true 'left' 'section'
    Rule 'header-divider' 'canvas' 222 21 0 23 $c.navy 1.3
    Text 'page-title' 'canvas' 238 16 704 37 $Stage.title 23.5 $c.navy $true 'left' 'title'
    Text 'page-subtitle' 'canvas' 90 56 852 28 $Stage.subtitle 11.5 $c.muted
    Rule 'header-rule' 'canvas' 20 88 920 0 $c.edge 0.8
    if($sid -eq 'problem' -and $panels.Count -eq 2 -and $panels[0].kind -eq 'bullets' -and -not (HasLinks $panels[1])){
        $bh=96+$(if($panels[0].outcome){23}else{0});$fy=104+$bh+14;$fh=454-$fy
        Panel 'panel-1' @(20,104,920,$bh) $panels[0].title $c.navy
        BulletRows 'panel-1-facts' 'panel-1' $panels[0].lines 36 142 884 51 $c.blue 13 6
        if($panels[0].outcome){Text 'panel-1-outcome' 'panel-1' 36 (104+$bh-24) 884 19 $panels[0].outcome 11 $c.muted $false 'left' 'detail'}
        Panel 'panel-2' @(20,$fy,920,$fh) $panels[1].title $c.red
        Flow 'panel-2' $panels[1] @(20,$fy,920,$fh) $false $true
    }elseif($sid -eq 'problem' -and $panels[0].kind -eq 'asset' -and (HasLinks $panels[1])){
        Panel 'panel-1' @(20,126,270,286) $panels[0].title $c.navy
        Context 'panel-1' $panels[0] @(20,126,270,286)
        Panel 'panel-2' @(304,126,636,286) $panels[1].title $c.red
        LinkedFlow 'panel-2' $panels[1] @(304,126,636,286)
    }elseif($sid -eq 'problem' -and $panels.Count -eq 2 -and $panels[0].kind -eq 'bullets' -and (HasLinks $panels[1]) -and @($panels[1].evidence_links|Where-Object {$_.panel_index -ne 0 -or $_.step_index -ne 0}).Count -eq 0){
        Panel 'panel-1' @(20,104,920,96) $panels[0].title $c.navy
        BulletRows 'panel-1-facts' 'panel-1' $panels[0].lines 36 142 884 51 $c.blue 13 6
        if($panels[0].outcome){throw 'REFERENCE_LAYOUT_UNSUPPORTED: compact context outcome requires a different supported composition'}
        Panel 'panel-2' @(20,214,920,240) $panels[1].title $c.red
        Flow 'panel-2' $panels[1] @(20,214,920,240) $false $true
        Shape 'context-to-first-step' 'canvas' 'downArrow' 160 202 10 10 $c.red ''
    }elseif($sid -eq 'problem' -and $panels[0].kind -eq 'bullets' -and (HasLinks $panels[1])){
        $bh=260.0;$top=if($panels.Count -eq 3){128.0}else{150.0}
        Panel 'panel-2' @(20,$top,920,$bh) $panels[1].title $c.red
        LinkedFlow 'panel-2' $panels[1] @(20,$top,920,$bh)
        if($panels.Count -eq 3){
            Strip 'panel-3' $panels[2] @(20,410,920,$(if($panels[2].outcome){65}else{44})) $c.red
        }
    }elseif($sid -eq 'actions' -and $panels.Count -in @(3,4,5,6)){
        ActionRows
    }elseif($sid -eq 'effects' -and $panels[1].kind -eq 'bullets' -and $null -ne $panels[1].line_states){
        $groups=@(@($panels[1].line_states)|Group-Object);$maxLines=($groups|Measure-Object Count -Maximum).Maximum
        if($groups.Count -gt 2 -or $maxLines -gt 3){
            if($panels.Count -ne 2){throw 'REFERENCE_LAYOUT_UNSUPPORTED: compact classified effects use two panels'}
            Panel 'panel-1' @(20,104,920,146) $panels[0].title $c.green
            CompactMetrics 'panel-1' $panels[0] @(20,104,920,146)
            Panel 'panel-2' @(20,264,920,202) $panels[1].title $c.navy
            CompactStateRows 'panel-2' $panels[1] @(20,264,920,202)
        }else{
            Panel 'panel-1' @(20,104,920,178) $panels[0].title $c.green
            Metrics 'panel-1' $panels[0] @(20,104,920,178)
            $dh=if($maxLines -gt 2){170.0}else{158.0}
            Panel 'panel-2' @(20,296,920,$dh) $panels[1].title $c.navy
            StateColumns 'panel-2' $panels[1] @(20,296,920,$dh)
        }
    }elseif($sid -eq 'effects' -and $panels.Count -eq 3 -and (CanJoinFinance $panels[1] $panels[2])){
        Panel 'panel-1' @(20,104,920,182) $panels[0].title $c.green
        Metrics 'panel-1' $panels[0] @(20,104,920,182)
        Panel 'panel-2' @(20,300,920,154) $panels[1].title $c.navy
        JoinedFinance 'panel-2' $panels[1] $panels[2] @(20,300,920,154)
    }elseif($sid -eq 'cause' -and $panels[1].kind -eq 'flow' -and (HasLinks $panels[1])){
        $notes=if($panels[1].outcome){1}else{0};foreach($peerIndex in @(LinkPeers $panels[1])){if($panels[$peerIndex].outcome){$notes++}}
        $bh=240+20*$notes;$top=128-10*$notes
        Panel 'panel-2' @(20,$top,920,$bh) $panels[1].title $c.red
        LinkedFlow 'panel-2' $panels[1] @(20,$top,920,$bh)
        if($panels.Count -eq 3){
            Strip 'panel-3' $panels[2] @(20,($top+$bh+14),920,$(if($panels[2].outcome){65}else{43}))
        }
    }elseif($sid -eq 'cause' -and $panels[0].kind -eq 'table' -and $panels[1].kind -eq 'bullets'){
        if(@($panels[1].statement_links).Count -gt 1 -and $panels.Count -gt 2){throw 'REFERENCE_LAYOUT_UNSUPPORTED: multiple statement references require two cause panels; keep boundary facts in classified causal lines'}
        $sc=@($panels[1].lines).Count;$sn=if($panels[1].outcome){23}else{0};$sw=if($null -ne $panels[1].line_states){344.0}else{440.0}
        $th=TableH $panels[0] 392;$minScopeH=if(@($panels[1].statement_links).Count -gt 1){332.0}else{280.0}
        $sh=[math]::Max($minScopeH,(ListHeight $panels[1].lines $sw 14)+7*$sc+9*($sc-1)+48+$sn)
        $sh=[math]::Max($sh,$th);$th=$sh
        Panel 'panel-1' @(20,116,392,$th) $panels[0].title $c.navy
        Table 'panel-1' $panels[0] @(20,116,392,$th) $true
        Panel 'panel-2' @(448,116,492,$sh) $panels[1].title $c.navy
        ScopeRows 'panel-2' $panels[1] @(448,116,492,$sh)
        if($null -ne $panels[1].statement_links -and @($panels[1].statement_links).Count -eq 1){StatementConnections $panels[1]}
        else{Shape 'evidence-to-scope' 'canvas' 'rightArrow' 419 (116+[math]::Min($th,$sh)/2) 20 14 $c.blue ''}
        if($panels.Count -eq 3){
            $by=116+[math]::Max($th,$sh)+14
            Strip 'panel-3' $panels[2] @(20,$by,920,$(if($panels[2].outcome){65}else{43}))
        }
    }elseif($sid -eq 'rollout' -and (HasLinks $panels[1]) -and @($panels[1].steps).Count -eq 4 -and 0 -in @(LinkPeers $panels[1]) -and @($panels[1].evidence_links|Where-Object {$_.step_index -eq 3}).Count -eq 0){
        Panel 'panel-2' @(20,104,920,350) $panels[1].title $c.gold
        $fields=@{};foreach($prop in $panels[1].PSObject.Properties){$fields[$prop.Name]=$prop.Value}
        $fields.steps=@($panels[1].steps|Select-Object -First 3);$fields.step_icons=@($panels[1].step_icons|Select-Object -First 3);$fields.outcome=$null
        LinkedFlow 'panel-2' ([pscustomobject]$fields) @(20,104,920,254)
        Shape 'expansion-to-final' 'panel-2' 'downArrow' 782 365 12 16 $c.gold ''
        Shape 'panel-2-final-step' 'panel-2' 'roundrect' 32 389 896 54 $c.sand ''
        Figure 'panel-2-final-figure' 'panel-2-final-step' $panels[1].step_icons[3] 46 395 52 42 $c.gold
        Text 'panel-2-final-text' 'panel-2-final-step' 122 401 784 29 $panels[1].steps[3] 17 $c.gold $true
        if($panels[1].outcome){throw 'REFERENCE_LAYOUT_UNSUPPORTED: four-step final band outcome needs a supported variant'}
    }elseif($sid -eq 'rollout' -and (HasLinks $panels[1])){
        $peers=@(LinkPeers $panels[1]);$consumesCoverage=0 -in $peers
        if(-not $consumesCoverage){
            Panel 'panel-1' @(20,104,920,112) $panels[0].title $c.gold
            CompactCoverage 'panel-1' $panels[0] @(20,104,920,112)
            $fb=@(20,226,920,240)
        }else{$fb=@(20,145,920,266)}
        Panel 'panel-2' $fb $panels[1].title $c.gold
        LinkedFlow 'panel-2' $panels[1] $fb
    }elseif($sid -eq 'actions'){
        $n=$panels.Count
        if($n -lt 3 -or $n -gt 6){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 action count'}
        $cols=if($n -ge 5){3}else{$n};$rows=if($n -ge 5){2}else{1};$gap=12.0;$cw=(920-($cols-1)*$gap)/$cols
        $ch=if($rows -eq 2){164.0}else{238.0};$top=if($rows -eq 2){104.0}else{135.0}
        for($i=0;$i -lt $n;$i++){
            $p=$panels[$i];$name='panel-'+($i+1);$x=20+($i%$cols)*($cw+$gap);$y=$top+[math]::Floor($i/$cols)*($ch+12)
            if($p.role -ne 'action' -or $p.kind -ne 'bullets' -or -not $p.icon -or -not $p.outcome){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 action card required fields'}
            Panel $name @($x,$y,$cw,$ch) $p.title $c.navy
            $fw=if($rows -eq 2){65.0}else{80.0};$tx=$x+$fw+27;$tw=$cw-$fw-40
            Figure ($name+'-figure') $name $p.icon ($x+12) ($y+43) $fw $(if($rows -eq 2){65}else{90}) $c.blue
            $bh=$ch-83
            BulletRows ($name+'-facts') $name $p.lines $tx ($y+42) $tw $bh $c.blue 12
            Rect ($name+'-purpose-bg') $name ($x+8) ($y+$ch-37) ($cw-16) 29 $c.mint ''
            Text ($name+'-purpose-label') ($name+'-purpose-bg') ($x+15) ($y+$ch-32) 47 21 '목적' 10.5 $c.green $false 'left' 'source'
            Shape ($name+'-purpose-link') ($name+'-purpose-bg') 'rightArrow' ($x+62) ($y+$ch-27) 10 9 $c.green ''
            Text ($name+'-purpose') ($name+'-purpose-bg') ($x+84) ($y+$ch-32) ($cw-99) 21 $p.outcome 11.5 $c.green $true 'left' 'detail'
        }
    }else{
        $boxes=@()
        switch($sid){
            'problem'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'context' -or $panels[1].role -ne 'phenomenon'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 problem slots'}
                if($panels[0].kind -eq 'asset'){
                    $r=[double]$panels[0].asset.known_visible_aspect_ratio;$lw=if($r -ge 1.25){270.0}elseif($r -lt 0.85){240.0}else{252.0}
                    $rx=34+$lw;$rw=940-$rx
                    $ih=0.0
                    if($panels.Count -eq 3){$joined=@($panels[2].lines)-join ' · ';$wr=WrapText $joined 716 160 11.5;$ih=[math]::Max(44,($wr-split "`r").Count*14.375+18+$(if($panels[2].outcome){23}else{0}))}
                    $top=104+(350-225-$(if($ih){$ih+14}else{0}))/2
                    $boxes+=,@(20,$top,$lw,225);$boxes+=,@($rx,$top,$rw,225)
                    if($panels.Count -eq 3){$boxes+=,@(20,($top+239),920,$ih)}
                }else{
                    # A side-by-side concept and process reserve a real impact row,
                    # including its optional outcome. Do not squeeze the last row
                    # into whatever height remains after two full-width panels.
                    $boxes+=,@(20,104,280,225);$boxes+=,@(314,104,626,225)
                    if($panels.Count -eq 3){$boxes+=,@(20,343,920,99)}
                }
            }
            'cause'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'evidence' -or $panels[1].role -ne 'causal'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 cause slots'}
                $th=if($panels[0].kind -eq 'table'){TableH $panels[0] 392}else{260.0}
                $ch=if($panels[1].kind -eq 'flow'){235.0}else{[math]::Max(177,(ListHeight $panels[1].lines 388 12.3)+48)}
                if($ch -gt 270 -or $th -gt 270){throw 'TEXT_NEEDS_SHORTEN: V4 cause density'}
                $top=if($panels.Count -eq 2){132.0}else{104.0}
                $boxes+=,@(20,$top,392,$th);$boxes+=,@(426,$top,514,$ch)
                if($panels.Count -eq 3){$by=$top+[math]::Max($th,$ch)+14;$boxes+=,@(20,$by,920,([math]::Min(85,454-$by)))}
            }
            'effects'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'outcomes' -or $panels[1].role -ne 'details'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 effects slots'}
                if($panels.Count -eq 3){$boxes+=,@(20,104,354,226);$boxes+=,@(388,104,552,226);$boxes+=,@(20,344,920,111)}
                elseif($panels[1].kind -eq 'bars' -and @($panels[1].bars).Count -ge 3){$boxes+=,@(20,104,354,338);$boxes+=,@(388,104,552,338)}
                else{
                    $boxes+=,@(20,104,920,194)
                    $dh=if($panels[1].kind -eq 'table'){TableH $panels[1] 920}elseif($panels[1].kind -eq 'bars'){44+56*@($panels[1].bars).Count}else{[math]::Max(126,(ListHeight $panels[1].lines 778 12.3)+47)}
                    if($dh -gt 165){throw 'TEXT_NEEDS_SHORTEN: V4 effects detail density'}
                    $boxes+=,@(20,312,920,$dh)
                }
            }
            'rollout'{
                if($panels.Count -notin @(2,3) -or $panels[0].role -ne 'coverage' -or $panels[1].role -ne 'expansion'){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 rollout slots'}
                $th=TableH $panels[0] 392;$n=@($panels[1].steps).Count;$flowH=38+$n*59+($n-1)*10+12+$(if($panels[1].outcome){27}else{0})
                if($panels.Count -eq 3){$flowH=[math]::Min(260,$flowH)}
                $top=if($panels.Count -eq 2){116.0}else{104.0}
                $boxes+=,@(20,$top,392,$th);$boxes+=,@(426,$top,514,$flowH)
                if($panels.Count -eq 3){$by=$top+[math]::Max($th,$flowH)+12;$boxes+=,@(20,$by,920,(454-$by))}
            }
        }
        $allowed=@{context=@('bullets','asset');phenomenon=@('flow');impact=@('bullets');evidence=@('table','asset');causal=@('flow','bullets');boundary=@('bullets');outcomes=@('metrics');details=@('table','bars','bullets');calculation=@('flow');coverage=@('table');expansion=@('flow');checks=@('bullets')}
        for($i=0;$i -lt $panels.Count;$i++){
            $p=$panels[$i];$box=$boxes[$i];$name='panel-'+($i+1)
            if(-not $allowed.ContainsKey([string]$p.role) -or $p.kind -notin $allowed[[string]$p.role]){throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 role kind'}
            $accent=if($p.role -eq 'phenomenon' -or $p.tone -eq 'danger'){$c.red}elseif($p.role -eq 'outcomes'){$c.green}elseif($sid -eq 'rollout' -and $Stage.scope -eq 'proposal'){$c.gold}else{$c.navy}
            if($box[3] -lt 110 -and $p.kind -eq 'bullets'){
                Strip $name $p $box
                continue
            }
            Panel $name $box $p.title $accent
            if($p.role -eq 'calculation'){Sum $name $p $box;continue}
            switch($p.kind){
                'asset'{Context $name $p $box}
                'bullets'{if($p.role -eq 'context'){Context $name $p $box}else{Bullets $name $p $box}}
                'flow'{Flow $name $p $box ($p.role -eq 'expansion')}
                'table'{Table $name $p $box}
                'metrics'{Metrics $name $p $box ($panels.Count -eq 3 -or ($sid -eq 'effects' -and $panels[1].kind -eq 'bars' -and @($panels[1].bars).Count -ge 3))}
                'bars'{Bars $name $p $box}
                default{throw 'REFERENCE_LAYOUT_UNSUPPORTED: V4 component'}
            }
        }
        if($sid -eq 'problem' -and $panels[0].kind -eq 'asset' -and $panels.Count -eq 3){
            $flowBox=$boxes[1]
            Shape 'problem-to-impact' 'canvas' 'downArrow' ($flowBox[0]+$flowBox[2]/2-5) ($flowBox[1]+$flowBox[3]+3) 10 8 $c.red ''
        }
    }
    Text 'page-citation' 'canvas' 20 477 920 18 $Stage.citation 10.5 $c.muted $false 'left' 'source'
    Shape 'footer-band' 'canvas' 'roundrect' 12 503 936 29 $c.navy ''
    Text 'page-takeaway' 'footer-band' 24 508 912 20 $Stage.takeaway 12.5 '#FFFFFF' $true 'left' 'conclusion'
    $map=@{}
    foreach($s in $items){if($map.ContainsKey($s.id)){throw ('REFERENCE_DUPLICATE_ID: '+$s.id)};$map[$s.id]=$s}
    foreach($s in $items){
        if([double]::IsNaN($s.x) -or [double]::IsNaN($s.y) -or [double]::IsNaN($s.w) -or [double]::IsNaN($s.h) -or $s.x -lt 0 -or $s.y -lt 0 -or $s.w -lt 0 -or $s.h -lt 0 -or $s.x+$s.w -gt 960.01 -or $s.y+$s.h -gt 540.01){throw ('REFERENCE_GEOMETRY: '+$s.id)}
        if($s.parent){$b=$map[$s.parent];if($null -eq $b -or $s.x -lt $b.x-.1 -or $s.y -lt $b.y-.1 -or $s.x+$s.w -gt $b.x+$b.w+.1 -or $s.y+$s.h -gt $b.y+$b.h+.1){throw ('REFERENCE_PARENT: '+$s.id)}}
    }
    $text=@($items|Where-Object {$_.kind -in @('text','asset')})
    for($i=0;$i -lt $text.Count;$i++){for($j=$i+1;$j -lt $text.Count;$j++){
        $a=$text[$i];$b=$text[$j];$ow=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x);$oh=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
        if($ow -gt .5 -and $oh -gt .5){throw ('REFERENCE_TEXT_OVERLAP: '+$a.id+' / '+$b.id)}
    }}
    # Compare visible input leaves with the compiled result before any COM write.
    # Unsupported combinations must fail here instead of silently losing content.
    $visible=(($items|Where-Object {$_.kind -ceq 'text'}|ForEach-Object {$_.text}) -join ' ') -replace '\s+',' '
    $leaves=New-Object 'Collections.Generic.List[string]'
    foreach($field in @('title','subtitle','takeaway','citation')){if($Stage.$field){$leaves.Add([string]$Stage.$field)}}
    foreach($p in $panels){
        foreach($field in @('title','outcome')){if($p.$field){$leaves.Add([string]$p.$field)}}
        foreach($line in @($p.lines)){if($line){$leaves.Add([string]$line)}}
        foreach($step in @($p.steps)){
            if(-not $step){continue}
            if($p.relationship -ceq 'sum'){
                $m=[regex]::Match([string]$step,' (?:USD|KRW) -?\d')
                if($m.Success){$leaves.Add(([string]$step).Substring(0,$m.Index));$leaves.Add(([string]$step).Substring($m.Index+1))}else{$leaves.Add([string]$step)}
            }else{$leaves.Add([string]$step)}
        }
        if($p.table){foreach($v in @($p.table.headers)){if($v){$leaves.Add([string]$v)}};foreach($row in @($p.table.rows)){foreach($v in @($row)){if($v){$leaves.Add([string]$v)}}}}
        foreach($m in @($p.metrics)+@($p.bars)){foreach($field in @('label','value_text','detail')){if($m.$field){$leaves.Add([string]$m.$field)}}}
        if($p.asset -and $p.asset.description){$leaves.Add([string]$p.asset.description)}
    }
    foreach($leaf in $leaves){$needle=($leaf -replace '\s+',' ').Trim();if($needle -and -not $visible.Contains($needle)){throw ('REFERENCE_CONTENT_LOSS: unsupported composition would omit: '+$needle)}}
    return $items.ToArray()
}
