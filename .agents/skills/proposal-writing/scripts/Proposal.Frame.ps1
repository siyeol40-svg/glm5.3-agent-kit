# Shared visual frame for the supported V5 problem / V6 actions dispatch only.
# Native specifications remain pure; no Office, files, images, models or network IO.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')

function Get-ProposalDesign98FrameLayout($Stage,$Shapes) {
    $isProblem=$Stage.id -ceq 'problem' -and $Stage.layout_profile -ceq 'reference-v5-problem'
    $isActions=$Stage.id -ceq 'actions' -and $Stage.layout_profile -ceq 'reference-v6'
    if(-not $isProblem -and -not $isActions){throw 'FRAME_UNSUPPORTED: only V5 problem and V6 actions are registered'}
    $revision=if($isProblem){'proposal-reference-r5'}else{'proposal-reference-r6'}
    $frameIds=@('canvas','page-band','page-number','section-name','header-divider','page-title','page-subtitle','header-rule','page-citation','footer-band','page-takeaway')
    $existing=@{}
    foreach($shape in @($Shapes)){
        if([string]::IsNullOrWhiteSpace([string]$shape.id) -or $existing.ContainsKey([string]$shape.id)){throw 'FRAME_DUPLICATE_SHAPE: native IDs must be nonempty and unique'}
        if($shape.layout_revision -cne $revision){throw 'FRAME_REVISION_MISMATCH: preserve the registered native stage revision'}
        $existing[[string]$shape.id]=$shape
    }
    foreach($id in $frameIds){if(-not $existing.ContainsKey($id)){throw ('FRAME_MISSING_SHAPE: '+$id)}}

    # These eleven fixed frame slots match Proposal.V7.Common.ps1. Business body
    # shapes are reused without changing their values, position, style or order.
    $t=@{navy='#0D2A46';muted='#5D7084';edge='#D7E1E9';white='#FFFFFF';ink='#203349'}
    $scene=[pscustomobject]@{shapes=[Collections.Generic.List[object]]::new();theme=$t;stage=$Stage}
    $number=if($isProblem){'02'}else{'04'};$label=if($isProblem){'문제 현상'}else{'개선 사항'}
    Add-PV7Box $scene 'canvas' '' 0 0 960 540 $t.white
    Add-PV7Box $scene 'page-band' 'canvas' 20 14 44 42 $t.navy '' 'roundrect'
    Add-PV7Text $scene 'page-number' 'page-band' 23 18 38 32 $number 24 $t.white $true 'center' 'title'
    Add-PV7Text $scene 'section-name' 'canvas' 79 14 132 28 $label 18 $t.navy $true 'left' 'section'
    Add-PV7Line $scene 'header-divider' 'canvas' 210 20 0 22 $t.edge $false .8
    Add-PV7Text $scene 'page-title' 'canvas' 225 12 715 32 $Stage.title 23 $t.navy $true 'left' 'title'
    Add-PV7Text $scene 'page-subtitle' 'canvas' 79 49 861 20 $Stage.subtitle 11.5 $t.muted
    Add-PV7Line $scene 'header-rule' 'canvas' 20 78 920 0 $t.edge $false .8
    Add-PV7Text $scene 'page-citation' 'canvas' 20 481 920 16 $Stage.citation 10 $t.muted $false 'left' 'source'
    Add-PV7Box $scene 'footer-band' 'canvas' 20 507 920 26 $t.navy
    Add-PV7Text $scene 'page-takeaway' 'footer-band' 31 511 898 18 $Stage.takeaway 12.5 $t.white $true 'left' 'conclusion'
    $replacement=@{}
    foreach($shape in $scene.shapes){$shape.layout_revision=$revision;$replacement[[string]$shape.id]=$shape}
    $result=[Collections.Generic.List[object]]::new()
    foreach($shape in @($Shapes)){if($replacement.ContainsKey([string]$shape.id)){$result.Add($replacement[[string]$shape.id])}else{$result.Add($shape)}}
    return $result.ToArray()
}
