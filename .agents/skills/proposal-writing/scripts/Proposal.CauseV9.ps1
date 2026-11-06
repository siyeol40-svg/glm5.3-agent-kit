# Generic observed-location and source-supported cause diagram. Pure native specifications.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')

function Assert-ProposalCauseV9Visuals($Stage){
    foreach($panel in @($Stage.panels|Where-Object {$null -ne $_})){
        $keys=if($panel -is [Collections.IDictionary]){@($panel.Keys)}else{@($panel.PSObject.Properties.Name)}
        if('statement_links' -cin $keys){throw 'V9_CAUSE_LINKS: statement_links is unsupported; use V9 location and order fields'}
    }
    if($Stage.layout_profile -cne 'reference-v9' -or $Stage.id -cne 'cause'){
        throw 'CAUSE_V9_PROFILE: reference-v9 cause required'
    }
    $panels=@($Stage.panels)
    $roles=@('system','evidence','causal','boundary')
    $kinds=@('bullets','table','bullets','bullets')
    if($panels.Count -ne 4){throw 'CAUSE_V9_PANELS: four panels required'}
    for($i=0;$i -lt 4;$i++){
        if($panels[$i].role -cne $roles[$i] -or $panels[$i].kind -cne $kinds[$i]){
            throw 'CAUSE_V9_PANELS: fixed panel role and kind required'
        }
    }
    $table=$panels[1].table
    $rows=@($table.rows)
    $causal=@($panels[2].lines)
    $states=@($panels[2].line_states)
    if(@($panels[0].lines).Count -notin 1..4 -or @($panels[3].lines).Count -notin 1..3 -or $causal.Count -notin 2..4){
        throw 'CAUSE_V9_LINES: system 1–4, causal 2–4, boundary 1–3'
    }
    if(@($table.headers).Count -ne 2 -or $rows.Count -notin 2..5){
        throw 'CAUSE_V9_TABLE: two columns and two to five rows required'
    }
    foreach($row in $rows){if(@($row).Count -ne 2){throw 'CAUSE_V9_TABLE: every evidence row needs two cells'}}
    if($states.Count -ne $causal.Count -or @($states|Where-Object {$_ -cnotin @('supported','hypothesis','boundary','unknown')}).Count){
        throw 'CAUSE_V9_CAUSAL_STATE: explicit recognized state required for each causal item'
    }
    foreach($panel in @($panels[1],$panels[2])){
        if(-not @($panel.source_ids).Count){throw 'CAUSE_V9_SOURCE: evidence and mechanism need source IDs'}
        foreach($id in $panel.source_ids){
            if([string]::IsNullOrWhiteSpace([string]$id) -or $id -cnotin @($Stage.source_ids)){
                throw 'CAUSE_V9_SOURCE: panel source must be declared on this stage'
            }
        }
    }

    function Assert-CauseV9Keys($Value,[string[]]$Expected){
        if($null -eq $Value){throw 'CAUSE_V9_KEYS: closed visual mapping required'}
        $keys=if($Value -is [Collections.IDictionary]){@($Value.Keys)}else{@($Value.PSObject.Properties.Name)}
        if($keys.Count -ne $Expected.Count -or @($Expected|Where-Object {$_ -cnotin $keys}).Count){
            throw 'CAUSE_V9_KEYS: unsupported or missing visual mapping field'
        }
    }
    function Assert-CauseV9Index($Index,[int]$Count){
        if(($Index -isnot [int] -and $Index -isnot [long]) -or $Index -lt 0 -or $Index -ge $Count){
            throw 'CAUSE_V9_INDEX: mapping requires a valid integer index'
        }
    }
    $visual=$Stage.visuals
    $cooling=$visual.kind -ceq 'water_cooled_plant'
    if($cooling){
        Assert-CauseV9Keys $visual @('kind','scope','source_id','locations','causal_order')
        if($visual.scope -cne 'general_principle'){throw 'COOLING_CAUSE_SCOPE: a general principle, not site piping, is required'}
        $source=$visual.source_id
        if($source -isnot [string] -or $source -cnotmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$' -or $source -cnotin @($Stage.source_ids) -or $source -cnotin @($panels[0].source_ids)){
            throw 'COOLING_CAUSE_SOURCE: reference general equipment evidence listed on the stage and system panel'
        }
    }else{
        Assert-CauseV9Keys $visual @('kind','locations','causal_order')
    }
    if($visual.kind -cnotin @('evidence_path','water_cooled_plant') -or $visual.locations -isnot [Collections.IList] -or $visual.causal_order -isnot [Collections.IList]){
        throw 'CAUSE_V9_VISUAL: a supported visual kind with location and causal arrays is required'
    }
    $locations=@($visual.locations)
    $order=@($visual.causal_order)
    if($locations.Count -notin 2..3 -or $order.Count -notin 2..3){
        throw 'CAUSE_V9_VISUAL: two to three observed locations and two to three linked causal items required'
    }
    $labels=@{}
    $coolingRows=@{}
    $coolingRoles=[ordered]@{
        chiller=@('Chiller','냉동기','수냉식 Chiller')
        pump=@('Water Pump','Circulation Pump','순환 Pump','순환 펌프')
        tower=@('Cooling Tower','냉각탑')
    }
    if($cooling -and $locations.Count -ne $coolingRoles.Count){
        throw 'COOLING_CAUSE_ROLE: include each of the three equipment roles once'
    }
    foreach($location in $locations){
        if($cooling){
            Assert-CauseV9Keys $location @('role','label','evidence_row')
            if($location.role -isnot [string] -or $location.role -cnotin @($coolingRoles.Keys) -or [string]$location.label -notin $coolingRoles[$location.role]){
                throw 'COOLING_CAUSE_ROLE: the diagram node must match its equipment category'
            }
            if(@($locations|Where-Object role -ceq $location.role).Count -ne 1){
                throw 'COOLING_CAUSE_ROLE: include each of the three equipment roles once'
            }
        }else{
            Assert-CauseV9Keys $location @('label','evidence_row')
        }
        $label=$location.label
        if($label -isnot [string] -or [string]::IsNullOrWhiteSpace($label) -or $label -cne $label.Trim() -or $label -match '[\r\n\t\[\]]' -or $label.Length -gt 30){
            throw 'CAUSE_V9_LOCATION_LABEL: use a short single-line phrase present in the evidence'
        }
        if($labels.ContainsKey($label)){throw 'CAUSE_V9_LOCATION_DUPLICATE: each location label must be distinct'}
        Assert-CauseV9Index $location.evidence_row $rows.Count
        if($cooling){
            if($coolingRows.ContainsKey([int]$location.evidence_row)){throw 'COOLING_CAUSE_ROW: assign a distinct evidence row to each equipment role'}
            $coolingRows[[int]$location.evidence_row]=$true
        }
        $pattern=[regex]::Escape($label)
        if($label -match '^[A-Za-z0-9]'){$pattern='(?<![A-Za-z0-9])'+$pattern}
        if($label -match '[A-Za-z0-9]$'){$pattern+='(?![A-Za-z0-9])'}
        if(-not @($rows[[int]$location.evidence_row]|Where-Object {$_ -match $pattern}).Count){
            throw 'CAUSE_V9_LOCATION_EVIDENCE: location label absent from its declared evidence row'
        }
        $labels[$label]=$true
    }
    $linked=@{}
    foreach($index in $order){
        Assert-CauseV9Index $index $causal.Count
        if($linked.ContainsKey([int]$index)){throw 'CAUSE_V9_CAUSAL_DUPLICATE: each causal item can occur once'}
        if($states[$index] -cne 'supported'){throw 'CAUSE_V9_CAUSAL_STATE: only source-supported causal items can be connected'}
        $linked[[int]$index]=$true
    }
}

