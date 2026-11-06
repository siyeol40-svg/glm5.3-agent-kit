# Fixed compound problem layout. Pure native specifications; no Office/media/network access.
# Input is a resolved reference-v5-problem stage. Ledger resolution belongs to ProblemV5/Core.
. (Join-Path $PSScriptRoot 'Proposal.Graphics.ps1')
. (Join-Path $PSScriptRoot 'Proposal.ProblemV5.ps1')
function Get-ProposalProblemV5Layout($Stage) {
    if([string]$Stage.id -cne 'problem' -or [string]$Stage.layout_profile -cne 'reference-v5-problem'){throw 'V5_LAYOUT_STAGE: only reference-v5-problem problem is supported'}
    if($null -ne $Stage.panels -and @($Stage.panels).Count -gt 0){throw 'V5_LAYOUT_MIXED: compound data cannot be mixed with panels'}
    $p=$Stage.problem
    $overview=$p.overview_photo
    foreach($field in @('comparison','path','evidence','impact')){if($null -eq $p.$field){throw ('V5_LAYOUT_REQUIRED: '+$field)}}
    foreach($column in @($p.comparison.baseline,$p.comparison.observed)){
        if($null -eq $column -or @($column.items).Count -notin @(2,3)){throw 'V5_LAYOUT_COMPARISON: two columns with two or three items are required'}
    }
    if(@($p.path.steps).Count -notin @(3,4)){throw 'V5_LAYOUT_PATH: three or four steps are required'}
    $pathKeys=if($p.path -is [Collections.IDictionary]){@($p.path.Keys)}else{@($p.path.PSObject.Properties.Name)}
    $pathRelationship='sequence'
    if('relationship' -cin $pathKeys){
        if($p.path.relationship -isnot [string] -or $p.path.relationship -cnotin @('sequence','parallel','procedure')){throw 'V5_LAYOUT_RELATIONSHIP: path.relationship requires sequence, parallel or procedure string'}
        $pathRelationship=$p.path.relationship
    }
    $procedure=$pathRelationship -ceq 'procedure'
    $comparisonFocus=Get-ProposalV5ComparisonFocus $p.comparison $pathRelationship
    $caseWidth=if($procedure){510}else{390}
    $caseInner=$caseWidth-24
    $pathX=20+$caseWidth+14
    $pathWidth=940-$pathX
    $pathInner=$pathWidth-24
    if(@($p.impact.groups).Count -ne 2){throw 'V5_LAYOUT_IMPACT: exactly two groups are required'}
    foreach($group in @($p.impact.groups)){
        if(@($group.lines).Count -notin @(1,2,3) -or $group.state -cnotin @('supported','risk','unknown')){throw 'V5_LAYOUT_IMPACT: one to three lines and a supported/risk/unknown state are required'}
    }
    $e=$p.evidence
    if($e.kind -ceq 'table'){
        if($null -ne $e.asset -or $null -eq $e.table -or @($e.table.headers).Count -ne 2 -or @($e.table.rows).Count -notin @(2,3,4)){throw 'V5_LAYOUT_TABLE: exactly two columns and two to four rows without asset are required'}
        foreach($row in @($e.table.rows)){if(@($row).Count -ne 2){throw 'V5_LAYOUT_TABLE: every row must have two cells'}}
    }elseif($e.kind -ceq 'asset'){
        if($null -ne $e.table -or $null -eq $e.asset){throw 'V5_LAYOUT_ASSET: supply an existing picture reference without a table'}
        $a=$e.asset;$ratio=$a.known_visible_aspect_ratio
        if($a.reference_kind -cne 'picture' -or $ratio -isnot [ValueType] -or $ratio -is [bool] -or [double]::IsNaN([double]$ratio) -or [double]::IsInfinity([double]$ratio) -or [double]$ratio -le 0){throw 'V5_LAYOUT_ASSET: finite positive COM picture ratio is required'}
        if($a.origin -cnotin @('provided','synthetic_test')){throw 'V5_LAYOUT_ASSET: declared origin is required'}
        foreach($field in @('document_name','shape_name','description')){if([string]::IsNullOrWhiteSpace([string]$a.$field)){throw ('V5_LAYOUT_ASSET: missing '+$field)}}
        if($null -eq $a.slide_index -or [double]$a.slide_index -lt 1 -or [double]$a.slide_index -ne [math]::Floor([double]$a.slide_index)){throw 'V5_LAYOUT_ASSET: positive slide reference is required'}
    }else{throw 'V5_LAYOUT_EVIDENCE: table or asset is required'}

    $items=New-Object 'Collections.Generic.List[object]'
    $textErrors=New-Object 'Collections.Generic.List[object]';$textErrorIds=@{}
    # Enumerate input leaves independently of the rendering calls so a missing renderer
    # cannot silently turn an omitted field into a successful content-preservation check.
    $leaves=New-Object 'Collections.Generic.List[string]'
    foreach($field in @('title','subtitle','takeaway','citation')){$leaves.Add([string]$Stage.$field)}
    foreach($zone in @($p.comparison,$p.path,$e,$p.impact)){foreach($field in @('title','note')){if($zone.$field){$leaves.Add([string]$zone.$field)}}}
    foreach($column in @($p.comparison.baseline,$p.comparison.observed)){$leaves.Add([string]$column.title);foreach($v in @($column.items)){$leaves.Add([string]$v)}}
    foreach($step in @($p.path.steps)){$leaves.Add([string]$step.title);$leaves.Add([string]$step.detail)}
    if($e.kind -ceq 'table'){foreach($v in @($e.table.headers)){$leaves.Add([string]$v)};foreach($row in @($e.table.rows)){foreach($v in @($row)){$leaves.Add([string]$v)}}}else{$leaves.Add([string]$e.asset.description)}
    foreach($group in @($p.impact.groups)){$leaves.Add([string]$group.title);foreach($v in @($group.lines)){$leaves.Add([string]$v)}}
    $c=@{navy='#0C315F';blue='#27669C';ink='#1C314B';muted='#596A7F';edge='#D6E1EB';light='#F3F7FB';red='#BE3540';pink='#FFF4F3';green='#207C59';mint='#EDF6F0';gold='#A87221';sand='#FBF6EC'}
    function Measure-V5Text([string]$Content,[double]$Size){
        $u=0.0;foreach($ch in $Content.ToCharArray()){if([char]::IsWhiteSpace($ch)){$u+=.39}elseif([int]$ch -ge 0x2E80){$u+=1.03}elseif([char]::IsUpper($ch)){$u+=.71}else{$u+=.60}};return $u*$Size
    }
    function Wrap-V5Text([string]$Content,[double]$W,[double]$H,[double]$Size){
        if([string]::IsNullOrWhiteSpace($Content)){throw 'V5_LAYOUT_EMPTY: a required visible string is empty'}
        $out=New-Object 'Collections.Generic.List[string]'
        foreach($paragraph in ($Content -split '\r\n|\r|\n')){
            $line=''
            foreach($word in @($paragraph -split '\s+'|Where-Object {$_ -ne ''})){
                if((Measure-V5Text $word $Size) -gt $W-2){throw ('TEXT_NEEDS_SHORTEN: V5 unbroken text exceeds slot: '+$word)}
                $candidate=if($line){$line+' '+$word}else{$word}
                if((Measure-V5Text $candidate $Size) -gt $W-2){$out.Add($line);$line=$word}else{$line=$candidate}
            };$out.Add($line)
        }
        if($out.Count*$Size*1.25 -gt $H+.1){throw ('TEXT_NEEDS_SHORTEN: V5 text exceeds fixed slot: '+$Content)}
        return ($out.ToArray()-join "`r")
    }
    function Add-V5TextError([string]$Id,[string]$Reason,[string]$Content,[double]$W,[double]$H,[double]$Size,[double]$LinePadding=0){
        if(-not $textErrorIds.ContainsKey($Id)){
            $requiredLines=$null;$requiredWidth=$null;$allowedLines=[math]::Max(0,[math]::Floor(($H+.1-$LinePadding)/($Size*1.25)))
            if(-not [string]::IsNullOrWhiteSpace($Content)){
                try{$wrapped=Wrap-V5Text $Content $W ([double]::MaxValue) $Size;$requiredLines=($wrapped-split "`r").Count}catch{
                    $requiredWidth=0.0
                    foreach($word in @($Content -split '\s+'|Where-Object {$_ -ne ''})){$requiredWidth=[math]::Max($requiredWidth,(Measure-V5Text $word $Size))}
                }
            }
            $textErrors.Add([pscustomobject]@{slot=$Id;reason=$Reason;text=$Content;width=$W;height=$H;font_size=$Size;required_lines=$requiredLines;allowed_lines=$allowedLines;required_word_width=$requiredWidth})
            $textErrorIds[$Id]=$true
        }
    }
    function Spec($Id,$Role,$Parent,$Kind,$X,$Y,$W,$H,$Content='',$Size=12,$Ink='',$Fill='',$Edge='',$Bold=$false,$Primitive='',$Align='left',$Stroke=.8){
        if(-not $Ink){$Ink=$c.ink}
        $item=[pscustomobject][ordered]@{id=[string]$Id;role=[string]$Role;parent=[string]$Parent;kind=[string]$Kind;x=[double]$X;y=[double]$Y;w=[double]$W;h=[double]$H;text=[string]$Content;font_size=[double]$Size;font_bold=[bool]$Bold;color=[string]$Ink;fill=[string]$Fill;line_color=[string]$Edge;primitive=[string]$Primitive;align=[string]$Align;line_width=[double]$Stroke;layout_revision='proposal-reference-r5'}
        if($Primitive -ceq 'roundrect'){$item|Add-Member -NotePropertyName corner_radius -NotePropertyValue .04}
        $items.Add($item)
    }
    function Text($Id,$Parent,$X,$Y,$W,$H,$Content,$Size=12,$Ink='',$Bold=$false,$Align='left',$Role='body',$CenterVertically=$false){
        try{$wrapped=Wrap-V5Text ([string]$Content) $W $H $Size}catch{
            if($_.Exception.Message -notmatch '^(TEXT_NEEDS_SHORTEN|V5_LAYOUT_EMPTY):'){throw}
            Add-V5TextError $Id $_.Exception.Message ([string]$Content) $W $H $Size
            return
        }
        if($CenterVertically){
            $lineHeight=($wrapped -split "`r").Count*$Size*1.25
            $Y+=($H-$lineHeight)/2
            $H=$lineHeight
        }
        Spec $Id $Role $Parent 'text' $X $Y $W $H $wrapped $Size $Ink '' '' $Bold '' $Align
    }
    function Rect($Id,$Parent,$X,$Y,$W,$H,$Fill='',$Edge='',$Role='detail'){Spec $Id $Role $Parent 'rect' $X $Y $W $H '' 12 '' $Fill $Edge}
    function Shape($Id,$Parent,$Primitive,$X,$Y,$W,$H,$Fill='',$Edge='',$Role='detail'){Spec $Id $Role $Parent 'shape' $X $Y $W $H '' 12 '' $Fill $Edge $false $Primitive}
    function Rule($Id,$Parent,$X,$Y,$W,$H,$Edge,$Stroke=.8){Spec $Id 'detail' $Parent 'line' $X $Y $W $H '' 12 '' '' $Edge $false '' 'left' $Stroke}
    function Panel($Id,$X,$Y,$W,$H,$Title,$Accent,$HeadingWidth=($W-24)){
        Shape $Id 'canvas' 'roundrect' $X $Y $W $H '#FFFFFF' $c.edge 'panel'
        Shape ($Id+'-tab') $Id 'roundrect' $X $Y $W 25 $Accent
        Text ($Id+'-heading') ($Id+'-tab') ($X+12) ($Y+4) $HeadingWidth 19 $Title 13 '#FFFFFF' $true 'left' 'section'
    }
    function Note($Id,$Parent,$X,$Y,$W,$Content){if($Content){Text $Id $Parent $X $Y $W 15 $Content 10.5 $c.muted $false 'left' 'source'}}
    function List($Id,$Parent,$Lines,$X,$Y,$W,$H,$Accent,$Size=12.0,$Gap=6.0){
        $cy=[double]$Y;$n=0
        foreach($v in @($Lines)){
            $slot=$Id+'-item-'+$n
            try{$wrapped=Wrap-V5Text ([string]$v) ($W-12) $H $Size}catch{
                if($_.Exception.Message -notmatch '^(TEXT_NEEDS_SHORTEN|V5_LAYOUT_EMPTY):'){throw}
                Add-V5TextError $slot $_.Exception.Message ([string]$v) ($W-12) $H $Size
                $n++;continue
            }
            $height=($wrapped-split "`r").Count*$Size*1.25+1
            if($cy+$height -gt $Y+$H+.1){
                Add-V5TextError $slot ('TEXT_NEEDS_SHORTEN: V5 list exceeds fixed slot: '+[string]$v) ([string]$v) ($W-12) ([math]::Max(0,$Y+$H-$cy)) $Size 1
                $cy+=$height+$Gap;$n++;continue
            }
            Shape ($Id+'-dot-'+$n) $Parent 'ellipse' $X ($cy+5) 3.2 3.2 $Accent
            Text ($Id+'-item-'+$n) $Parent ($X+12) $cy ($W-12) $height $v $Size $c.ink
            $cy+=$height+$Gap;$n++
        }
    }

    function Add-OverviewPhotoZones {
        $asset=$overview.asset
        $ratio=$asset.known_visible_aspect_ratio
        if($pathRelationship -cne 'parallel' -or $e.kind -cne 'table'){
            throw 'V5_OVERVIEW: overview photo requires parallel drivers and a separate evidence table'
        }
        if($ratio -isnot [ValueType] -or $ratio -is [bool] -or [double]::IsNaN([double]$ratio) -or $ratio -lt 1.5 -or $ratio -gt (16.0/9.0)){
            throw 'V5_OVERVIEW: overview photo ratio must be between 3:2 and 16:9'
        }
        if($asset.reference_kind -cne 'picture' -or $asset.origin -cnotin @('provided','synthetic_test')){
            throw 'V5_OVERVIEW: overview photo requires an existing picture reference and declared origin'
        }
        if(@($p.comparison.baseline.items).Count -ne 3 -or @($p.comparison.observed.items).Count -ne 3 -or
            $p.path.steps.Count -ne 4 -or $e.table.rows.Count -ne 4 -or
            @($p.impact.groups|Where-Object {$_.lines.Count -ne 2}).Count -gt 0){
            throw 'V5_OVERVIEW: requires three facts per comparison side, four drivers, four evidence rows and two lines per impact group'
        }
        if(@(@($p.comparison,$p.path,$e,$p.impact)|Where-Object {$_.note}).Count){
            throw 'V5_OVERVIEW: this layout does not have room for separate panel notes'
        }

        $photoId='overview-picture'
        Panel 'problem-overview' 20 101 424 371 '설비 구성 예시' $c.navy
        $photoWidth=400.0
        $photoHeight=$photoWidth/[double]$ratio
        $photoTop=131+((400/1.5)-$photoHeight)/2
        Spec $photoId 'evidence_asset' 'problem-overview' 'asset' 32 $photoTop $photoWidth $photoHeight
        $items[$items.Count-1]|Add-Member -NotePropertyName asset -NotePropertyValue $asset
        if($asset.origin -ceq 'synthetic_test'){
            Text ($photoId+'-origin') 'problem-overview' 32 ($photoTop+$photoHeight+3) $photoWidth 14 '가상 이미지 · 실제 사례 사진 아님' 10.5 $c.muted $false 'left' 'source'
        }
        Text 'comparison-column-0-title' 'problem-overview' 32 416 $photoWidth 16 $p.comparison.baseline.title 12 $c.navy $true 'left' 'label'
        $cardWidth=($photoWidth-12)/3
        for($i=0;$i -lt 3;$i++){
            $x=32+$i*($cardWidth+6);$id='overview-baseline-'+$i
            Rect $id 'problem-overview' $x 435 $cardWidth 33 $c.light
            Text ('comparison-column-0-facts-item-'+$i) $id ($x+5) 436 ($cardWidth-10) 31 $p.comparison.baseline.items[$i] 11.5 $c.ink $false 'left' 'body' $true
        }

        $rightX=456.0
        $rightWidth=484.0
        $innerX=$rightX+10
        $innerWidth=$rightWidth-20
        Panel 'problem-comparison' $rightX 101 $rightWidth 66 $p.comparison.title $c.navy 296
        Text 'comparison-column-1-title' 'problem-comparison-tab' 780 105 148 17 $p.comparison.observed.title 11.5 '#DCEBF5' $false 'right' 'label'
        $cardWidth=($innerWidth-12)/3
        for($i=0;$i -lt 3;$i++){
            $x=$innerX+$i*($cardWidth+6);$id='overview-observed-'+$i
            Rect $id 'problem-comparison' $x 130 $cardWidth 33 '#E7F0F8'
            Text ('comparison-column-1-facts-item-'+$i) $id ($x+6) 131 ($cardWidth-12) 31 $p.comparison.observed.items[$i] 11.5 $c.navy $true 'left' 'body' $true
        }

        Panel 'problem-path' $rightX 173 $rightWidth 82 $p.path.title $c.red
        ($items|Where-Object id -ceq 'problem-path')|Add-Member -NotePropertyName relationship -NotePropertyValue $pathRelationship
        $cardWidth=($innerWidth-12)/4
        for($i=0;$i -lt 4;$i++){
            $x=$innerX+$i*($cardWidth+4);$id='path-step-'+$i
            $step=$p.path.steps[$i]
            Rect $id 'problem-path' $x 201 $cardWidth 50 $c.light
            foreach($figure in @(Get-ProposalIllustrationSpecs -Prefix ($id+'-figure') -Parent $id -Type ([string]$step.icon) -X ($x+5) -Y 204 -W 16 -H 14 -Color $c.blue -Revision 'proposal-reference-r5')){$items.Add($figure)}
            Text ($id+'-title') $id ($x+24) 203 ($cardWidth-29) 16 $step.title 11.5 $c.navy $true 'left' 'label'
            Text ($id+'-detail') $id ($x+5) 220 ($cardWidth-10) 29 $step.detail 11.5 $c.ink
        }

        Panel 'problem-evidence' $rightX 261 $rightWidth 117 $e.title $c.navy
        $rows=@(,$e.table.headers)+@($e.table.rows)
        $columnWidths=@(157.0,($innerWidth-157.0))
        for($r=0;$r -lt $rows.Count;$r++){
            $x=$innerX;$y=287+$r*18
            $fill=if($r -eq 0 -or $r%2 -eq 0){$c.light}else{'#FFFFFF'}
            for($col=0;$col -lt 2;$col++){
                $id='evidence-cell-'+$r+'-'+$col
                $width=$columnWidths[$col]
                Rect $id 'problem-evidence' $x $y $width 18 $fill $c.edge
                Text ($id+'-text') $id ($x+6) ($y+1.5) ($width-12) 15 $rows[$r][$col] 11.5 $c.ink ($r -eq 0)
                $x+=$width
            }
        }

        Panel 'problem-impact' $rightX 384 $rightWidth 88 $p.impact.title $c.navy
        $stateLabels=@{supported='제시된 내용';risk='발생 위험';unknown='미확인'}
        $cardWidth=($innerWidth-8)/2
        for($i=0;$i -lt 2;$i++){
            $x=$innerX+$i*($cardWidth+8);$id='impact-group-'+$i
            $group=$p.impact.groups[$i]
            $accent=if($group.state -ceq 'risk'){$c.gold}elseif($group.state -ceq 'unknown'){$c.muted}else{$c.blue}
            $fill=if($group.state -ceq 'risk'){$c.sand}else{$c.light}
            Rect $id 'problem-impact' $x 413 $cardWidth 56 $fill
            Text ($id+'-title') $id ($x+5) 415 ($cardWidth-83) 16 $group.title 11.5 $c.ink $true 'left' 'label'
            Text ($id+'-state') $id ($x+$cardWidth-77) 415 72 16 $stateLabels[$group.state] 11.5 $accent $true 'right' 'label'
            for($line=0;$line -lt 2;$line++){
                $y=433+$line*17
                Shape ($id+'-lines-dot-'+$line) $id 'ellipse' ($x+5) ($y+5) 3.2 3.2 $accent
                Text ($id+'-lines-item-'+$line) $id ($x+14) $y ($cardWidth-19) 15 $group.lines[$line] 11.5 $c.ink
            }
        }
    }

    Rect 'canvas' '' 0 0 960 540 '#FFFFFF' '' 'background'
    Shape 'page-band' 'canvas' 'roundrect' 0 0 74 69 $c.navy
    Text 'page-number' 'page-band' 12 18 50 36 '02' 28 '#FFFFFF' $true 'center' 'metric'
    Text 'section-name' 'canvas' 90 17 128 30 '문제 현상' 21 $c.navy $true 'left' 'section'
    Rule 'header-divider' 'canvas' 222 21 0 23 $c.navy 1.3
    Text 'page-title' 'canvas' 238 16 704 37 $Stage.title 23.5 $c.navy $true 'left' 'title'
    Text 'page-subtitle' 'canvas' 90 56 852 28 $Stage.subtitle 11.5 $c.muted
    Rule 'header-rule' 'canvas' 20 88 920 0 $c.edge

    if($overview){Add-OverviewPhotoZones}else{
    # Comparison is always two business axes; their supplied titles determine the meaning.
    Panel 'problem-comparison' 20 104 $caseWidth 184 $p.comparison.title $c.navy
    $columnWidth=($caseWidth-30)/2
    $columnInner=$columnWidth-20
    $ci=0
    foreach($column in @($p.comparison.baseline,$p.comparison.observed)){
        $x=30+$ci*($columnWidth+10);$id='comparison-column-'+$ci;$accent=$c.blue;$fill=$c.light
        if($procedure -and $ci -eq 1){$fill='#E7F0F8';$accent=$c.navy}
        $ch=if($p.comparison.note){120.0}else{140.0}
        Rect $id 'problem-comparison' $x 137 $columnWidth $ch $fill
        Text ($id+'-title') $id ($x+10) 143 $columnInner 20 $column.title 12.5 $accent $true 'left' 'label'
        if($null -ne $comparisonFocus){
            $selected=if($ci -eq 0){$comparisonFocus.baseline_item}else{$comparisonFocus.observed_item}
            $focusFill=if($ci -eq 0){'#DCEBF5'}else{'#205E90'}
            $focusInk=if($ci -eq 0){$c.navy}else{'#FFFFFF'}
            $focusH=if($p.comparison.note){40}else{52}
            $focusId=$id+'-focus'
            Rect $focusId $id ($x+7) 165 ($columnWidth-14) $focusH $focusFill
            Text ($focusId+'-text') $focusId ($x+12) 170 ($columnWidth-24) ($focusH-7) $column.items[$selected] 16 $focusInk $true 'center' 'body' $true
            $remaining=@(for($j=0;$j -lt $column.items.Count;$j++){if($j -ne $selected){$column.items[$j]}})
            $factsY=171+$focusH
            List ($id+'-facts') $id $remaining ($x+10) $factsY $columnInner (131+$ch-$factsY) $accent 11.5 4
        }else{
            Rule ($id+'-rule') $id ($x+10) 168 $columnInner 0 $c.edge
            List ($id+'-facts') $id $column.items ($x+10) 178 $columnInner ($ch-48) $accent 12 5
        }
        $ci++
    }
    Note 'comparison-note' 'problem-comparison' 32 267 $caseInner $p.comparison.note

    # Native concept glyphs explain each supplied item. Parallel observations must
    # not acquire an implied causal or temporal chain from decorative arrows.
    $pathAccent=if($procedure){$c.blue}else{$c.red}
    Panel 'problem-path' $pathX 104 $pathWidth 184 $p.path.title $pathAccent
    $pathPanel=@($items|Where-Object {$_.id -ceq 'problem-path'})[0]
    $pathPanel|Add-Member -NotePropertyName relationship -NotePropertyValue $pathRelationship
    $steps=@($p.path.steps)
    if($procedure){
        # A documented procedure is ordered without implying a failure chain.
        # Numbers replace decorative glyphs and leave the full row for the action.
        $x=$pathX+12;$gap=6.0;$stackHeight=if($p.path.note){126.0}else{142.0}
        $rowH=($stackHeight-($steps.Count-1)*$gap)/$steps.Count
        for($i=0;$i -lt $steps.Count;$i++){
            $step=$steps[$i];$id='path-step-'+$i;$y=136+$i*($rowH+$gap)
            Rect $id 'problem-path' $x $y $pathInner $rowH $c.light
            $discY=$y+($rowH-17)/2
            Shape ($id+'-disc') $id 'ellipse' ($x+8) $discY 17 17 $c.blue
            Text ($id+'-number') ($id+'-disc') ($x+8) ($discY+1) 17 16 ([string]($i+1)) 11.5 '#FFFFFF' $true 'center' 'label'
            Text ($id+'-title') $id ($x+34) ($y+4) 94 ($rowH-6) $step.title 12 $c.navy $true 'left' 'label'
            Text ($id+'-detail') $id ($x+136) ($y+4) ($pathInner-145) ($rowH-6) $step.detail 11.5 $c.ink
            if($i -lt $steps.Count-1){Shape ('path-arrow-'+$i) 'problem-path' 'downArrow' ($x+13.5) ($y+$rowH+1) 6 4 $c.blue}
        }
    }else{
        $gap=16.0;$nw=(492-($steps.Count-1)*$gap)/$steps.Count;$nh=if($p.path.note){127.0}else{141.0}
        for($i=0;$i -lt $steps.Count;$i++){
            $step=$steps[$i];$x=436+$i*($nw+$gap);$id='path-step-'+$i
            Rect $id 'problem-path' $x 137 $nw $nh $c.light
            Text ($id+'-title') $id ($x+6) 141 ($nw-12) 31 $step.title 12 $c.ink $true 'center' 'label'
            foreach($g in @(Get-ProposalIllustrationSpecs -Prefix ($id+'-figure') -Parent $id -Type ([string]$step.icon) -X ($x+6) -Y 175 -W ($nw-12) -H 44 -Color $c.blue -Revision 'proposal-reference-r5')){$items.Add($g)}
            Text ($id+'-detail') $id ($x+7) 223 ($nw-14) ($nh-88) $step.detail 11.5 $c.ink $false 'center'
            if($pathRelationship -ceq 'sequence' -and $i -lt $steps.Count-1){Shape ('path-arrow-'+$i) 'problem-path' 'rightArrow' ($x+$nw+3) 192 ($gap-6) 9 $c.red}
        }
    }
    Note 'path-note' 'problem-path' ($pathX+12) 269 $pathInner $p.path.note

    # Evidence retains two actual table columns or one existing, aspect-locked picture reference.
    Panel 'problem-evidence' 20 300 $caseWidth 164 $e.title $c.navy
    if($e.kind -ceq 'table'){
        $heads=@($e.table.headers);$rows=@($e.table.rows);$limit=if($e.note){441.0}else{456.0}
        $labelWidth=133.0
        if($pathRelationship -ceq 'parallel'){
            $wideLabel=174.0
            $tableRows=@(,$heads)+$rows
            $labelNeedsRoom=@($tableRows|Where-Object {(Measure-V5Text ([string]$_[0]) 11.5) -gt ($labelWidth-16)}).Count -gt 0
            $wideTableWraps=@($tableRows|Where-Object {
                $_[0] -match '[\r\n]' -or $_[1] -match '[\r\n]' -or
                (Measure-V5Text ([string]$_[0]) 11.5) -gt ($wideLabel-16) -or
                (Measure-V5Text ([string]$_[1]) 11.5) -gt ($caseInner-$wideLabel-16)
            }).Count -gt 0
            if($labelNeedsRoom -and -not $wideTableWraps){$labelWidth=$wideLabel}
        }
        $widths=@($labelWidth,($caseInner-$labelWidth))
        # Each row reserves the taller of its two wrapped cells at the fixed font.
        # Spare height belongs to the table as a whole, not to equal rigid row slots.
        $minimums=New-Object 'Collections.Generic.List[double]';$minimumTotal=0.0
        for($r=0;$r -le $rows.Count;$r++){
            $values=if($r -eq 0){$heads}else{@($rows[$r-1])};$minimum=11.5*1.25+6
            for($j=0;$j -lt 2;$j++){
                try{$wrapped=Wrap-V5Text ([string]$values[$j]) ($widths[$j]-14) ([double]::MaxValue) 11.5}catch{
                    if($_.Exception.Message -notmatch '^(TEXT_NEEDS_SHORTEN|V5_LAYOUT_EMPTY):'){throw}
                    Add-V5TextError ('evidence-cell-'+$r+'-'+$j+'-text') $_.Exception.Message ([string]$values[$j]) ($widths[$j]-14) ($limit-332) 11.5
                    continue
                }
                $minimum=[math]::Max($minimum,($wrapped-split "`r").Count*11.5*1.25+6)
            };$minimums.Add($minimum);$minimumTotal+=$minimum
        }
        $tableFits=$minimumTotal -le $limit-332+.1
        if(-not $tableFits){Add-V5TextError 'evidence-table' ('TEXT_NEEDS_SHORTEN: V5 table minimum row heights exceed fixed area: '+$minimumTotal+' > '+($limit-332)) '' $caseInner ($limit-332) 11.5}
        $extra=($limit-332-$minimumTotal)/($rows.Count+1);$y=332.0
        for($r=0;$tableFits -and $r -le $rows.Count;$r++){
            $values=if($r -eq 0){$heads}else{@($rows[$r-1])};$x=32.0;$rh=$minimums[$r]+$extra
            for($j=0;$j -lt 2;$j++){
                $id='evidence-cell-'+$r+'-'+$j;$fill=if($r -eq 0){$c.light}elseif($r%2){'#FFFFFF'}else{$c.light}
                Rect $id 'problem-evidence' $x $y $widths[$j] $rh $fill $c.edge
                $bold=$r -eq 0 -or ($procedure -and $j -eq 1)
                $ink=if($procedure -and $r -gt 0 -and $j -eq 1){$c.navy}else{$c.ink}
                Text ($id+'-text') $id ($x+7) ($y+3) ($widths[$j]-14) ($rh-6) $values[$j] 11.5 $ink $bold 'left' $(if($r -eq 0){'label'}else{'body'})
                $x+=$widths[$j]
            };$y+=$rh
        }
    }else{
        $a=$e.asset;$captionH=if($a.origin -ceq 'synthetic_test'){18.0}else{0.0};$frameH=if($e.note){109.0}else{124.0}
        $fx=32.0;$fy=332.0;$fw=$caseInner;$fh=$frameH-$captionH;$photoW=if($procedure){200.0}else{156.0}
        Rect 'evidence-photo-frame' 'problem-evidence' $fx $fy $fw $frameH $c.light
        $pw=[math]::Min(($photoW-12),($fh-8)*[double]$a.known_visible_aspect_ratio);$ph=$pw/[double]$a.known_visible_aspect_ratio
        Spec 'evidence-picture' 'evidence_asset' 'evidence-photo-frame' 'asset' ($fx+($photoW-$pw)/2) ($fy+($fh-$ph)/2) $pw $ph
        $items[$items.Count-1]|Add-Member -NotePropertyName asset -NotePropertyValue $a
        if($captionH){Text 'evidence-picture-origin' 'evidence-photo-frame' ($fx+5) ($fy+$fh) ($fw-10) 15 '가상 이미지 · 실제 사례 사진 아님' 10.5 $c.muted $false 'center' 'source'}
        Text 'evidence-picture-description' 'evidence-photo-frame' ($fx+$photoW+12) ($fy+5) ($fw-$photoW-20) ($fh-10) $a.description 11.5 $c.ink
    }
    Note 'evidence-note' 'problem-evidence' 32 446 $caseInner $e.note

    Panel 'problem-impact' $pathX 300 $pathWidth 164 $p.impact.title $c.navy
    $stateLabels=@{supported='제시된 내용';risk='발생 위험';unknown='미확인'};$i=0
    foreach($group in @($p.impact.groups)){
        $id='impact-group-'+$i;$state=[string]$group.state
        $accent=if($state -ceq 'risk'){$c.gold}elseif($state -ceq 'unknown'){$c.muted}else{$c.blue}
        $fill=if($state -ceq 'risk'){$c.sand}else{$c.light}
        if($procedure){
            $x=$pathX+12;$gh=if($p.impact.note){53.0}else{59.0};$y=332+$i*($gh+5)
            Rect $id 'problem-impact' $x $y $pathInner $gh $fill
            Text ($id+'-title') $id ($x+9) ($y+3) 104 31.5 $group.title 12.5 $c.ink $true 'left' 'label'
            Text ($id+'-state') $id ($x+9) ($y+35) 104 16 $stateLabels[$state] 11.5 $accent $true 'left' 'label'
            Rule ($id+'-divider') $id ($x+115) ($y+6) 0 ($gh-12) $c.edge
            List ($id+'-lines') $id $group.lines ($x+124) ($y+3) ($pathInner-133) ($gh-5) $accent 11.5 2.0
        }else{
            $x=436+$i*254;$gh=if($p.impact.note){109.0}else{124.0}
            Rect $id 'problem-impact' $x 332 238 $gh $fill
            Text ($id+'-title') $id ($x+10) 338 218 20 $group.title 12.5 $c.ink $true 'left' 'label'
            Text ($id+'-state') $id ($x+10) 361 218 16 $stateLabels[$state] 11.5 $accent $true 'left' 'label'
            List ($id+'-lines') $id $group.lines ($x+10) 384 218 ($gh-58) $accent 11.5 2.0
        }
        $i++
    }
    Note 'impact-note' 'problem-impact' ($pathX+12) 446 $pathInner $p.impact.note
    }
    Text 'page-citation' 'canvas' 20 477 920 18 $Stage.citation 10.5 $c.muted $false 'left' 'source'
    Shape 'footer-band' 'canvas' 'roundrect' 12 503 936 29 $c.navy
    Text 'page-takeaway' 'footer-band' 24 508 912 20 $Stage.takeaway 12.5 '#FFFFFF' $true 'left' 'conclusion'

    # No partial layout escapes. Text diagnostics are gathered from independent slots
    # first, then one failure stops the complete layout before any caller can use it.
    if($textErrors.Count){
        $details=New-Object 'Collections.Generic.List[string]'
        foreach($issue in @($textErrors|Select-Object -First 8)){
            $metric=if($null -ne $issue.required_lines){'lines '+$issue.required_lines+'/'+$issue.allowed_lines}elseif($null -ne $issue.required_word_width){'word width '+[math]::Round($issue.required_word_width,1)+'/'+[math]::Round(($issue.width-2),1)+'pt'}else{($issue.reason -replace '^TEXT_NEEDS_SHORTEN: V5 ','')}
            $sample=([string]$issue.text -replace '\s+',' ').Trim()
            if($sample.Length -gt 28){$sample=$sample.Substring(0,28)+'…'}
            $details.Add(('['+$issue.slot+'] '+$metric+$(if($sample){'; "'+$sample+'"'}else{''})))
        }
        if($textErrors.Count -gt 8){$details.Add(('Additional text slots: '+($textErrors.Count-8)))}
        $failure=New-Object InvalidOperationException ('TEXT_NEEDS_SHORTEN: V5 invalid text slots ('+$textErrors.Count+')'+"`n"+($details -join "`n"))
        $failure.Data['text_errors']=$textErrors.ToArray()
        throw $failure
    }
    # These are pre-mutation bounds checks, not a claim to have inspected rendered pixels.
    $map=@{}
    foreach($s in $items){
        if($map.ContainsKey($s.id)){throw ('V5_LAYOUT_DUPLICATE_ID: '+$s.id)};$map[$s.id]=$s
        foreach($field in @('x','y','w','h')){if([double]::IsNaN($s.$field) -or [double]::IsInfinity($s.$field)){throw ('V5_LAYOUT_GEOMETRY: '+$s.id)}}
        if($s.x -lt 0 -or $s.y -lt 0 -or $s.w -lt 0 -or $s.h -lt 0 -or $s.x+$s.w -gt 960.01 -or $s.y+$s.h -gt 540.01){throw ('V5_LAYOUT_GEOMETRY: '+$s.id)}
    }
    foreach($s in $items){if($s.parent){$b=$map[$s.parent];if($null -eq $b -or $s.x -lt $b.x-.1 -or $s.y -lt $b.y-.1 -or $s.x+$s.w -gt $b.x+$b.w+.1 -or $s.y+$s.h -gt $b.y+$b.h+.1){throw ('V5_LAYOUT_PARENT: '+$s.id)}}}
    $visible=@($items|Where-Object {$_.kind -cin @('text','asset')})
    for($i=0;$i -lt $visible.Count;$i++){for($j=$i+1;$j -lt $visible.Count;$j++){
        $a=$visible[$i];$b=$visible[$j];$ow=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x);$oh=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
        if($ow -gt .5 -and $oh -gt .5){throw ('V5_LAYOUT_LEAF_OVERLAP: '+$a.id+' / '+$b.id)}
    }}
    $text=@($items|Where-Object {$_.kind -ceq 'text'}|ForEach-Object {([string]$_.text -replace '\s+',' ').Trim()})
    foreach($leaf in $leaves){if((($leaf -replace '\s+',' ').Trim()) -cnotin $text){throw ('V5_LAYOUT_CONTENT_LOSS: '+$leaf)}}
    return $items.ToArray()
}
