# Pure contract and ledger resolution for one compound problem page. No Office or media IO.
function Assert-ProposalV5Object($Value,[string[]]$Keys,[string]$Where){
    if($null -eq $Value -or ($Value -isnot [pscustomobject] -and $Value -isnot [Collections.IDictionary])){throw ('needs_input: '+$Where+' object missing')}
    Assert-ProposalAllowedProperties $Value $Keys $Where
}
function Assert-ProposalV5Text($Value,[string]$Where){
    if($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)){throw ('needs_input: nonblank string missing: '+$Where)}
    if($Value.Length -gt 400){throw ('Unsupported text length above 400 limit: '+$Where)}
}
function Assert-ProposalV5Array($Value,[int]$Min,[int]$Max,[string]$Where){
    if($Value -isnot [array] -or $Value.Count -lt $Min -or $Value.Count -gt $Max){throw ('needs_input: '+$Where+' array count requires '+$Min+' to '+$Max)}
}
function Assert-ProposalV5TextItems($Value,[int]$Min,[int]$Max,[string]$Where){
    Assert-ProposalV5Array $Value $Min $Max $Where
    foreach($item in $Value){Assert-ProposalV5Text $item $Where}
}
function Assert-ProposalV5Refs($Ids,[string]$Where){
    Assert-ProposalV5Array $Ids 1 100 ($Where+'.source_ids')
    foreach($id in $Ids){if($id -isnot [string] -or [string]::IsNullOrWhiteSpace($id)){throw ('needs_input: invalid source_ids in '+$Where)}}
}
function Assert-ProposalV5Picture($Asset,[string]$Where='problem.evidence.asset'){
    Assert-ProposalV5Object $Asset @('document_name','slide_index','shape_name','description','reference_kind','known_visible_aspect_ratio','origin') $Where
    foreach($key in @('document_name','shape_name','description')){Assert-ProposalV5Text $Asset.$key ('asset.'+$key)}
    if([string]$Asset.slide_index -notmatch '^\d+$' -or [int]$Asset.slide_index -lt 1){throw 'Invalid existing COM asset slide_index'}
    if($Asset.reference_kind -isnot [string] -or $Asset.reference_kind -cne 'picture'){throw 'V5 asset reference_kind requires picture string'}
    $keys=if($Asset -is [Collections.IDictionary]){@($Asset.Keys)}else{@($Asset.PSObject.Properties.Name)}
    if('origin' -cin $keys -and ($Asset.origin -isnot [string] -or $Asset.origin -cnotin @('provided','synthetic_test'))){throw 'Unsupported V5 asset origin'}
    $ratio=$Asset.known_visible_aspect_ratio
    if($ratio -isnot [ValueType] -or $ratio -is [bool] -or $ratio -is [char] -or $ratio -is [DateTime] -or [double]::IsNaN([double]$ratio) -or [double]::IsInfinity([double]$ratio) -or [double]$ratio -le 0){throw 'needs_input: finite positive numeric asset aspect ratio required'}
}
function Assert-ProposalV5AssetOrigin($Asset,$SourceIds,$Ledger){
    $synthetic=@($SourceIds|Where-Object {$Ledger.sources[$_].kind -ceq 'synthetic_asset'}).Count -gt 0
    $origin=if($null -eq $Asset.origin){'provided'}else{$Asset.origin}
    if($origin -ceq 'synthetic_test' -and -not $synthetic){throw 'Synthetic origin requires synthetic_asset source'}
    if($origin -cne 'synthetic_test' -and $synthetic){throw 'Synthetic source requires synthetic_test origin'}
}
function Get-ProposalV5ComparisonFocus($Comparison,[string]$Relationship){
    $keys=if($Comparison -is [Collections.IDictionary]){@($Comparison.Keys)}else{@($Comparison.PSObject.Properties.Name)}
    if('focus' -cnotin $keys){return}
    if($Relationship -cne 'procedure'){throw 'V5_FOCUS: comparison.focus requires procedure relationship'}
    $focus=$Comparison.focus
    if($focus -isnot [pscustomobject] -and $focus -isnot [Collections.IDictionary]){throw 'V5_FOCUS: comparison.focus requires an object'}
    $fields=if($focus -is [Collections.IDictionary]){@($focus.Keys)}else{@($focus.PSObject.Properties.Name)}
    if($fields.Count -ne 2 -or 'baseline_item' -cnotin $fields -or 'observed_item' -cnotin $fields){throw 'V5_FOCUS: focus requires exact keys baseline_item and observed_item'}
    foreach($side in @('baseline','observed')){
        $index=$focus.($side+'_item')
        if(($index -isnot [int] -and $index -isnot [long]) -or $index -lt 0 -or $index -ge @($Comparison.$side.items).Count){throw ('V5_FOCUS: invalid focus index for '+$side)}
    }
    return $focus
}
function Assert-ProposalProblemV5Shape($Stage){
    if($Stage.id -cne 'problem' -or $Stage.layout_profile -cne 'reference-v5-problem'){throw 'Unsupported problem profile or stage'}
    if($null -ne $Stage.panels -and ($Stage.panels -isnot [array] -or $Stage.panels.Count -ne 0)){throw 'V5 problem cannot mix compound content and flat panels; panels must be empty'}
    foreach($key in @('title','subtitle','takeaway','citation')){Assert-ProposalV5Text $Stage.$key ('stage.'+$key)}
    $p=$Stage.problem
    Assert-ProposalV5Object $p @('comparison','path','evidence','impact','overview_photo') 'problem'
    Assert-ProposalV5Object $p.comparison @('title','baseline','observed','note','focus') 'problem.comparison'
    foreach($side in @('baseline','observed')){
        $col=$p.comparison.$side
        Assert-ProposalV5Object $col @('title','items','source_ids') ('comparison.'+$side)
        Assert-ProposalV5Text $col.title ('comparison.'+$side+'.title')
        Assert-ProposalV5TextItems $col.items 2 3 ('comparison.'+$side+'.items')
    }
    Assert-ProposalV5Object $p.path @('title','steps','note','relationship') 'problem.path'
    $pathKeys=if($p.path -is [Collections.IDictionary]){@($p.path.Keys)}else{@($p.path.PSObject.Properties.Name)}
    if('relationship' -cin $pathKeys -and ($p.path.relationship -isnot [string] -or $p.path.relationship -cnotin @('sequence','parallel','procedure'))){throw 'Unsupported problem.path.relationship: sequence, parallel or procedure string required'}
    $null=Get-ProposalV5ComparisonFocus $p.comparison $p.path.relationship
    Assert-ProposalV5Array $p.path.steps 3 4 'path.steps'
    foreach($step in $p.path.steps){
        Assert-ProposalV5Object $step @('title','detail','icon','source_ids') 'path.step'
        Assert-ProposalV5Text $step.title 'path.step.title';Assert-ProposalV5Text $step.detail 'path.step.detail'
        if($step.icon -isnot [string] -or $step.icon -cnotin (@($script:ProposalIconKinds)+@($script:ProposalV4IconKinds))){throw 'Unsupported problem path icon'}
    }
    $e=$p.evidence
    Assert-ProposalV5Object $e @('title','kind','source_ids','table','asset','note','caption_source_ids') 'problem.evidence'
    if($e.kind -cnotin @('table','asset')){throw 'Unsupported evidence kind; table or asset required'}
    if($e.kind -ceq 'table'){
        if($null -ne $e.caption_source_ids){throw 'caption_source_ids are only supported for asset captions'}
        if($null -ne $e.asset){throw 'Cannot mix table and asset evidence'}
        Assert-ProposalV5Object $e.table @('headers','rows') 'evidence.table'
        Assert-ProposalV5TextItems $e.table.headers 2 2 'table.headers'
        Assert-ProposalV5Array $e.table.rows 2 4 'table.rows'
        foreach($row in $e.table.rows){Assert-ProposalV5TextItems $row 2 2 'table.row width'}
    }else{
        if($null -ne $e.table){throw 'Cannot mix asset and table evidence'}
        Assert-ProposalV5Picture $e.asset
        if($null -ne $e.PSObject.Properties['caption_source_ids']){Assert-ProposalV5Refs $e.caption_source_ids 'asset caption'}
    }
    $problemKeys=if($p -is [Collections.IDictionary]){@($p.Keys)}else{@($p.PSObject.Properties.Name)}
    if('overview_photo' -cin $problemKeys){
        $photo=$p.overview_photo
        Assert-ProposalV5Object $photo @('asset','source_ids') 'problem.overview_photo'
        if($p.path.relationship -cne 'parallel'){throw 'problem.overview_photo requires parallel path relationship'}
        if($e.kind -cne 'table'){throw 'problem.overview_photo requires table evidence'}
        Assert-ProposalV5Picture $photo.asset 'problem.overview_photo.asset'
        $ratio=[double]$photo.asset.known_visible_aspect_ratio
        if($ratio -lt 1.5 -or $ratio -gt (16.0/9)){throw 'problem.overview_photo asset aspect ratio requires 3:2 to 16:9'}
        Assert-ProposalV5Refs $photo.source_ids 'problem.overview_photo'
    }
    Assert-ProposalV5Object $p.impact @('title','groups','note') 'problem.impact'
    Assert-ProposalV5Array $p.impact.groups 2 2 'impact.groups'
    foreach($g in $p.impact.groups){
        Assert-ProposalV5Object $g @('title','lines','state','source_ids') 'impact.group'
        Assert-ProposalV5Text $g.title 'impact.group.title';Assert-ProposalV5TextItems $g.lines 1 3 'impact.group.lines'
        if($g.state -isnot [string] -or $g.state -cnotin @('supported','risk','unknown')){throw 'Unsupported impact state'}
    }
    foreach($key in @('comparison','path','evidence','impact')){
        Assert-ProposalV5Text $p.$key.title ($key+'.title')
        if($null -ne $p.$key.note){Assert-ProposalV5Text $p.$key.note ($key+'.note')}
    }
}
function Get-ProposalV5CaptionRefs($Evidence,$Ledger){
    if($Evidence.kind -cne 'asset'){return @($Evidence.source_ids)}
    if($null -ne $Evidence.PSObject.Properties['caption_source_ids']){return @($Evidence.caption_source_ids)}
    return @($Evidence.source_ids|Where-Object {$Ledger.sources[$_].kind -cne 'synthetic_asset'})
}
function Get-ProposalProblemV5Leaves($Stage,$Ledger){
    $leaves=New-Object 'Collections.Generic.List[object]'
    function Add-V5Leaf($Value,$Ids,[string]$Where){if($null -ne $Value){$leaves.Add([pscustomobject]@{text=$Value;source_ids=@($Ids);where=$Where})}}
    $p=$Stage.problem
    foreach($key in @('title','subtitle','takeaway','citation')){Add-V5Leaf $Stage.$key $Stage.source_ids ('stage.'+$key)}
    $refs=@($p.comparison.baseline.source_ids)+@($p.comparison.observed.source_ids)
    Add-V5Leaf $p.comparison.title $refs 'comparison.title';Add-V5Leaf $p.comparison.note $refs 'comparison.note'
    foreach($side in @('baseline','observed')){$col=$p.comparison.$side;Add-V5Leaf $col.title $col.source_ids ('comparison.'+$side+'.title');foreach($v in $col.items){Add-V5Leaf $v $col.source_ids ('comparison.'+$side+'.items')}}
    $refs=@($p.path.steps|ForEach-Object {$_.source_ids})
    Add-V5Leaf $p.path.title $refs 'path.title';Add-V5Leaf $p.path.note $refs 'path.note'
    foreach($step in $p.path.steps){foreach($key in @('title','detail')){Add-V5Leaf $step.$key $step.source_ids ('path.step.'+$key)}}
    $e=$p.evidence;$captionRefs=@(Get-ProposalV5CaptionRefs $e $Ledger)
    Add-V5Leaf $e.title $captionRefs 'evidence.title';Add-V5Leaf $e.note $captionRefs 'evidence.note'
    if($e.kind -ceq 'table'){foreach($v in $e.table.headers){Add-V5Leaf $v $e.source_ids 'table.header'};foreach($row in $e.table.rows){foreach($v in $row){Add-V5Leaf $v $e.source_ids 'table.cell'}}}else{Add-V5Leaf $e.asset.description $e.source_ids 'asset.description'}
    if($null -ne $p.overview_photo){Add-V5Leaf $p.overview_photo.asset.description $p.overview_photo.source_ids 'overview_photo.asset.description'}
    $refs=@($p.impact.groups|ForEach-Object {$_.source_ids})
    Add-V5Leaf $p.impact.title $refs 'impact.title';Add-V5Leaf $p.impact.note $refs 'impact.note'
    foreach($g in $p.impact.groups){Add-V5Leaf $g.title $g.source_ids 'impact.group.title';foreach($v in $g.lines){Add-V5Leaf $v $g.source_ids 'impact.group.line'}}
    return $leaves.ToArray()
}
function Assert-ProposalProblemV5Stage($Stage,$Ledger){
    Assert-ProposalProblemV5Shape $Stage
    Assert-ProposalV5Refs $Stage.source_ids 'stage'
    Assert-ProposalSourceIds $Stage.source_ids $Ledger.sources 'problem stage.source_ids' $false $true
    if(@($Stage.source_ids|Where-Object {$Ledger.sources[$_].kind -cne 'synthetic_asset'}).Count -eq 0){throw 'needs_input: stage requires non-synthetic factual source_ids'}
    $p=$Stage.problem;$e=$p.evidence;$photo=$p.overview_photo
    $nodes=@($p.comparison.baseline,$p.comparison.observed)+@($p.path.steps)+@($e)+@($p.impact.groups)
    if($null -ne $photo){$nodes+=@($photo)}
    foreach($node in $nodes){
        Assert-ProposalV5Refs $node.source_ids 'child'
        $assetNode=([object]::ReferenceEquals($node,$e) -and $e.kind -ceq 'asset') -or [object]::ReferenceEquals($node,$photo)
        Assert-ProposalSourceIds $node.source_ids $Ledger.sources 'problem child evidence.source_ids' $false $assetNode
        foreach($id in $node.source_ids){if($id -cnotin @($Stage.source_ids)){throw 'Child source_ids must be included in parent stage.source_ids'}}
    }
    if($e.kind -ceq 'asset'){
        $captionRefs=@(Get-ProposalV5CaptionRefs $e $Ledger)
        if($captionRefs.Count -eq 0){
            if($e.title -cnotin @('설명용 이미지','가상 설명 이미지') -or $null -ne $e.note){throw 'needs_input: factual asset title/note requires non-synthetic caption_source_ids'}
        }else{
            Assert-ProposalV5Refs $captionRefs 'asset caption'
            Assert-ProposalSourceIds $captionRefs $Ledger.sources 'asset caption_source_ids'
            foreach($id in $captionRefs){if($id -cnotin @($Stage.source_ids)){throw 'caption_source_ids must be included in parent stage.source_ids'}}
        }
        Assert-ProposalV5AssetOrigin $e.asset $e.source_ids $Ledger
    }
    if($null -ne $photo){Assert-ProposalV5AssetOrigin $photo.asset $photo.source_ids $Ledger}
    foreach($leaf in @(Get-ProposalProblemV5Leaves $Stage $Ledger)){
        $unbound=[regex]::Replace($leaf.text,'\[\[[A-Za-z][A-Za-z0-9_-]*\]\]','')
        if($unbound.Contains('[[') -or $unbound.Contains(']]')){throw ('Malformed ledger binding in '+$leaf.where)}
        $null=Convert-ProposalDisplayText $leaf.text $Ledger.bindings $leaf.where
        foreach($match in [regex]::Matches($leaf.text,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){
            $binding=$Ledger.bindings[$match.Groups[1].Value]
            $refs=@($binding.source_ids)
            $missing=if($binding.kind -ceq 'derived'){@($refs|Where-Object {$_ -cnotin @($leaf.source_ids)}).Count -gt 0}else{@($refs|Where-Object {$_ -cin @($leaf.source_ids)}).Count -eq 0}
            if($missing){throw ('Local number evidence is not included in source_ids: '+$leaf.where)}
        }
    }
    return $true
}
function Convert-ProposalProblemV5Stage($Stage,$Ledger){
    $copy=$Stage|ConvertTo-Json -Depth 60|ConvertFrom-Json
    if($copy.problem.evidence.kind -ceq 'asset' -and $null -eq $copy.problem.evidence.asset.PSObject.Properties['origin']){$copy.problem.evidence.asset|Add-Member -NotePropertyName origin -NotePropertyValue 'provided'}
    $photo=$copy.problem.overview_photo
    if($null -ne $photo -and $null -eq $photo.asset.PSObject.Properties['origin']){
        $photo.asset|Add-Member -NotePropertyName origin -NotePropertyValue 'provided'
    }
    $displayFields=@('title','subtitle','takeaway','citation','note','items','detail','headers','rows','lines','description')
    function Resolve-V5Node($Node,[string]$Key){
        if($Node -is [string]){if($Key -cin $displayFields){return (Convert-ProposalDisplayText $Node $Ledger.bindings ('problem.'+$Key))};return $Node}
        if($Node -is [array]){for($i=0;$i -lt $Node.Count;$i++){$Node[$i]=Resolve-V5Node $Node[$i] $Key};return ,$Node}
        if($Node -is [pscustomobject]){foreach($prop in @($Node.PSObject.Properties)){$prop.Value=Resolve-V5Node $prop.Value $prop.Name}}
        return $Node
    }
    return (Resolve-V5Node $copy '')
}