function Get-ProposalCauseV9Layout($Stage){
    Assert-ProposalCauseV9Visuals $Stage
    if($Stage.visuals.kind -ceq 'water_cooled_plant'){
        . (Join-Path $PSScriptRoot 'Proposal.CoolingCause.ps1')
        return @(Get-ProposalCoolingCauseLayout $Stage)
    }
    $panels=@($Stage.panels)
    $scene=New-ProposalV7Scene $Stage
    $color=$scene.theme
    $markers=@('A','B','C')
    $rows=@($panels[1].table.rows)
    $locations=@($Stage.visuals.locations)
    $order=@($Stage.visuals.causal_order)
    $rest=@(0..(@($panels[2].lines).Count-1)|Where-Object {$_ -notin $order})

    function Add-CauseV9Panel($Id,$X,$Y,$W,$H,$Title,$Accent){
        Add-PV7Box $scene $Id 'canvas' $X $Y $W $H $color.white $color.edge 'roundrect'
        Add-PV7Section $scene ($Id+'-heading') $Id ($X+11) ($Y+8) ($W-22) $Title $Accent
    }
    function Add-CauseV9Badge($Id,$Parent,$X,$Y,$Label,$Fill,$TextColor){
        Add-PV7Box $scene $Id $Parent $X $Y 17 17 $Fill '' 'roundrect'
        Add-PV7Text $scene ($Id+'-label') $Id $X ($Y+.5) 17 16 $Label 11.5 $TextColor $true 'center' 'label'
    }
    Add-CauseV9Panel 'cause-system' 20 98 425 222 $panels[0].title $color.navy
    Add-PV7Text $scene 'cause-location-caption' 'cause-system' 31 130 402 18 '관찰 위치 · 오른쪽 근거와 같은 표지' 11 $color.muted $false 'left' 'detail'
    $locationWidth=(403-7*($locations.Count-1))/$locations.Count
    for($i=0;$i -lt $locations.Count;$i++){
        $x=31+$i*($locationWidth+7)
        $id='cause-location-card-'+$i
        Add-PV7Box $scene $id 'cause-system' $x 151 $locationWidth 43 '#E8F3F8' '' 'roundrect'
        Add-CauseV9Badge ('cause-location-mark-'+$i) $id ($x+8) 164 $markers[$i] $color.blue $color.white
        Add-PV7Text $scene ('cause-location-label-'+$i) $id ($x+31) 157 ($locationWidth-39) 32 $locations[$i].label 11.5 $color.navy $true 'left' 'label'
    }
    $system=@($panels[0].lines)
    $columns=if($system.Count -le 2){1}else{2}
    $systemWidth=(403-8*($columns-1))/$columns
    for($i=0;$i -lt $system.Count;$i++){
        $x=31+($i%$columns)*($systemWidth+8)
        $y=207+[math]::Floor($i/$columns)*51
        $id='cause-system-item-'+$i
        Add-PV7Box $scene $id 'cause-system' $x $y $systemWidth 43 $color.light
        Add-PV7Box $scene ($id+'-mark') $id ($x+8) ($y+8) 3 15 $color.blue
        Add-PV7Text $scene ($id+'-line') $id ($x+17) ($y+5) ($systemWidth-24) 33 $system[$i]
    }

    Add-CauseV9Panel 'cause-evidence' 459 98 481 222 $panels[1].title $color.navy
    Add-PV7Box $scene 'cause-evidence-header' 'cause-evidence' 470 130 459 22 $color.navy
    Add-PV7Text $scene 'cause-evidence-header-0' 'cause-evidence-header' 479 132 126 18 $panels[1].table.headers[0] 11.5 $color.white $true
    Add-PV7Text $scene 'cause-evidence-header-1' 'cause-evidence-header' 617 132 228 18 $panels[1].table.headers[1] 11.5 $color.white $true
    Add-PV7Text $scene 'cause-evidence-header-reference' 'cause-evidence-header' 856 132 67 18 '표지' 11.5 $color.white $true 'center' 'label'
    $rowHeight=158/$rows.Count
    for($i=0;$i -lt $rows.Count;$i++){
        $y=152+$i*$rowHeight
        $id='cause-evidence-row-'+$i
        $fill=if($i%2 -eq 0){$color.light}else{$color.white}
        Add-PV7Box $scene $id 'cause-evidence' 470 $y 459 $rowHeight $fill
        Add-PV7Text $scene ($id+'-key') $id 479 ($y+1) 126 ($rowHeight-2) $rows[$i][0] 11.5 $color.navy $true
        Add-PV7Text $scene ($id+'-detail') $id 617 ($y+1) 228 ($rowHeight-2) $rows[$i][1]
        $position=0
        for($j=0;$j -lt $locations.Count;$j++){
            if($locations[$j].evidence_row -ne $i){continue}
            Add-CauseV9Badge ('cause-evidence-mark-'+$j) $id (857+$position*22) ($y+($rowHeight-17)/2) $markers[$j] '#D8EAF3' $color.navy
            $position++
        }
    }

    Add-CauseV9Panel 'cause-sequence' 20 334 588 139 $panels[2].title $color.red
    $nodeHeight=if($rest.Count){54}else{88}
    $nodeWidth=(566-20*($order.Count-1))/$order.Count
    for($i=0;$i -lt $order.Count;$i++){
        $index=[int]$order[$i]
        $x=31+$i*($nodeWidth+20)
        $id='cause-sequence-node-'+$index
        Add-PV7Box $scene $id 'cause-sequence' $x 367 $nodeWidth $nodeHeight '#FFF2F0' '' 'roundrect'
        Add-CauseV9Badge ('cause-sequence-mark-'+$index) $id ($x+8) 377 ([string]($i+1)) $color.red $color.white
        Add-PV7Text $scene ('cause-sequence-line-'+$index) $id ($x+33) 375 ($nodeWidth-41) ($nodeHeight-14) $panels[2].lines[$index] 11.5 $color.ink $true
        if($i -lt $order.Count-1){
            Add-PV7Line $scene ('cause-link-'+$i) 'cause-sequence' ($x+$nodeWidth+2) (367+$nodeHeight/2) 16 0 $color.red $true 1.25
        }
    }
    $stateLabels=@{supported='근거 있음';hypothesis='가설';boundary='적용 범위';unknown='미확인'}
    if($rest.Count){
        $remainingWidth=(566-8*($rest.Count-1))/$rest.Count
        for($i=0;$i -lt $rest.Count;$i++){
            $index=$rest[$i]
            $x=31+$i*($remainingWidth+8)
            $id='cause-other-'+$index
            $state=$panels[2].line_states[$index]
            $fill=if($state -ceq 'hypothesis'){$color.sand}else{$color.light}
            Add-PV7Box $scene $id 'cause-sequence' $x 430 $remainingWidth 34 $fill
            Add-PV7Text $scene ('cause-other-state-'+$index) $id ($x+8) 432 61 30 $stateLabels[$state] 11.5 $color.muted $true 'left' 'label'
            Add-PV7Text $scene ('cause-other-line-'+$index) $id ($x+72) 432 ($remainingWidth-81) 30 $panels[2].lines[$index]
        }
    }

    Add-CauseV9Panel 'cause-boundary' 622 334 318 139 $panels[3].title $color.amber
    $limits=@($panels[3].lines)
    for($i=0;$i -lt $limits.Count;$i++){
        $y=367+$i*33
        $id='cause-boundary-'+$i
        Add-PV7Box $scene $id 'cause-boundary' 633 $y 296 31 $color.sand
        Add-PV7Text $scene ($id+'-line') $id 642 ($y+1) 278 29 $limits[$i]
    }
    $specs=@(Complete-ProposalV7Scene $scene $Stage)
    foreach($shape in $specs){$shape.layout_revision='proposal-reference-r9'}
    return $specs
}
