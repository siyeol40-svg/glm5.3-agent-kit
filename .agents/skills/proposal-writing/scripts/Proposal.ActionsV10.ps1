# Fixed two-group action page. All illustrations and business text remain editable.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')
. (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')

function Assert-ProposalActionsV10Visuals($Stage) {
    if($Stage.id -cne 'actions' -or $Stage.layout_profile -cne 'reference-v10-actions'){
        throw 'V10_ACTIONS_PROFILE: use this profile only for actions'
    }
    $v=$Stage.visuals
    if($null -eq $v -or ($v -isnot [pscustomobject] -and $v -isnot [Collections.IDictionary])){
        throw 'V10_ACTIONS_GROUP: visuals must be an object'
    }
    $keys=if($v -is [Collections.IDictionary]){@($v.Keys)}else{@($v.PSObject.Properties.Name)}
    if($keys.Count -ne 2 -or 'kind' -cnotin $keys -or 'group_titles' -cnotin $keys -or $v.kind -isnot [string] -or $v.kind -cne 'grouped_actions'){
        throw 'V10_ACTIONS_GROUP: only grouped_actions and group_titles are supported'
    }
    if($v.group_titles -isnot [array] -or $v.group_titles.Count -ne 2){
        throw 'V10_ACTIONS_GROUP: exactly two group titles are required'
    }
    foreach($label in $v.group_titles){
        if($label -isnot [string] -or [string]::IsNullOrWhiteSpace($label) -or $label -match '[\p{N}\p{C}\[\]]' -or (Measure-PV7Text $label 14) -gt 400){
            throw 'V10_ACTIONS_GROUP: each group needs a short single-line name without quantities'
        }
    }
    $first=$v.group_titles[0].Normalize([Text.NormalizationForm]::FormKC) -replace '[\s\p{P}]',''
    $second=$v.group_titles[1].Normalize([Text.NormalizationForm]::FormKC) -replace '[\s\p{P}]',''
    if(-not $first -or -not $second -or $first -ieq $second){
        throw 'V10_ACTIONS_GROUP: group names must be distinct'
    }
}

function Get-ProposalActionsV10Layout($Stage) {
    Assert-ProposalActionsV10Visuals $Stage
    $panels=@($Stage.panels)
    $v8=[pscustomobject]@{id=$Stage.id;layout_profile='reference-v8-actions';panels=$panels}
    $null=Assert-ProposalActionsV8Stage $v8
    foreach($panel in $panels){
        if($panel.role -cne 'action' -or $panel.kind -cne 'bullets' -or [string]::IsNullOrWhiteSpace($panel.outcome)){
            throw 'V10_ACTIONS_CONTENT: each action needs its business statements and outcome'
        }
        if($null -ne $panel.line_states -and ($panel.line_states.Count -ne 3 -or @($panel.line_states|Where-Object {$_ -cne 'supported'}).Count)){
            throw 'V10_ACTIONS_CONTENT: action statements must be supported'
        }
    }
    $scene=New-ProposalV7Scene $Stage
    $c=$scene.theme

    function Add-PAV10Figure([string]$Id,[string]$Parent,$Panel,[double]$X,[double]$Y,[string]$Accent) {
        # Keep the V8 title/icon contract. These two exact title topics choose
        # different equipment silhouettes within the same validated icon family.
        if($Panel.icon -ceq 'heat_exchanger' -and $Panel.title -match '(?i)(?<![A-Za-z])Cooling\s+Tower(?![A-Za-z])|냉각탑'){
            Add-PV7Box $scene ($Id+'-tower-body') $Parent ($X+9) ($Y+8) 35 20 $c.light $Accent 'roundrect'
            Add-PV7Box $scene ($Id+'-tower-roof') $Parent ($X+7) ($Y+6) 39 4 $Accent
            Add-PV7Box $scene ($Id+'-tower-fan') $Parent ($X+20) ($Y+1) 14 7 $c.white $Accent 'ellipse'
            foreach($i in 0..3){Add-PV7Line $scene ($Id+'-tower-grille-'+$i) $Parent ($X+14) ($Y+13+$i*3) 25 0 $Accent}
            Add-PV7Box $scene ($Id+'-tower-basin') $Parent ($X+8) ($Y+28) 37 3 $Accent
            return
        }
        if($Panel.icon -ceq 'water' -and $Panel.title -match '(?i)(?<![A-Za-z])Water\s+Pump(?![A-Za-z])|냉수\s*펌프'){
            Add-PV7Box $scene ($Id+'-pump-outlet') $Parent ($X+30) ($Y+4) 16 5 $Accent
            Add-PV7Box $scene ($Id+'-pump-inlet') $Parent ($X+3) ($Y+14) 14 5 $Accent
            Add-PV7Box $scene ($Id+'-pump-body') $Parent ($X+14) ($Y+4) 24 24 $c.light $Accent 'ellipse'
            Add-PV7Box $scene ($Id+'-pump-hub') $Parent ($X+22) ($Y+12) 8 8 $c.white $Accent 'ellipse'
            Add-PV7Box $scene ($Id+'-pump-base') $Parent ($X+13) ($Y+29) 28 3 $Accent
            return
        }
        Add-PV7Figure $scene $Id $Parent ([string]$Panel.icon) $X $Y 52 34 $Accent
    }

    for($g=0;$g -lt 2;$g++){
        $group='action-group-'+$g
        $groupY=89+191*$g
        $accent=if($g -eq 0){$c.navy}else{'#176358'}
        $surface=if($g -eq 0){'#EEF4FA'}else{'#EEF7F4'}
        Add-PV7Spec $scene $group 'panel' 'canvas' 'shape' 20 $groupY 920 185 '' 11.5 $c.ink $surface $c.edge $false 'roundrect'
        Add-PV7Box $scene ($group+'-header') $group 20 $groupY 920 23 $accent
        Add-PV7Text $scene ($group+'-title') ($group+'-header') 33 ($groupY+2) 884 19 $Stage.visuals.group_titles[$g] 14 $c.white $true 'left' 'section'

        for($column=0;$column -lt 3;$column++){
            $i=3*$g+$column
            $p=$panels[$i]
            $id='action-card-'+$i
            $x=28+306*$column
            $y=$groupY+26
            Add-PV7Spec $scene $id 'card' $group 'shape' $x $y 292 156 '' 11.5 $c.ink $c.white $c.edge $false 'roundrect'
            Add-PV7Text $scene ($id+'-title') $id ($x+12) ($y+3) 214 33 $p.title 13 $accent $true 'left' 'section'
            Add-PAV10Figure ($id+'-figure') $id $p ($x+230) ($y+2) $accent
            Add-PV7Line $scene ($id+'-rule') $id ($x+12) ($y+37) 268 0 $c.edge
            for($j=0;$j -lt 3;$j++){
                $bodyY=$y+39+29*$j
                Add-PV7Box $scene ($id+'-mark-'+$j) $id ($x+12) ($bodyY+5) 2 7 $accent
                Add-PV7Text $scene ($id+'-line-'+$j) $id ($x+22) $bodyY 258 29 $p.lines[$j]
            }
            Add-PV7Box $scene ($id+'-outcome-band') $id ($x+9) ($y+126) 274 29 $surface
            Add-PV7Text $scene ($id+'-outcome') ($id+'-outcome-band') ($x+17) ($y+126) 258 29 $p.outcome 11.5 $accent $true
        }
    }
    $shapes=@(Complete-ProposalV7Scene $scene $Stage)
    foreach($shape in $shapes){$shape.layout_revision='proposal-reference-r10'}
    return $shapes
}