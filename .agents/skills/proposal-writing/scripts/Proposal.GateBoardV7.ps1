# Fixed editable Gateboard for a proposed rollout. Pure native specs; no Office or media I/O.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')

function Get-ProposalGateBoardV7Layout($Stage) {
    $panels=@($Stage.panels)
    if([string]$Stage.id -cne 'rollout' -or [string]$Stage.layout_profile -cne 'reference-v7' -or [string]$Stage.scope -cne 'proposal'){
        throw 'GATE_BOARD_UNSUPPORTED: reference-v7 rollout with proposal scope is required'
    }
    if($panels.Count -ne 4){throw 'GATE_BOARD_UNSUPPORTED: four fixed business panels are required'}
    $roles=@('coverage','expansion','checks','acceptance');$kinds=@('table','flow','bullets','bullets')
    for($i=0;$i -lt 4;$i++){
        if([string]$panels[$i].role -cne $roles[$i] -or [string]$panels[$i].kind -cne $kinds[$i]){throw 'GATE_BOARD_UNSUPPORTED: fixed coverage/expansion/checks/acceptance roles and kinds are required'}
    }
    $targets=@($panels[0].table.rows);$headers=@($panels[0].table.headers);$steps=@($panels[1].steps)
    if($targets.Count -ne 5 -or $headers.Count -ne 2){throw 'GATE_BOARD_UNSUPPORTED: five targets with two table columns are required'}
    foreach($row in $targets){if(@($row).Count -ne 2){throw 'GATE_BOARD_UNSUPPORTED: every target requires its investigation scope'}}
    if($steps.Count -ne 4 -or @($panels[2].lines).Count -ne 6 -or @($panels[3].lines).Count -ne 6){throw 'GATE_BOARD_UNSUPPORTED: four activities, six checks and six acceptance criteria are required'}
    $visual=$Stage.visuals
    if($null -eq $visual -or [string]$visual.kind -cne 'gate_board'){throw 'GATE_BOARD_UNSUPPORTED: explicit gate_board visual mapping is required'}
    foreach($property in @($visual.PSObject.Properties.Name)){
        if($property -cnotin @('kind','check_gates','acceptance_gates')){throw ('GATE_BOARD_UNSUPPORTED: unknown visual field '+$property)}
    }
    foreach($mappingName in @('check_gates','acceptance_gates')){
        $mapping=@($visual.$mappingName)
        if($mapping.Count -ne 6){throw ('GATE_BOARD_UNSUPPORTED: six '+$mappingName+' assignments are required')}
        foreach($gate in $mapping){
            if($null -eq $gate -or $gate -is [string] -or $gate -is [bool] -or $gate -isnot [ValueType]){throw 'GATE_BOARD_UNSUPPORTED: each Gate index must be an integer from zero to three'}
            $number=[double]$gate
            if([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0 -or $number -gt 3 -or [math]::Truncate($number) -ne $number){throw 'GATE_BOARD_UNSUPPORTED: each Gate index must be an integer from zero to three'}
        }
    }
    $scene=New-ProposalV7Scene $Stage;$c=$scene.theme

    # Colors identify proposed management stages, never completion or readiness.
    $phaseColors=@($c.navy,$c.blue,$c.amber,$c.green)
    Add-PV7Text $scene 'gate-flow-title' 'canvas' 28 96 497 20 $panels[1].title 13 $c.navy $true 'left' 'section'
    Add-PV7Text $scene 'gate-phase-legend' 'canvas' 553 97 379 18 'Gate 번호와 색은 검토 단계 구분' 11.5 $c.muted $false 'right' 'label'
    $gateWidth=218.5;$gateGap=10.0
    for($i=0;$i -lt 4;$i++){
        $x=28+$i*($gateWidth+$gateGap);$id='gate-stage-'+$i
        Add-PV7Box $scene $id 'canvas' $x 123 $gateWidth 66 $c.light
        Add-PV7Box $scene ($id+'-number-disc') $id ($x+12) 132 23 23 $phaseColors[$i] '' 'ellipse'
        Add-PV7Text $scene ($id+'-number') ($id+'-number-disc') ($x+12) 135 23 17 ([string]($i+1)) 11.5 $c.white $true 'center' 'label'
        Add-PV7Text $scene ($id+'-label') $id ($x+43) 134 ($gateWidth-55) 18 'GATE' 11.5 $phaseColors[$i] $true 'left' 'label'
        Add-PV7Text $scene ($id+'-activity') $id ($x+12) 159 ($gateWidth-24) 20 $steps[$i] 11.5 $c.ink $true
        Add-PV7Line $scene ($id+'-baseline') $id ($x+12) 185 ($gateWidth-24) 0 $phaseColors[$i] $false 1.2
        if($i -lt 3){Add-PV7Line $scene ('gate-flow-arrow-'+$i) 'canvas' ($x+$gateWidth) 151 $gateGap 0 $c.muted $true 1.2}
    }

    # The target table stays adjacent to the criteria, rather than turning five targets into new claims.
    Add-PV7Text $scene 'gate-coverage-title' 'canvas' 28 202 309 20 $panels[0].title 13 $c.navy $true 'left' 'section'
    Add-PV7Box $scene 'gate-coverage' 'canvas' 28 230 309 235 $c.white
    Add-PV7Box $scene 'gate-coverage-header' 'gate-coverage' 28 230 309 25 $c.navy
    Add-PV7Text $scene 'gate-coverage-header-0' 'gate-coverage-header' 36 235 93 17 $headers[0] 11.5 $c.white $true
    Add-PV7Text $scene 'gate-coverage-header-1' 'gate-coverage-header' 140 235 189 17 $headers[1] 11.5 $c.white $true
    for($r=0;$r -lt 5;$r++){
        $y=255+42*$r;$id='gate-target-'+$r;$fill=if($r%2 -eq 0){$c.light}else{$c.white}
        Add-PV7Box $scene $id 'gate-coverage' 28 $y 309 42 $fill
        Add-PV7Text $scene ($id+'-label') $id 36 ($y+5) 93 32 $targets[$r][0] 11.5 $c.navy $true
        Add-PV7Text $scene ($id+'-scope') $id 140 ($y+5) 189 32 $targets[$r][1] 11.5 $c.ink
        if($r -lt 4){Add-PV7Line $scene ($id+'-rule') 'gate-coverage' 28 ($y+42) 309 0 $c.edge $false .7}
    }

    # A shared Gate heading replaces repeated numbers for a uniform six-row mapping.
    # Mixed mappings retain business order and carry explicit G1/G2/G3/G4 references.
    # Per-row metadata remains available in either native representation.
    $columns=@(
        @{panel=2;name='check';x=355.0;w=278.0;mapping=@($visual.check_gates)},
        @{panel=3;name='acceptance';x=648.0;w=284.0;mapping=@($visual.acceptance_gates)}
    )
    foreach($column in $columns){
        $p=$panels[$column.panel];$root='gate-'+$column.name+'-criteria'
        Add-PV7Text $scene ($root+'-title') 'canvas' $column.x 202 $column.w 20 $p.title 13 $c.navy $true 'left' 'section'
        Add-PV7Box $scene $root 'canvas' $column.x 230 $column.w 236 $c.white
        $assigned=@($column.mapping|Select-Object -Unique);$uniform=$assigned.Count -eq 1
        $relation=if($column.panel -eq 2){'기술 확인'}else{'도입 판단'}
        $groupColor=if($uniform){$phaseColors[[int]$assigned[0]]}else{$c.blue}
        $groupLabel=if($uniform){'GATE '+[string]([int]$assigned[0]+1)+' · '+$relation}else{'GATE별 '+$relation}
        Add-PV7Box $scene ($root+'-relation') $root $column.x 230 $column.w 24 $c.light
        Add-PV7Box $scene ($root+'-relation-accent') ($root+'-relation') $column.x 230 3 24 $groupColor
        Add-PV7Text $scene ($root+'-relation-label') $root ($column.x+10) 235 ($column.w-20) 17 $groupLabel 11.5 $groupColor $true 'left' 'label'
        if($uniform){$scene.shapes[$scene.shapes.Count-1].PSObject.Properties.Add([Management.Automation.PSNoteProperty]::new('gate_index',[int]$assigned[0]))}
        $phaseTints=@('#EEF2F6','#EBF4FA',$c.sand,$c.mint)
        for($r=0;$r -lt 6;$r++){
            $y=256+35*$r;$id='gate-'+$column.name+'-'+$r;$gate=[int]$column.mapping[$r];$start=$scene.shapes.Count
            $rowFill=if($uniform){$c.white}else{$phaseTints[$gate]}
            Add-PV7Box $scene $id $root $column.x $y $column.w 35 $rowFill
            if($uniform){
                Add-PV7Box $scene ($id+'-marker') $id ($column.x+7) ($y+10) 3 12 $phaseColors[$gate]
                Add-PV7Text $scene ($id+'-text') $id ($column.x+18) ($y+2) ($column.w-25) 31 $p.lines[$r] 11.5 $c.ink
            }else{
                Add-PV7Text $scene ($id+'-number') $id ($column.x+5) ($y+8) 28 17 ('G'+[string]($gate+1)) 11.5 $phaseColors[$gate] $true 'left' 'label'
                Add-PV7Text $scene ($id+'-text') $id ($column.x+36) ($y+2) ($column.w-43) 31 $p.lines[$r] 11.5 $c.ink
            }
            if($r -lt 5){Add-PV7Line $scene ($id+'-rule') $root ($column.x+7) ($y+35) ($column.w-14) 0 $c.edge $false .6}
            for($j=$start;$j -lt $scene.shapes.Count;$j++){
                $native=$scene.shapes[$j]
                $native.PSObject.Properties.Add([Management.Automation.PSNoteProperty]::new('gate_index',$gate))
                $native.PSObject.Properties.Add([Management.Automation.PSNoteProperty]::new('gate_item_index',$r))
                $native.PSObject.Properties.Add([Management.Automation.PSNoteProperty]::new('gate_panel_role',[string]$p.role))
            }
        }
    }
    return Complete-ProposalV7Scene $scene $Stage
}
