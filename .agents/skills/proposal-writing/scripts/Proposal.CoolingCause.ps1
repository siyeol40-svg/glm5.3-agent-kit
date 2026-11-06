# General water-cooled plant schematic. Fixed semantic geometry, not a customer piping drawing.
function Get-ProposalCoolingCauseLayout($Stage){
    $scene=New-ProposalV7Scene $Stage
    $color=$scene.theme
    $panels=@($Stage.panels)
    $locations=@{}
    foreach($location in $Stage.visuals.locations){$locations[$location.role]=$location}
    $markers=[ordered]@{chiller='A';pump='B';tower='C'}
    $loopBlue='#176EA5'
    $loopWarm='#AC752B'

    function Add-CoolingPanel($Id,$X,$Y,$W,$H,$Title,$Accent){
        Add-PV7Box $scene $Id 'canvas' $X $Y $W $H $color.white $color.edge 'roundrect'
        Add-PV7Section $scene ($Id+'-heading') $Id ($X+11) ($Y+8) ($W-22) $Title $Accent
    }
    function Add-CoolingTag($Id,$Parent,$X,$Y,$Text,$Fill,$Ink){
        Add-PV7Box $scene $Id $Parent $X $Y 17 17 $Fill '' 'roundrect'
        Add-PV7Text $scene ($Id+'-label') $Id $X ($Y+.5) 17 16 $Text 11.5 $Ink $true 'center' 'label'
    }

    Add-CoolingPanel 'cooling-system' 20 98 520 235 $panels[0].title $color.navy
    Add-PV7Text $scene 'cooling-scope' 'cooling-system' 31 127 498 19 '일반 원리 · 현장 배관과 구분' 11 $color.muted $false 'left' 'detail'
    Add-PV7Box $scene 'cooling-loops' 'cooling-system' 31 148 498 103 $color.white $color.edge 'roundrect'
    Add-PV7Box $scene 'cooling-chilled-bg' 'cooling-loops' 32 149 236 101 '#EAF4FB'
    Add-PV7Box $scene 'cooling-condenser-bg' 'cooling-loops' 268 149 260 101 '#FCF6ED'
    Add-PV7Text $scene 'cooling-chilled-title' 'cooling-loops' 39 153 180 18 '냉수 회로 · 냉각 공급' 11.5 $loopBlue $true
    Add-PV7Text $scene 'cooling-condenser-title' 'cooling-loops' 338 153 184 18 '응축수 회로 · 열 배출' 11.5 $loopWarm $true

    Add-PV7Box $scene 'cooling-node-load' 'cooling-loops' 39 177 74 64 $color.white '#B9D5E7' 'roundrect'
    Add-PV7Text $scene 'cooling-node-load-label' 'cooling-node-load' 42 195 68 18 '냉각 부하' 11.5 $color.navy $true 'center'
    Add-PV7Text $scene 'cooling-node-load-detail' 'cooling-node-load' 42 216 68 16 '열 흡수' 11 $loopBlue $false 'center' 'detail'

    Add-PV7Box $scene 'cooling-node-chiller' 'cooling-loops' 226 175 107 68 $color.white '#A9BFD0' 'roundrect'
    Add-CoolingTag 'cooling-node-chiller-tag' 'cooling-node-chiller' 233 181 $markers.chiller $color.navy $color.white
    Add-PV7Text $scene 'cooling-node-chiller-label' 'cooling-node-chiller' 254 179 74 30 $locations.chiller.label 11.5 $color.navy $true
    Add-PV7Line $scene 'cooling-separate-water' 'cooling-node-chiller' 274 209 0 26 $color.edge
    Add-PV7Text $scene 'cooling-chiller-chilled-side' 'cooling-node-chiller' 230 216 40 17 '냉수' 11 $loopBlue $true 'center' 'detail'
    Add-PV7Text $scene 'cooling-chiller-condenser-side' 'cooling-node-chiller' 277 216 53 17 '응축수' 11 $loopWarm $true 'center' 'detail'

    Add-PV7Box $scene 'cooling-node-tower' 'cooling-loops' 415 177 107 64 $color.white '#DFC394' 'roundrect'
    Add-CoolingTag 'cooling-node-tower-tag' 'cooling-node-tower' 422 182 $markers.tower $loopWarm $color.white
    Add-PV7Text $scene 'cooling-node-tower-detail' 'cooling-node-tower' 444 184 72 16 '열 방출' 11 $loopWarm $false 'left' 'detail'
    Add-PV7Text $scene 'cooling-node-tower-label' 'cooling-node-tower' 419 209 99 26 $locations.tower.label 11.5 $color.navy $true 'center'

    # Two separately colored supply/return pairs terminate at the corresponding side of the chiller.
    # Pump labels denote each circuit's function, without placing pumps on a particular pipe.
    Add-PV7Box $scene 'cooling-chilled-supply' 'cooling-loops' 114 183 111 10 $loopBlue '' 'leftArrow'
    Add-PV7Box $scene 'cooling-chilled-return' 'cooling-loops' 114 225 111 10 $loopBlue '' 'rightArrow'
    Add-PV7Box $scene 'cooling-condenser-hot' 'cooling-loops' 334 183 80 10 $loopWarm '' 'rightArrow'
    Add-PV7Box $scene 'cooling-condenser-cool' 'cooling-loops' 334 225 80 10 $loopWarm '' 'leftArrow'
    Add-CoolingTag 'cooling-node-pump-tag' 'cooling-loops' 117 201 $markers.pump $loopBlue $color.white
    Add-PV7Text $scene 'cooling-node-pump-label' 'cooling-loops' 137 201 87 20 $locations.pump.label 11.5 $color.navy $true
    Add-CoolingTag 'cooling-node-pump-secondary-tag' 'cooling-loops' 336 201 $markers.pump $loopWarm $color.white
    Add-PV7Text $scene 'cooling-node-pump-secondary-label' 'cooling-loops' 357 201 55 20 'Pump' 11.5 $loopWarm $true 'center'

    $system=@($panels[0].lines)
    $columns=if($system.Count -le 2){1}else{2}
    $factWidth=(498-8*($columns-1))/$columns
    for($i=0;$i -lt $system.Count;$i++){
        $x=31+($i%$columns)*($factWidth+8)
        $y=256+[math]::Floor($i/$columns)*34
        $id='cooling-system-fact-'+$i
        Add-PV7Box $scene $id 'cooling-system' $x $y $factWidth 31 $color.light
        Add-PV7Box $scene ($id+'-mark') $id ($x+7) ($y+6) 2 13 $color.blue
        Add-PV7Text $scene ($id+'-line') $id ($x+13) ($y+1) ($factWidth-18) 29 $system[$i]
    }

    Add-CoolingPanel 'cooling-evidence' 552 98 388 235 $panels[1].title $color.navy
    Add-PV7Box $scene 'cooling-evidence-header' 'cooling-evidence' 563 130 366 23 $color.navy
    Add-PV7Text $scene 'cooling-evidence-header-0' 'cooling-evidence-header' 570 133 100 18 $panels[1].table.headers[0] 11.5 $color.white $true
    Add-PV7Text $scene 'cooling-evidence-header-1' 'cooling-evidence-header' 676 133 216 18 $panels[1].table.headers[1] 11.5 $color.white $true
    Add-PV7Text $scene 'cooling-evidence-header-key' 'cooling-evidence-header' 899 133 26 18 '표지' 11.5 $color.white $true 'center'
    $rows=@($panels[1].table.rows)
    $rowHeight=168/$rows.Count
    for($i=0;$i -lt $rows.Count;$i++){
        $y=153+$i*$rowHeight
        $id='cooling-evidence-row-'+$i
        $fill=if($i%2 -eq 0){$color.light}else{$color.white}
        Add-PV7Box $scene $id 'cooling-evidence' 563 $y 366 $rowHeight $fill
        Add-PV7Text $scene ($id+'-key') $id 570 ($y+2) 100 ($rowHeight-3) $rows[$i][0] 11.5 $color.navy $true
        Add-PV7Text $scene ($id+'-detail') $id 676 ($y+2) 216 ($rowHeight-3) $rows[$i][1]
        foreach($role in $markers.Keys){
            if($locations[$role].evidence_row -eq $i){
                Add-CoolingTag ('cooling-evidence-'+$role) $id 903 ($y+($rowHeight-17)/2) $markers[$role] '#D8EAF3' $color.navy
            }
        }
    }

    Add-CoolingPanel 'cooling-sequence' 20 345 588 129 $panels[2].title $color.blue
    $order=@($Stage.visuals.causal_order)
    $rest=@(0..(@($panels[2].lines).Count-1)|Where-Object {$_ -notin $order})
    $nodeHeight=if($rest.Count){55}else{74}
    $nodeWidth=(566-20*($order.Count-1))/$order.Count
    for($i=0;$i -lt $order.Count;$i++){
        $index=[int]$order[$i]
        $x=31+$i*($nodeWidth+20)
        $y=379
        $id='cooling-sequence-node-'+$index
        Add-PV7Box $scene $id 'cooling-sequence' $x $y $nodeWidth $nodeHeight '#EAF4FB' '' 'roundrect'
        $labelY=$y+($nodeHeight-43)/2
        Add-CoolingTag ('cooling-sequence-mark-'+$index) $id ($x+8) ($labelY+2) ([string]($i+1)) $color.blue $color.white
        Add-PV7Text $scene ('cooling-sequence-line-'+$index) $id ($x+33) $labelY ($nodeWidth-41) 43 $panels[2].lines[$index] 11.5 $color.ink $true
        if($i -lt $order.Count-1){
            Add-PV7Line $scene ('cooling-sequence-link-'+$i) 'cooling-sequence' ($x+$nodeWidth+2) ($y+$nodeHeight/2) 16 0 $color.blue $true 1.25
        }
    }
    $stateLabels=@{supported='근거 있음';hypothesis='가설';boundary='적용 범위';unknown='미확인'}
    if($rest.Count){
        $restWidth=(566-8*($rest.Count-1))/$rest.Count
        for($i=0;$i -lt $rest.Count;$i++){
            $index=$rest[$i]
            $x=31+$i*($restWidth+8)
            $id='cooling-other-'+$index
            $state=$panels[2].line_states[$index]
            $fill=if($state -ceq 'hypothesis'){$color.sand}else{$color.light}
            Add-PV7Box $scene $id 'cooling-sequence' $x 438 $restWidth 30 $fill
            Add-PV7Text $scene ($id+'-state') $id ($x+8) 439 61 28 $stateLabels[$state] 11.5 $color.muted $true 'left' 'label'
            Add-PV7Text $scene ($id+'-line') $id ($x+72) 439 ($restWidth-81) 29 $panels[2].lines[$index]
        }
    }

    Add-CoolingPanel 'cooling-boundary' 622 345 318 129 $panels[3].title $color.amber
    $limits=@($panels[3].lines)
    for($i=0;$i -lt $limits.Count;$i++){
        $y=378+$i*29
        $id='cooling-boundary-'+$i
        Add-PV7Box $scene $id 'cooling-boundary' 633 $y 296 28 $color.sand
        Add-PV7Text $scene ($id+'-line') $id 641 $y 280 28 $limits[$i]
    }
    $specs=@(Complete-ProposalV7Scene $scene $Stage)
    foreach($shape in $specs){$shape.layout_revision='proposal-reference-r9'}
    return $specs
}
