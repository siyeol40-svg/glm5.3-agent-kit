# Fixed 3-by-2 wide action cards. Pure editable native specifications only.
# The source identities, eighteen action statements and six outcomes are preserved.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')

function Get-ProposalActionsGridV8Layout($Stage) {
    if([string]$Stage.id -cne 'actions' -or [string]$Stage.layout_profile -cne 'reference-v8-actions'){
        throw 'ACTIONS_V8_UNSUPPORTED: only the registered actions profile can use this grid'
    }
    $panels=@($Stage.panels)
    if($panels.Count -ne 6){throw 'ACTIONS_V8_UNSUPPORTED_COUNT: exactly six sourced action cards are required'}
    . (Join-Path $PSScriptRoot 'Proposal.ActionIcons.ps1')
    $null=Assert-ProposalActionIconSemantics $Stage
    foreach($p in $panels){
        if([string]$p.role -cne 'action' -or [string]$p.kind -cne 'bullets'){
            throw 'ACTIONS_V8_UNSUPPORTED_SLOT: each card must use the action/bullets role'
        }
        if(@($p.lines).Count -ne 3){throw 'ACTIONS_V8_UNSUPPORTED_LINES: preserve exactly three action statements per card'}
        if([string]::IsNullOrWhiteSpace([string]$p.title) -or [string]::IsNullOrWhiteSpace([string]$p.outcome) -or [string]::IsNullOrWhiteSpace([string]$p.icon)){
            throw 'ACTIONS_V8_UNSUPPORTED_CONTENT: each card needs its source title, illustration role and outcome'
        }
        if($null -ne $p.line_states){
            if(@($p.line_states).Count -ne 3){throw 'ACTIONS_V8_UNSUPPORTED_STATE: one source state is required for each statement'}
            foreach($state in $p.line_states){if([string]$state -cne 'supported'){throw 'ACTIONS_V8_UNSUPPORTED_STATE: this fixed variant supports sourced statements only'}}
        }
    }
    $scene=New-ProposalV7Scene $Stage
    $c=$scene.theme
    for($i=0;$i -lt 6;$i++){
        $x=20+314*($i%3)
        $y=100+191*[math]::Floor($i/3)
        $w=292.0;$h=179.0
        $id='action-card-'+$i;$p=$panels[$i]

        Add-PV7Box $scene $id 'canvas' $x $y $w $h $c.white $c.edge 'roundrect'
        Add-PV7Box $scene ($id+'-number-disc') $id ($x+12) ($y+12) 22 22 $c.navy '' 'ellipse'
        Add-PV7Text $scene ($id+'-number') ($id+'-number-disc') ($x+12) ($y+14) 22 17 ([string]($i+1)) 11.5 $c.white $true 'center' 'label'
        Add-PV7Text $scene ($id+'-title') $id ($x+42) ($y+8) 174 34 ([string]$p.title) 13 $c.navy $true 'left' 'section'
        Add-PV7Figure $scene ($id+'-figure') $id ([string]$p.icon) ($x+224) ($y+3) 56 41 $c.blue
        Add-PV7Line $scene ($id+'-header-rule') $id ($x+12) ($y+45) 268 0 $c.edge $false .7

        # Wide body slots retain common English noun phrases instead of splitting
        # them down the former six narrow columns. No automatic fit is used.
        for($j=0;$j -lt 3;$j++){
            $bodyY=$y+50+31*$j
            Add-PV7Box $scene ($id+'-marker-'+$j) $id ($x+12) ($bodyY+4) 2 8 $c.blue
            Add-PV7Text $scene ($id+'-line-'+$j) $id ($x+22) $bodyY 258 30 ([string]$p.lines[$j]) 11.5 $c.ink
        }

        Add-PV7Box $scene ($id+'-outcome-band') $id ($x+9) ($y+145) 274 30 $c.mint
        Add-PV7Text $scene ($id+'-outcome') ($id+'-outcome-band') ($x+17) ($y+145) 258 30 ([string]$p.outcome) 12 $c.green $true 'left' 'body'
    }
    $shapes=@(Complete-ProposalV7Scene $scene $Stage)
    foreach($shape in $shapes){$shape.layout_revision='proposal-reference-r8'}
    return $shapes
}
