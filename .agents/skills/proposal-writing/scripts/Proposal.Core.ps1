# Model-independent data and workflow helpers. No Office access in this file.
$script:ProposalStageOrder=@('problem','cause','actions','effects','rollout')
$script:ProposalIconKinds=@('heat_exchanger','oil','water','microbe','clean','training','rotation','shield','monitor','check','cost','factory')
$script:ProposalV4IconKinds=@('vacuum_chamber','part','erosion','material','energy','tank','filter','membrane_stack')
$script:ProposalPanelRoles=@('context','phenomenon','impact','evidence','causal','boundary','action','outcomes','details','calculation','coverage','expansion','checks')
function Get-ProposalTextHash([string]$Text){
  $sha=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Assert-ProposalId([string]$Id,[string]$Label){if($Id -notmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$'){throw ($Label+': invalid identifier')}}
function Assert-ProposalAllowedProperties($Value,[string[]]$Allowed,[string]$Where){
  if($null -eq $Value){return}
  $keys=if($Value -is [Collections.IDictionary]){@($Value.Keys)}else{@($Value.PSObject.Properties.Name)}
  foreach($key in $keys){if([string]$key -cnotin $Allowed){throw ('Unsupported property '+$Where+'.'+$key)}}
}
function Assert-ProposalV9Shape($Stage){
  if([string]$Stage.id -cnotin @('cause','effects')){throw ('V9 unsupported stage: '+$Stage.id)}
  Assert-ProposalAllowedProperties $Stage @('id','title','subtitle','takeaway','source_ids','panels','layout_profile','citation','visuals') 'stage'
  if($null -ne $Stage.visuals){
    $visualKeys=if($Stage.visuals -is [Collections.IDictionary]){@($Stage.visuals.Keys)}else{@($Stage.visuals.PSObject.Properties.Name)}
    if('resolved_metrics' -in $visualKeys){throw 'V9 resolved_metrics is internal and cannot be supplied'}
  }
  if(@($Stage.panels|Where-Object {$null -ne $_}).Count -eq 0){return}
  if($Stage.id -ceq 'cause'){
    . (Join-Path $PSScriptRoot 'Proposal.CauseV9.ps1')
    $null=Assert-ProposalCauseV9Visuals $Stage
  }else{
    . (Join-Path $PSScriptRoot 'Proposal.EffectsV9.ps1')
    $null=Assert-ProposalEffectsV9Visuals $Stage
  }
}
function ConvertTo-ProposalActionsV10BaseStage($Stage){
  if($Stage.id -cne 'actions'){throw ('V10 unsupported stage: '+$Stage.id)}
  Assert-ProposalAllowedProperties $Stage @('id','title','subtitle','takeaway','source_ids','panels','layout_profile','citation','visuals') 'stage'
  if(@($Stage.panels|Where-Object {$null -ne $_}).Count){
    . (Join-Path $PSScriptRoot 'Proposal.ActionsV10.ps1')
    $null=Assert-ProposalActionsV10Visuals $Stage
  }
  $base=$Stage|ConvertTo-Json -Depth 60|ConvertFrom-Json
  $base.layout_profile='reference-v8-actions'
  $base.PSObject.Properties.Remove('visuals')
  return $base
}
function Assert-ProposalShapeKeys($Case){
  Assert-ProposalAllowedProperties $Case @('schema_version','case_id','title','sources','numbers','identifiers','stages') 'case'
  foreach($source in @($Case.sources)){Assert-ProposalAllowedProperties $source @('id','text','kind','url') 'source'}
  foreach($number in @($Case.numbers)){Assert-ProposalAllowedProperties $number @('id','value','unit','qualifier','currency','period','source_ids','metric','kind','formula','inputs') 'number'}
  foreach($identifier in @($Case.identifiers)){Assert-ProposalAllowedProperties $identifier @('id','value','source_ids') 'identifier'}
  foreach($stage in @($Case.stages)){
    if($stage.layout_profile -ceq 'reference-v10-actions'){
      $base=ConvertTo-ProposalActionsV10BaseStage $stage
      Assert-ProposalShapeKeys ([pscustomobject]@{stages=@($base)})
      continue
    }
    if($stage.layout_profile -ceq 'reference-v9'){
      Assert-ProposalV9Shape $stage
      . (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')
      $base=ConvertTo-ProposalDesign98BaseStage $stage
      Assert-ProposalShapeKeys ([pscustomobject]@{stages=@($base)})
      continue
    }
    if($stage.layout_profile -ceq 'reference-v8-actions'){
      . (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')
      Assert-ProposalActionsV8Shape $stage
      $base=ConvertTo-ProposalActionsV8BaseStage $stage
      Assert-ProposalShapeKeys ([pscustomobject]@{stages=@($base)})
      continue
    }
    if($stage.layout_profile -ceq 'reference-v7'){
      . (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')
      Assert-ProposalDesign98Shape $stage
      $base=ConvertTo-ProposalDesign98BaseStage $stage
      Assert-ProposalShapeKeys ([pscustomobject]@{stages=@($base)})
      continue
    }
    Assert-ProposalAllowedProperties $stage @('id','title','subtitle','takeaway','source_ids','panels','scope','layout_profile','citation','problem') 'stage'
    $stageKeys=if($stage -is [Collections.IDictionary]){@($stage.Keys)}else{@($stage.PSObject.Properties.Name)}
    if('layout_profile' -cin $stageKeys -and ($stage.layout_profile -isnot [string] -or $stage.layout_profile -cnotin @('reference-v2','reference-v3','reference-v4','reference-v5-problem','reference-v6'))){throw 'Unsupported stage layout_profile'}
    if($stage.layout_profile -ceq 'reference-v6' -and $stage.id -ceq 'problem'){throw 'V6 unsupported stage problem: use reference-v5-problem'}
    if($stage.layout_profile -ceq 'reference-v5-problem'){. (Join-Path $PSScriptRoot 'Proposal.ProblemV5.ps1');Assert-ProposalProblemV5Shape $stage;continue}
    if('problem' -cin $stageKeys){throw 'Compound problem content requires reference-v5-problem profile'}
    if('citation' -cin $stageKeys -and $stage.citation -isnot [string]){throw 'Stage citation must be a string'}
    $allowedIcons=if($stage.layout_profile -cin @('reference-v4','reference-v6')){@($script:ProposalIconKinds)+@($script:ProposalV4IconKinds)}else{@($script:ProposalIconKinds)}
    foreach($panel in @($stage.panels)){
      Assert-ProposalAllowedProperties $panel @('title','kind','tone','source_ids','lines','steps','table','metrics','bars','asset','icon','outcome','step_icons','relationship','role','evidence_links','line_states','statement_links') 'panel'
      $panelKeys=if($panel -is [Collections.IDictionary]){@($panel.Keys)}else{@($panel.PSObject.Properties.Name)}
      $null=Assert-ProposalEvidenceLinkShape $stage $panel
      $null=Assert-ProposalStatementLinkShape $stage $panel
      $requiredEffectStates=$stage.layout_profile -cin @('reference-v4','reference-v6') -and $stage.id -ceq 'effects' -and $panel.role -ceq 'details' -and $panel.kind -ceq 'bullets'
      if($requiredEffectStates -and 'line_states' -cnotin $panelKeys){throw 'needs_input: V4 effects details bullets require line_states'}
      if('line_states' -cin $panelKeys){
        if($stage.layout_profile -cnotin @('reference-v4','reference-v6')){throw 'line_states require reference-v4'}
        $lineStateScope=($stage.id -ceq 'cause' -and $panel.role -ceq 'causal') -or ($stage.id -ceq 'effects' -and $panel.role -ceq 'details')
        if(-not $lineStateScope -or $panel.kind -cne 'bullets'){throw 'line_states require cause causal or effects details bullets'}
        if($panel.line_states -isnot [array]){throw 'line_states must be an array'}
        if($requiredEffectStates -and $panel.line_states.Count -eq 0){throw 'line_states must not be empty for V4 effects details bullets'}
        if($panel.lines -isnot [array] -or @($panel.line_states).Count -ne @($panel.lines).Count){throw 'line_states length must match the bullet lines array'}
        foreach($state in $panel.line_states){if($state -isnot [string] -or $state -cnotin @('supported','hypothesis','unknown','boundary')){throw 'line_states contain an unsupported state'}}
      }
      $allowedRoles=if($stage.layout_profile -ceq 'reference-v6'){@($script:ProposalPanelRoles)+@('system','operation','acceptance')}else{@($script:ProposalPanelRoles)}
      if('role' -cin $panelKeys -and ($panel.role -isnot [string] -or $panel.role -cnotin $allowedRoles)){throw 'Unsupported panel role'}
      if('icon' -cin $panelKeys -and ($panel.icon -isnot [string] -or $panel.icon -cnotin $allowedIcons)){throw 'Unsupported panel icon'}
      if('outcome' -cin $panelKeys -and $panel.outcome -isnot [string]){throw 'Panel outcome must be a string'}
      if('relationship' -cin $panelKeys){
        if($panel.relationship -isnot [string] -or $panel.relationship -cne 'sum'){throw 'Unsupported panel relationship'}
        if($panel.kind -ne 'flow'){throw 'Panel sum relationship requires flow'}
      }
      if('step_icons' -cin $panelKeys){
        if($panel.kind -notin @('flow','timeline')){throw 'Panel step_icons require flow or timeline'}
        if($panel.step_icons -isnot [array]){throw 'Panel step_icons must be an array'}
        if(@($panel.step_icons).Count -ne @($panel.steps).Count){throw 'Panel step_icons count must match steps'}
        foreach($icon in $panel.step_icons){if($icon -isnot [string] -or $icon -cnotin $allowedIcons){throw 'Unsupported panel step_icons token'}}
      }
      if($null -ne $panel.tone -and $panel.tone -notin @('normal','danger','success')){throw 'Unsupported panel tone'}
      if($null -ne $panel.table){Assert-ProposalAllowedProperties $panel.table @('headers','rows') 'table'}
      foreach($metric in @($panel.metrics)){Assert-ProposalAllowedProperties $metric @('label','value_text','detail') 'metric'}
      foreach($bar in @($panel.bars)){Assert-ProposalAllowedProperties $bar @('label','value_text','number_id') 'bar'}
      if($null -ne $panel.asset){
        Assert-ProposalAllowedProperties $panel.asset @('document_name','slide_index','shape_name','description','reference_kind','known_visible_aspect_ratio','origin') 'asset'
        $assetKeys=if($panel.asset -is [Collections.IDictionary]){@($panel.asset.Keys)}else{@($panel.asset.PSObject.Properties.Name)}
        if('origin' -cin $assetKeys -and ($panel.asset.origin -isnot [string] -or $panel.asset.origin -cnotin @('provided','synthetic_test'))){throw 'Unsupported asset origin'}
      }
    }
  }
}
function Assert-ProposalJsonPath([string]$Path){
  if([IO.Path]::GetExtension($Path) -ine '.json'){throw 'Only .json input is allowed; Office files are not read'}
}
function Get-ProposalSourceMap($Case){
  $map=@{}
  foreach($source in @($Case.sources)){
    if($null -eq $source){throw 'needs_input: sources are required'}
    Assert-ProposalId ([string]$source.id) 'source'
    if($map.ContainsKey($source.id)){throw ('Duplicate source: '+$source.id)}
    if($source.kind -isnot [string] -or $source.kind -cnotin @('public_vendor_case','public_document','user_observation','rollout_record','synthetic_asset')){throw ('Unsupported source kind: '+$source.id)}
    if([string]::IsNullOrWhiteSpace([string]$source.text)){throw ('needs_input: source text missing: '+$source.id)}
    $map[$source.id]=$source
  }
  if($map.Count -eq 0){throw 'needs_input: no source evidence'}
  return $map
}
function Assert-ProposalSourceIds($Ids,$SourceMap,[string]$Where,[bool]$AllowEmpty=$false,[bool]$AllowSyntheticAsset=$false){
  $items=@($Ids|Where-Object {$null -ne $_ -and [string]$_ -ne ''})
  if($items.Count -eq 0 -and -not $AllowEmpty){throw ('needs_input: source_ids missing: '+$Where)}
  foreach($id in $items){
    if(-not $SourceMap.ContainsKey([string]$id)){throw ('Unknown source '+$id+' in '+$Where)}
    if(-not $AllowSyntheticAsset -and $SourceMap[[string]$id].kind -eq 'synthetic_asset'){throw ('Synthetic asset source cannot support factual evidence: '+$Where)}
  }
}
function Get-ProposalNumberMap($Case,$SourceMap){
  $definitions=@{};$resolved=@{};$visiting=@{}
  foreach($number in @($Case.numbers)){
    if($null -eq $number){continue}
    Assert-ProposalId ([string]$number.id) 'number'
    if($definitions.ContainsKey($number.id)){throw ('Duplicate number: '+$number.id)}
    $definitions[$number.id]=$number
  }
  function Resolve-Number([string]$Id){
    if($resolved.ContainsKey($Id)){return $resolved[$Id]}
    if(-not $definitions.ContainsKey($Id)){throw ('Unknown number: '+$Id)}
    if($visiting.ContainsKey($Id)){throw ('Cyclic number formula: '+$Id)}
    $visiting[$Id]=$true;$n=$definitions[$Id]
    if($n.kind -notin @('reported','derived')){throw ('Unsupported number kind: '+$Id)}
    $unit=[string]$n.unit;$currency=[string]$n.currency;$period=[string]$n.period;$qualifier=[string]$n.qualifier
    if($currency -and $currency -notin @('USD','KRW')){throw ('Unsupported currency: '+$Id)}
    if($period -and $period -notin @('year','month')){throw ('Unsupported period: '+$Id)}
    if($qualifier -and $qualifier -notin @('이상','이하','미만','초과')){throw ('Unsupported qualifier: '+$Id)}
    if([string]::IsNullOrWhiteSpace([string]$n.metric)){throw ('needs_input: number metric missing: '+$Id)}
    $value=[decimal]0;$refs=@()
    if($n.kind -eq 'derived'){
      if($n.formula -ne 'sum' -or @($n.inputs).Count -lt 2){throw ('Only sum of at least two inputs is supported: '+$Id)}
      $seenInputs=@{}
      foreach($inputId in @($n.inputs)){if($seenInputs.ContainsKey([string]$inputId)){throw ('Duplicate sum input: '+$Id)};$seenInputs[[string]$inputId]=$true}
      $parts=@($n.inputs|ForEach-Object {Resolve-Number ([string]$_)})
      $base=$parts[0]
      foreach($part in $parts){
        if($part.currency -ne $base.currency -or $part.period -ne $base.period -or $part.unit -ne $base.unit -or $part.qualifier){throw ('Incompatible sum currency/period/unit/qualifier: '+$Id)}
        $value+=$part.value;$refs+=@($part.source_ids)
      }
      foreach($field in @('currency','period','unit')){
        $declared=[string]$n.$field
        if($declared -and $declared -ne [string]$base.$field){throw ('Declared sum '+$field+' conflicts: '+$Id)}
      }
      $currency=$base.currency;$period=$base.period;$unit=$base.unit
      if($qualifier){throw ('Derived qualifier is unsupported: '+$Id)}
      if($null -ne $n.value -and [string]$n.value -ne ''){
        $declaredValue=[decimal]::Parse([string]$n.value,[Globalization.CultureInfo]::InvariantCulture)
        if($declaredValue -ne $value){throw ('Declared derived amount differs from calculated sum: '+$Id)}
      }
      if(@($n.source_ids|Where-Object {$null -ne $_}).Count){Assert-ProposalSourceIds $n.source_ids $SourceMap $Id $true;$refs+=@($n.source_ids)}
    }else{
      if([string]$n.value -notmatch '^-?\d+(?:\.\d+)?$'){throw ('Invalid decimal value: '+$Id)}
      $value=[decimal]::Parse([string]$n.value,[Globalization.CultureInfo]::InvariantCulture)
      Assert-ProposalSourceIds $n.source_ids $SourceMap $Id
      $refs=@($n.source_ids)
    }
    if($unit -eq '%' -and ($currency -or $value -lt 0 -or $value -gt 100)){throw ('Invalid percent number: '+$Id)}
    # A Korean year suffix can represent a calendar year (2016년). Retain its
    # source value and precision without formatting it as a grouped quantity.
    # Money and every other unit keep the existing thousands separator policy.
    $numberFormat=if($unit -ceq '년' -and -not $currency){'0.############################'}else{'#,0.############################'}
    $display=$value.ToString($numberFormat,[Globalization.CultureInfo]::InvariantCulture)
    if($currency){$display=$currency+' '+$display}
    if($unit){$display+=$unit}
    if($qualifier){$display+=' '+$qualifier}
    if($period){$display+= $(if($period -eq 'year'){' / 년'}else{' / 월'})}
    $out=[pscustomobject]@{id=$Id;value=$value;unit=$unit;currency=$currency;period=$period;qualifier=$qualifier;metric=$n.metric;source_ids=@($refs|Select-Object -Unique);display=$display;kind=$n.kind}
    if($n.kind -eq 'derived'){$out|Add-Member -NotePropertyName formula -NotePropertyValue 'sum';$out|Add-Member -NotePropertyName inputs -NotePropertyValue @($n.inputs)}
    $resolved[$Id]=$out;$visiting.Remove($Id)
    return $out
  }
  foreach($id in @($definitions.Keys)){$null=Resolve-Number $id}
  return $resolved
}
function Get-ProposalLedger($Case){
  Assert-ProposalShapeKeys $Case
  if([string]$Case.schema_version -ne '1.0'){throw 'Unsupported schema_version'}
  Assert-ProposalId ([string]$Case.case_id) 'case_id'
  $ids=@($Case.stages|ForEach-Object {[string]$_.id})
  if(($ids -join ',') -cne ($script:ProposalStageOrder -join ',')){throw 'Stages must be problem,cause,actions,effects,rollout exactly once and in order'}
  $sources=Get-ProposalSourceMap $Case
  $numbers=Get-ProposalNumberMap $Case $sources
  $identifiers=Get-ProposalIdentifierMap $Case $sources $numbers
  $bindings=@{}
  foreach($key in @($numbers.Keys)){$bindings[$key]=$numbers[$key]}
  foreach($key in @($identifiers.Keys)){$bindings[$key]=$identifiers[$key]}
  return [pscustomobject]@{sources=$sources;numbers=$numbers;identifiers=$identifiers;bindings=$bindings}
}
function Get-ProposalIdentifierMap($Case,$SourceMap,$NumberMap){
  $map=@{}
  foreach($identifier in @($Case.identifiers|Where-Object {$null -ne $_})){
    Assert-ProposalId ([string]$identifier.id) 'identifier'
    $id=[string]$identifier.id
    if($SourceMap.ContainsKey($id) -or $NumberMap.ContainsKey($id)){throw ('Identifier id collision with another ledger: '+$id)}
    if($map.ContainsKey($id)){throw ('Duplicate identifier: '+$id)}
    $value=[string]$identifier.value
    if($value -notmatch '^[\p{L}\p{Nd}][\p{L}\p{Nd}._-]{0,39}$' -or $value -notmatch '\p{L}' -or $value -notmatch '\p{Nd}' -or $value -match '(?i:USD|KRW)|[$₩%]|\d(?:억원|만원|천원|원|억|년|개월|월|일|시간|분|초|건|매|개|대|회|퍼센트|프로)$'){
      throw ('Identifier value must be a short equipment name, not a quantity/currency/unit: '+$id)
    }
    Assert-ProposalSourceIds $identifier.source_ids $SourceMap $id
    # A finite Korean ending may follow the exact model name; it must end at a boundary.
    # A terminal period is punctuation only when it does not continue a larger model token.
    $koreanEnding='(?:으로부터|에서부터|에게서|한테서|으로써|으로서|에게는|에게도|에서는|에서도|으로는|으로도|까지는|부터는|입니다|이다|에서|에게|한테|으로|처럼|보다|부터|까지|마다|하고|에는|로는|로도|만|도|을|를|은|는|이|가|의|와|과|로|에)'
    $endingBoundary='(?:(?![\p{L}\p{Nd}._-])|\.(?![\p{L}\p{Nd}._-]))'
    $pattern='(?<![\p{L}\p{Nd}._-])'+[regex]::Escape($value)+'(?:(?![\p{L}\p{Nd}._-])|(?='+$koreanEnding+$endingBoundary+'))'
    $supporting=@($identifier.source_ids|Where-Object {[regex]::IsMatch([string]$SourceMap[[string]$_].text,$pattern)})
    if($supporting.Count -eq 0){throw ('Identifier source lacks the exact equipment token: '+$id)}
    $map[$id]=[pscustomobject]@{id=$id;value=$value;display=$value;source_ids=$supporting;kind='identifier'}
  }
  return $map
}
function Convert-ProposalDisplayText([string]$Text,$Numbers,[string]$Where){
  $matches=[regex]::Matches($Text,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')
  $stripped=[regex]::Replace($Text,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]','')
  if($stripped -match '\d'){throw ('Unregistered raw number in '+$Where+'; use ledger [[ID]]')}
  if($stripped.Contains('[[') -or $stripped.Contains(']]')){throw ('Malformed number binding in '+$Where)}
  $out=$Text
  foreach($match in $matches){
    $id=$match.Groups[1].Value
    if(-not $Numbers.ContainsKey($id)){throw ('Unknown number binding '+$id+' in '+$Where)}
    $out=$out.Replace($match.Value,[string]$Numbers[$id].display)
  }
  return $out
}
function Assert-ProposalDenseV6Slots($Stage){
  $id=[string]$Stage.id;$panels=@($Stage.panels|Where-Object {$null -ne $_})
  if($id -cnotin @('cause','actions','effects','rollout')){throw ('V6 unsupported stage: '+$id)}
  $count=if($id -ceq 'actions'){6}else{4}
  if($panels.Count -ne $count){throw ('V6 panel count must be exactly '+$count+': '+$id)}
  switch($id){
    'cause' {$roles=@('system','evidence','causal','boundary');$kinds=@(@('bullets'),@('table'),@('flow','bullets'),@('bullets'))}
    'actions' {$roles=@('action')*6;$kinds=@(@('bullets'),@('bullets'),@('bullets'),@('bullets'),@('bullets'),@('bullets'))}
    'effects' {$roles=@('outcomes','details','operation','boundary');$kinds=@(@('metrics'),@('table','bullets'),@('bullets'),@('bullets'))}
    'rollout' {$roles=@('coverage','expansion','checks','acceptance');$kinds=@(@('table'),@('flow'),@('bullets'),@('bullets'))}
  }
  for($i=0;$i -lt $count;$i++){
    $p=$panels[$i]
    if($p.role -cne $roles[$i]){throw ('V6 role or position mismatch: '+$id+' requires '+$roles[$i])}
    if([string]$p.kind -cnotin @($kinds[$i])){throw ('V6 role kind mismatch: '+$id+'.'+$roles[$i])}
    $keys=if($p -is [Collections.IDictionary]){@($p.Keys)}else{@($p.PSObject.Properties.Name)}
    # Body properties are exclusive to the selected kind, even when empty.
    # Otherwise an additional business claim can survive resolution while the
    # selected renderer and density counter both silently ignore it.
    $selectedContent=@{bullets='lines';flow='steps';table='table';metrics='metrics'}[[string]$p.kind]
    foreach($contentKey in @('lines','steps','table','metrics','bars','asset')){
      if($contentKey -cin $keys -and $contentKey -cne $selectedContent){throw ('V6 content property '+$contentKey+' is unsupported for selected kind '+$p.kind)}
    }
    if($id -cne 'actions' -and 'outcome' -cin $keys){throw 'V6 outcome is supported only on action cards; do not silently drop business content'}
    if($null -ne $p.relationship){throw 'V6 sum relationship is unsupported; no unverified effect calculation slot'}
    if($id -ceq 'actions'){
      if([string]::IsNullOrWhiteSpace([string]$p.icon)){throw 'V6 action icon is required'}
      if([string]::IsNullOrWhiteSpace([string]$p.outcome)){throw 'V6 action outcome is required'}
    }
  }
}
function Assert-ProposalReferenceV3Slots($Stage){
  if($Stage.layout_profile -ceq 'reference-v6'){Assert-ProposalDenseV6Slots $Stage;return}
  # V4 inherits the V3 semantic slots; only its fixed composition and icon set differ.
  $profile=[string]$Stage.layout_profile
  $id=[string]$Stage.id;$panels=@($Stage.panels|Where-Object {$null -ne $_});$count=$panels.Count
  if(($id -eq 'actions' -and ($count -lt 3 -or $count -gt 6)) -or ($id -ne 'actions' -and $count -notin @(2,3))){throw ('Unsupported '+$profile+' panel count: '+$id)}
  switch($id){
    'problem' {$roles=@('context','phenomenon','impact');$kinds=@(@('bullets','asset'),@('flow'),@('bullets'))}
    'cause' {$roles=@('evidence','causal','boundary');$kinds=@(@('table','asset'),@('flow','bullets'),@('bullets'))}
    'actions' {$roles=@('action')*6;$kinds=@(@('bullets'),@('bullets'),@('bullets'),@('bullets'),@('bullets'),@('bullets'))}
    'effects' {$roles=@('outcomes','details','calculation');$kinds=@(@('metrics'),@('table','bars','bullets'),@('flow'))}
    'rollout' {$roles=@('coverage','expansion','checks');$kinds=@(@('table'),@('flow'),@('bullets'))}
  }
  for($i=0;$i -lt $count;$i++){
    if($panels[$i].role -cne $roles[$i]){throw ('Unsupported '+$profile+' panel role or position: '+$id+' requires '+$roles[$i])}
    if([string]$panels[$i].kind -cnotin @($kinds[$i])){throw ('Unsupported '+$profile+' role kind: '+$id+'.'+$roles[$i])}
    if($panels[$i].relationship -ceq 'sum' -and $panels[$i].role -cne 'calculation'){throw ($profile+' sum relationship is restricted to the calculation role')}
    if($panels[$i].role -eq 'calculation' -and $panels[$i].relationship -cne 'sum'){throw ($profile+' calculation requires a validated sum relationship')}
  }
}
function Test-ProposalEvidenceIndexInteger($Value){
  if($null -eq $Value){return $false}
  return [Type]::GetTypeCode($Value.GetType()) -in @([TypeCode]::SByte,[TypeCode]::Byte,[TypeCode]::Int16,[TypeCode]::UInt16,[TypeCode]::Int32,[TypeCode]::UInt32,[TypeCode]::Int64,[TypeCode]::UInt64)
}
function Assert-ProposalEvidenceLinkShape($Stage,$Panel){
  $keys=if($Panel -is [Collections.IDictionary]){@($Panel.Keys)}else{@($Panel.PSObject.Properties.Name)}
  if('evidence_links' -cnotin $keys){return $false}
  if($Stage.layout_profile -cnotin @('reference-v4','reference-v6')){throw 'evidence_links require reference-v4'}
  if($Panel.kind -cne 'flow'){throw 'evidence_links require flow'}
  if($Panel.role -ceq 'phenomenon'){
    if($Stage.id -cne 'problem'){throw 'evidence_links phenomenon requires problem stage'}
  }elseif($Panel.role -cnotin @('causal','expansion')){throw 'evidence_links require phenomenon in problem, causal or expansion role'}
  if($Panel.evidence_links -isnot [array]){throw 'evidence_links must be an array'}
  foreach($link in $Panel.evidence_links){
    if($null -eq $link -or ($link -isnot [pscustomobject] -and $link -isnot [Collections.IDictionary])){throw 'evidence_links entries must be objects'}
    Assert-ProposalAllowedProperties $link @('step_index','panel_index','item_indices') 'evidence_links.evidence_link'
    foreach($field in @('step_index','panel_index')){if(-not (Test-ProposalEvidenceIndexInteger $link.$field)){throw ('evidence_links '+$field+' requires an integer')}}
    if($link.item_indices -isnot [array] -or @($link.item_indices).Count -lt 1 -or @($link.item_indices).Count -gt 6){throw 'evidence_links item_indices require an array of one to six integers'}
    foreach($item in $link.item_indices){if(-not (Test-ProposalEvidenceIndexInteger $item)){throw 'evidence_links item_indices require integer values'}}
  }
  return $true
}
function Assert-ProposalEvidenceLinks($Stage){
  $panels=@($Stage.panels)
  for($flowIndex=0;$flowIndex -lt $panels.Count;$flowIndex++){
    $flow=$panels[$flowIndex]
    if(-not (Assert-ProposalEvidenceLinkShape $Stage $flow)){continue}
    $seenPairs=@{};$seenItems=@{};$peerCounts=@{};$peerUsedCounts=@{}
    foreach($link in $flow.evidence_links){
      $step=$link.step_index;$peerIndex=$link.panel_index
      if($step -lt 0 -or $step -ge @($flow.steps).Count){throw 'evidence_links step_index is out of range'}
      if($peerIndex -lt 0 -or $peerIndex -ge $panels.Count){throw 'evidence_links panel_index is out of range'}
      if($peerIndex -eq $flowIndex){throw 'evidence_links cannot reference the flow itself'}
      $peer=$panels[$peerIndex]
      if($peer.kind -cnotin @('table','bullets')){throw 'evidence_links source peers must be table or bullets panels'}
      $pairKey=([string]$step)+':'+([string]$peerIndex)
      if($seenPairs.ContainsKey($pairKey)){throw 'evidence_links Duplicate step and panel link'}
      $seenPairs[$pairKey]=$true
      if(@($peer.source_ids|Where-Object {$_ -notin @($flow.source_ids)}).Count){throw 'evidence_links peer source_ids must all be included in flow source_ids'}
      $itemCount=if($peer.kind -ceq 'table'){@($peer.table.rows).Count}else{@($peer.lines).Count}
      $peerKey=[string]$peerIndex;$peerCounts[$peerKey]=$itemCount
      foreach($itemIndex in $link.item_indices){
        if($itemIndex -lt 0 -or $itemIndex -ge $itemCount){throw 'evidence_links item index is out of range'}
        $itemKey=$peerKey+':'+([string]$itemIndex)
        if($seenItems.ContainsKey($itemKey)){throw 'evidence_links source item must be referenced exactly once per flow'}
        $seenItems[$itemKey]=$true;$peerUsedCounts[$peerKey]=1+[int]$peerUsedCounts[$peerKey]
      }
    }
    foreach($peerKey in $peerCounts.Keys){if([int]$peerUsedCounts[$peerKey] -ne [int]$peerCounts[$peerKey]){throw 'evidence_links must cover all source items of each referenced peer panel'}}
  }
}
function Assert-ProposalStatementLinkShape($Stage,$Panel){
  $keys=if($Panel -is [Collections.IDictionary]){@($Panel.Keys)}else{@($Panel.PSObject.Properties.Name)}
  if('statement_links' -cnotin $keys){return $false}
  if($Stage.layout_profile -cnotin @('reference-v4','reference-v6')){throw 'statement_links require reference-v4'}
  if($Stage.id -cne 'cause' -or $Panel.role -cne 'causal' -or $Panel.kind -cne 'bullets'){throw 'statement_links require cause causal bullets'}
  if($Panel.statement_links -isnot [array]){throw 'statement_links must be an array'}
  foreach($link in $Panel.statement_links){
    if($null -eq $link -or ($link -isnot [pscustomobject] -and $link -isnot [Collections.IDictionary])){throw 'statement_links entries must be objects'}
    Assert-ProposalAllowedProperties $link @('line_index','row_indices') 'statement_links.statement_link'
    if(-not (Test-ProposalEvidenceIndexInteger $link.line_index)){throw 'statement_links line_index requires an integer'}
    if($link.row_indices -isnot [array] -or @($link.row_indices).Count -eq 0){throw 'statement_links row_indices require a nonempty array of integers'}
    foreach($rowIndex in $link.row_indices){if(-not (Test-ProposalEvidenceIndexInteger $rowIndex)){throw 'statement_links row_indices require integer values'}}
  }
  return $true
}
function Assert-ProposalStatementLinks($Stage){
  foreach($panel in @($Stage.panels)){
    if(-not (Assert-ProposalStatementLinkShape $Stage $panel) -or $panel.statement_links.Count -eq 0){continue}
    $evidenceIndex=if($Stage.layout_profile -ceq 'reference-v6'){1}else{0}
    $peer=@($Stage.panels)[$evidenceIndex]
    if($null -eq $peer -or $peer.role -cne 'evidence' -or $peer.kind -cne 'table'){throw ('statement_links require evidence panel '+$evidenceIndex+' to be a table')}
    if(@($peer.source_ids|Where-Object {$_ -notin @($panel.source_ids)}).Count){throw 'statement_links peer source_ids must all be included in causal source_ids'}
    $seenLines=@{};$rowCount=@($peer.table.rows).Count
    foreach($link in $panel.statement_links){
      if($link.line_index -lt 0 -or $link.line_index -ge @($panel.lines).Count){throw 'statement_links line_index is out of range'}
      $lineKey=[string]$link.line_index
      if($seenLines.ContainsKey($lineKey)){throw 'statement_links Duplicate line_index'}
      $seenLines[$lineKey]=$true;$seenRows=@{}
      foreach($rowIndex in $link.row_indices){
        if($rowIndex -lt 0 -or $rowIndex -ge $rowCount){throw 'statement_links row index is out of range'}
        $rowKey=[string]$rowIndex
        if($seenRows.ContainsKey($rowKey)){throw 'statement_links Duplicate row within one link'}
        $seenRows[$rowKey]=$true
      }
    }
  }
}
function Assert-ProposalStage($Stage,$Ledger){
  if($Stage.layout_profile -ceq 'reference-v10-actions'){
    $base=ConvertTo-ProposalActionsV10BaseStage $Stage
    return (Assert-ProposalStage $base $Ledger)
  }
  if($Stage.layout_profile -ceq 'reference-v9'){
    Assert-ProposalV9Shape $Stage
    . (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')
    $base=ConvertTo-ProposalDesign98BaseStage $Stage
    $null=Assert-ProposalStage $base $Ledger
    if($Stage.id -ceq 'effects'){
      . (Join-Path $PSScriptRoot 'Proposal.EffectsV9.ps1')
      $null=Get-ProposalEffectsV9Numbers $Stage $Ledger
    }elseif($Stage.visuals.kind -ceq 'water_cooled_plant'){
      $source=$Ledger.sources[[string]$Stage.visuals.source_id]
      if($null -eq $source -or $source.kind -cne 'public_document'){
        throw 'V9 cooling system schematic requires a technical document source'
      }
    }
    return $true
  }
  if($Stage.layout_profile -ceq 'reference-v8-actions'){
    . (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')
    Assert-ProposalActionsV8Shape $Stage
    $base=ConvertTo-ProposalActionsV8BaseStage $Stage
    $null=Assert-ProposalStage $base $Ledger
    return (Assert-ProposalActionsV8Stage $Stage)
  }
  if($Stage.layout_profile -ceq 'reference-v7'){
    . (Join-Path $PSScriptRoot 'Proposal.Design98.Contract.ps1')
    $base=ConvertTo-ProposalDesign98BaseStage $Stage
    $null=Assert-ProposalStage $base $Ledger
    return (Assert-ProposalDesign98Stage $Stage $Ledger)
  }
  if($Stage.layout_profile -ceq 'reference-v5-problem'){. (Join-Path $PSScriptRoot 'Proposal.ProblemV5.ps1');return (Assert-ProposalProblemV5Stage $Stage $Ledger)}
  $id=[string]$Stage.id
  if($id -notin $script:ProposalStageOrder){throw 'Unknown stage id'}
  $typedReference=$Stage.layout_profile -cin @('reference-v3','reference-v4','reference-v6')
  $displayKeys=@('title','subtitle','takeaway')
  if($typedReference -or $null -ne $Stage.citation){$displayKeys+='citation'}
  foreach($key in $displayKeys){
    if([string]::IsNullOrWhiteSpace([string]$Stage.$key)){throw ('needs_input: '+$id+'.'+$key+' missing')}
    $null=Convert-ProposalDisplayText ([string]$Stage.$key) $Ledger.bindings ($id+'.'+$key)
  }
  $proposal=$id -eq 'rollout' -and $Stage.scope -eq 'proposal'
  if($id -eq 'rollout' -and $Stage.scope -notin @('proposal','actual')){throw 'needs_input: rollout scope proposal|actual is required'}
  Assert-ProposalSourceIds $Stage.source_ids $Ledger.sources $id ($proposal -and -not $typedReference)
  foreach($key in $displayKeys){
    foreach($binding in [regex]::Matches([string]$Stage.$key,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){
      $number=$Ledger.bindings[$binding.Groups[1].Value]
      $missingDerived=$number.kind -eq 'derived' -and @($number.source_ids|Where-Object {$_ -notin @($Stage.source_ids)}).Count -gt 0
      if($missingDerived -or @($number.source_ids|Where-Object {$_ -in @($Stage.source_ids)}).Count -eq 0){throw ('Stage number evidence is not included in source_ids: '+$id)}
    }
  }
  $maxPanels=if($id -eq 'actions'){6}else{4}
  if(@($Stage.panels|Where-Object {$null -ne $_}).Count -lt 1){throw ('needs_input: '+$id+' panels missing')}
  if(@($Stage.panels).Count -gt $maxPanels){throw ('Unsupported panel count: '+$id)}
  if($typedReference){Assert-ProposalReferenceV3Slots $Stage}
  foreach($panel in @($Stage.panels)){
    if($panel.kind -notin @('bullets','flow','timeline','table','metrics','bars','asset')){throw ('Unsupported panel kind: '+$panel.kind)}
    if([string]::IsNullOrWhiteSpace([string]$panel.title)){throw ('needs_input: panel title missing in '+$id)}
    $null=Convert-ProposalDisplayText ([string]$panel.title) $Ledger.bindings ($id+'.panel.title')
    Assert-ProposalSourceIds $panel.source_ids $Ledger.sources ($id+'.panel') $proposal ($panel.kind -eq 'asset')
    if($id -eq 'rollout' -and -not $proposal){
      $records=@($panel.source_ids|Where-Object {$Ledger.sources[[string]$_].kind -eq 'rollout_record'})
      if($records.Count -eq 0){throw 'Actual rollout requires rollout_record evidence for every panel'}
    }
    $texts=@([string]$panel.title)
    if($null -ne $panel.outcome){$texts+=[string]$panel.outcome}
    switch($panel.kind){
      'bullets' {if(@($panel.lines).Count -lt 1 -or @($panel.lines).Count -gt 6){throw 'Unsupported or missing bullet lines'};$texts+=@($panel.lines)}
      'flow' {if(@($panel.steps).Count -lt 2 -or @($panel.steps).Count -gt 4){throw 'Flow requires two to four evidenced steps'};$texts+=@($panel.steps)}
      'timeline' {if(@($panel.steps).Count -lt 2 -or @($panel.steps).Count -gt 4){throw 'Timeline requires two to four evidenced steps'};$texts+=@($panel.steps)}
      'table' {
        $columns=@($panel.table.headers).Count;$rows=@($panel.table.rows)
        if($columns -lt 1 -or $columns -gt 4 -or $rows.Count -lt 1 -or $rows.Count -gt 5){throw 'Unsupported table dimensions'}
        $texts+=@($panel.table.headers)
        foreach($row in $rows){
          if(@($row).Count -ne $columns){throw 'Table row width differs from header'}
          foreach($cell in @($row)){
            foreach($cellBinding in [regex]::Matches([string]$cell,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){
              $numberId=$cellBinding.Groups[1].Value
              if($Ledger.numbers.ContainsKey($numberId)){
                if([string]$cell -cne ('[['+$numberId+']]')){throw 'Numeric table cells must use exactly one ledger binding'}
                if([string]$row[0] -cne [string]$Ledger.numbers[$numberId].metric){throw 'Table row label and number metric differ'}
              }
            }
          }
          $texts+=@($row)
        }
      }
      'metrics' {
        if(@($panel.metrics).Count -lt 1 -or @($panel.metrics).Count -gt 3){throw 'Unsupported metrics count'}
        foreach($metric in @($panel.metrics)){
          if([string]$metric.value_text -notmatch '^\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]$'){throw 'Metric value_text must be exactly one ledger binding'}
          $numberId=$Matches[1]
          if(-not $Ledger.numbers.ContainsKey($numberId) -or [string]$metric.label -cne [string]$Ledger.numbers[$numberId].metric){throw 'Metric label and number metric differ'}
          foreach($field in @('label','value_text','detail')){foreach($binding in [regex]::Matches([string]$metric.$field,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){if(-not $Ledger.numbers.ContainsKey($binding.Groups[1].Value)){throw 'Metric fields accept quantity bindings only'}}}
          $texts+=@($metric.label,$metric.value_text)
          if([string]$metric.detail){$texts+=[string]$metric.detail}
        }
      }
      'bars' {
        if(@($panel.bars).Count -lt 1 -or @($panel.bars).Count -gt 4){throw 'Unsupported bars count'}
        foreach($bar in @($panel.bars)){
          if(-not $Ledger.numbers.ContainsKey([string]$bar.number_id)){throw 'Bar requires a registered number_id'}
          $number=$Ledger.numbers[[string]$bar.number_id]
          if($number.unit -ne '%' -or $number.qualifier -or $number.value -lt 0 -or $number.value -gt 100){throw 'Bar requires an exact unqualified percent'}
          if([string]$bar.label -cne [string]$number.metric -or [string]$bar.value_text -cne ('[['+$bar.number_id+']]')){throw 'Bar label/value binding differs from ledger metric'}
          foreach($field in @('label','value_text')){foreach($binding in [regex]::Matches([string]$bar.$field,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){if(-not $Ledger.numbers.ContainsKey($binding.Groups[1].Value)){throw 'Bar fields accept quantity bindings only'}}}
          if($null -ne $bar.ratio){throw 'Input bar ratio is unsupported; it is computed from the ledger'}
          $texts+=@($bar.label,$bar.value_text)
        }
      }
      'asset' {
        Assert-ProposalSourceIds $panel.source_ids $Ledger.sources ($id+'.asset') $false $true
        $asset=$panel.asset
        if($null -eq $asset){throw 'needs_input: existing COM asset reference missing'}
        $allowedAssetFields=@('document_name','slide_index','shape_name','description','reference_kind','known_visible_aspect_ratio','origin')
        foreach($name in @($asset.PSObject.Properties.Name)){if($name -notin $allowedAssetFields){throw ('Unsupported asset field; file/URL loading is forbidden: '+$name)}}
        if([string]::IsNullOrWhiteSpace([string]$asset.document_name) -or [string]::IsNullOrWhiteSpace([string]$asset.shape_name) -or [string]::IsNullOrWhiteSpace([string]$asset.description)){throw 'needs_input: asset document/shape/description missing'}
        if([string]$asset.slide_index -notmatch '^\d+$' -or [int]$asset.slide_index -lt 1){throw 'Invalid existing COM asset slide_index'}
        if($asset.reference_kind -notin @('picture','diagram')){throw 'Unsupported asset reference_kind'}
        if($typedReference -and $asset.reference_kind -cne 'picture'){throw ('Unsupported '+$Stage.layout_profile+' asset reference_kind; current photo slots require picture')}
        $syntheticSources=@($panel.source_ids|Where-Object {$Ledger.sources[[string]$_].kind -eq 'synthetic_asset'})
        $origin=if($null -ne $asset.origin){[string]$asset.origin}else{'provided'}
        if($origin -eq 'synthetic_test' -and $syntheticSources.Count -eq 0){throw 'Synthetic asset origin requires a synthetic_asset source'}
        if($origin -ne 'synthetic_test' -and $syntheticSources.Count -gt 0){throw 'Synthetic asset source requires explicit synthetic_test origin'}
        if($typedReference -and $asset.reference_kind -eq 'picture'){
          $ratio=$asset.known_visible_aspect_ratio
          if($ratio -isnot [ValueType] -or $ratio -is [bool] -or $ratio -is [char] -or $null -eq $ratio -or $ratio -is [DateTime] -or [double]::IsNaN([double]$ratio) -or [double]::IsInfinity([double]$ratio) -or [double]$ratio -le 0){throw ('needs_input: '+$Stage.layout_profile+' picture requires a positive finite numeric known visible asset aspect ratio from COM')}
        }
        if($null -ne $asset.known_visible_aspect_ratio -and [double]$asset.known_visible_aspect_ratio -le 0){throw 'Invalid visible asset aspect ratio'}
        $texts+=[string]$asset.description
      }
    }
    if($panel.relationship -eq 'sum'){
      if(@($panel.steps).Count -ne 3){throw 'Sum relationship requires exactly three steps'}
      $sumIds=@()
      foreach($step in $panel.steps){
        $binding=[regex]::Match([string]$step,' \[\[([A-Za-z][A-Za-z0-9_-]*)\]\]$')
        $numberId=$binding.Groups[1].Value
        if(-not $binding.Success -or -not $Ledger.numbers.ContainsKey($numberId)){throw 'Sum step must match its number metric and binding'}
        $number=$Ledger.numbers[$numberId]
        if([string]$step -cne ([string]$number.metric+' [['+$numberId+']]')){throw 'Sum step must match its number metric and binding'}
        $sumIds+= [string]$number.id
      }
      if($sumIds[0] -eq $sumIds[1]){throw 'Sum relationship requires distinct input numbers'}
      $sum=$Ledger.numbers[$sumIds[2]]
      if($sum.kind -ne 'derived' -or $sum.formula -ne 'sum' -or @($sum.inputs).Count -ne 2 -or [string]$sum.inputs[0] -ine $sumIds[0] -or [string]$sum.inputs[1] -ine $sumIds[1]){throw 'Sum relationship total must derive from the first two numbers in order'}
      if($typedReference -and $panel.role -eq 'calculation' -and $sum.currency -cnotin @('USD','KRW')){throw ($Stage.layout_profile+' calculation requires a monetary sum with currency USD or KRW')}
    }
    foreach($text in $texts){
      if([string]::IsNullOrWhiteSpace([string]$text)){throw ('needs_input: blank panel content in '+$id)}
      $null=Convert-ProposalDisplayText ([string]$text) $Ledger.bindings ($id+'.panel.content')
      foreach($binding in [regex]::Matches([string]$text,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){
        $number=$Ledger.bindings[$binding.Groups[1].Value]
        $missingDerived=$number.kind -eq 'derived' -and @($number.source_ids|Where-Object {$_ -notin @($panel.source_ids)}).Count -gt 0
        if($missingDerived -or @($number.source_ids|Where-Object {$_ -in @($panel.source_ids)}).Count -eq 0){throw ('Panel number evidence is not included in source_ids: '+$id)}
      }
    }
  }
  $null=Assert-ProposalEvidenceLinks $Stage
  $null=Assert-ProposalStatementLinks $Stage
  return $true
}
function Assert-ProposalCase($Case,[switch]$AllowDraft){
  $ledger=Get-ProposalLedger $Case
  if(-not $AllowDraft){foreach($stage in @($Case.stages)){$null=Assert-ProposalStage $stage $ledger}}
  return $true
}
function Read-ProposalCase([string]$Path,[switch]$AllowDraft){
  Assert-ProposalJsonPath $Path
  $case=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json
  $null=Assert-ProposalCase $case -AllowDraft:$AllowDraft
  return $case
}
function Get-ProposalResolvedStage($Case,[string]$StageId){
  $ledger=Get-ProposalLedger $Case
  $raw=@($Case.stages|Where-Object {$_.id -ceq $StageId})
  if($raw.Count -ne 1){throw 'Stage missing or duplicated'}
  $null=Assert-ProposalStage $raw[0] $ledger
  if($raw[0].layout_profile -ceq 'reference-v5-problem'){. (Join-Path $PSScriptRoot 'Proposal.ProblemV5.ps1');return (Convert-ProposalProblemV5Stage $raw[0] $ledger)}
  $stage=$raw[0]|ConvertTo-Json -Depth 60|ConvertFrom-Json
  foreach($key in @('title','subtitle','takeaway','citation')){if($null -ne $stage.$key){$stage.$key=Convert-ProposalDisplayText ([string]$stage.$key) $ledger.bindings $key}}
  foreach($panel in @($stage.panels)){
    $panel.title=Convert-ProposalDisplayText ([string]$panel.title) $ledger.bindings 'panel title'
    if($null -ne $panel.outcome){$panel.outcome=Convert-ProposalDisplayText ([string]$panel.outcome) $ledger.bindings 'panel outcome'}
    foreach($key in @('lines','steps')){if($null -ne $panel.$key){$panel.$key=@($panel.$key|ForEach-Object {Convert-ProposalDisplayText ([string]$_) $ledger.bindings $key})}}
    if($panel.kind -eq 'table'){
      $panel.table.headers=@($panel.table.headers|ForEach-Object {Convert-ProposalDisplayText ([string]$_) $ledger.bindings 'table header'})
      $newRows=@();foreach($row in @($panel.table.rows)){$newRows+=,@($row|ForEach-Object {Convert-ProposalDisplayText ([string]$_) $ledger.bindings 'table cell'})};$panel.table.rows=$newRows
    }
    foreach($metric in @($panel.metrics)){if($null -ne $metric){foreach($key in @('label','value_text','detail')){if($null -ne $metric.$key){$metric.$key=Convert-ProposalDisplayText ([string]$metric.$key) $ledger.bindings 'metric'}}}}
    foreach($bar in @($panel.bars)){if($null -ne $bar){foreach($key in @('label','value_text')){$bar.$key=Convert-ProposalDisplayText ([string]$bar.$key) $ledger.bindings 'bar'};$bar|Add-Member -NotePropertyName ratio -NotePropertyValue ([double]$ledger.numbers[[string]$bar.number_id].value/100.0) -Force}}
    if($panel.kind -eq 'asset'){
      $panel.asset.description=Convert-ProposalDisplayText ([string]$panel.asset.description) $ledger.bindings 'asset description'
      if($stage.layout_profile -cin @('reference-v3','reference-v4','reference-v6') -and $null -eq $panel.asset.origin){$panel.asset|Add-Member -NotePropertyName origin -NotePropertyValue 'provided'}
    }
  }
  if($stage.layout_profile -ceq 'reference-v9' -and $StageId -ceq 'effects'){
    . (Join-Path $PSScriptRoot 'Proposal.EffectsV9.ps1')
    $stage.visuals|Add-Member -NotePropertyName resolved_metrics -NotePropertyValue @(Get-ProposalEffectsV9Numbers $raw[0] $ledger)
  }
  if($StageId -eq 'rollout' -and $stage.scope -eq 'proposal' -and $stage.subtitle -notlike '*검토안*적용 실적 아님*'){$stage.subtitle='검토안 · 적용 실적 아님 | '+$stage.subtitle}
  return $stage
}
function Get-ProposalNextStageId($State){
  foreach($id in $script:ProposalStageOrder){$entry=@($State.stages|Where-Object {$_.id -eq $id})[0];if($null -eq $entry -or $entry.status -ne 'complete'){return $id}}
  return $null
}
function Assert-ProposalStageOrder($State,[string]$StageId){
  $next=Get-ProposalNextStageId $State
  if(-not $next -or $next -ne $StageId){throw ('Stage order blocked; next='+$next+'; requested='+$StageId)}
}
function Assert-ProposalSaveReady($State){
  if(Get-ProposalNextStageId $State){throw 'Save blocked: required stages are incomplete'}
  if(-not $State.target_name){throw 'Save blocked: no bound open document'}
}
function Get-ProposalStateSummary($State){
  $sourceIds=@($State.ledger_added_source_ids|Where-Object {$null -ne $_});$numberIds=@($State.ledger_added_number_ids|Where-Object {$null -ne $_});$identifierIds=@($State.ledger_added_identifier_ids|Where-Object {$null -ne $_})
  return [pscustomobject]@{run_id=$State.run_id;target_name=$State.target_name;next_stage=(Get-ProposalNextStageId $State);status=$State.status;stages=@($State.stages|Select-Object id,status,slide_id,qa_status,qa_counts,last_repair,last_error);visual_qa='not_performed_policy';saved=$State.saved;ledger=[pscustomobject]@{case_id=$State.case_id;revision_count=$(if($null -ne $State.ledger_revision_count){$State.ledger_revision_count}else{0});current_file=$(if($State.current_case_file){$State.current_case_file}else{'case.json'});added_source_ids=@($sourceIds|Select-Object -First 8);added_number_ids=@($numberIds|Select-Object -First 8);added_identifier_ids=@($identifierIds|Select-Object -First 8);added_source_count=$sourceIds.Count;added_number_count=$numberIds.Count;added_identifier_count=$identifierIds.Count}}
}
function Get-ProposalRecordFingerprint($Record,[string]$Kind){
  $fields=if($Kind -eq 'source'){@('id','text','kind','url')}elseif($Kind -eq 'identifier'){@('id','value','source_ids')}else{@('id','kind','metric','value','unit','qualifier','currency','period','formula','inputs','source_ids')}
  $normal=[ordered]@{}
  foreach($field in $fields){
    if($field -in @('inputs','source_ids')){$normal[$field]=@($Record.$field|Where-Object {$null -ne $_}|ForEach-Object {[string]$_}|Sort-Object -CaseSensitive)}
    elseif($field -eq 'value' -and [string]$Record.$field -match '^-?\d+(?:\.\d+)?$'){$normal[$field]=([decimal]::Parse([string]$Record.$field,[Globalization.CultureInfo]::InvariantCulture)).ToString('G29',[Globalization.CultureInfo]::InvariantCulture)}
    else{$normal[$field]=[string]$Record.$field}
  }
  return ($normal|ConvertTo-Json -Depth 12 -Compress)
}
function Merge-ProposalLedger($Case,$Patch){
  $null=Assert-ProposalCase $Case -AllowDraft
  Assert-ProposalAllowedProperties $Patch @('sources','numbers','identifiers') 'ledger patch'
  $merged=$Case|ConvertTo-Json -Depth 60|ConvertFrom-Json
  $addedSources=@();$addedNumbers=@();$addedIdentifiers=@()
  foreach($group in @('sources','numbers','identifiers')){
    $kind=if($group -eq 'sources'){'source'}elseif($group -eq 'identifiers'){'identifier'}else{'number'}
    $allowed=if($kind -eq 'source'){@('id','text','kind','url')}elseif($kind -eq 'identifier'){@('id','value','source_ids')}else{@('id','value','unit','qualifier','currency','period','source_ids','metric','kind','formula','inputs')}
    if($group -notin @($merged.PSObject.Properties.Name)){$merged|Add-Member -NotePropertyName $group -NotePropertyValue @()}
    $existing=@{};foreach($record in @($Case.$group)){$existing[[string]$record.id]=$record}
    $seen=@{}
    foreach($record in @($Patch.$group|Where-Object {$null -ne $_})){
      Assert-ProposalAllowedProperties $record $allowed ('ledger '+$kind)
      Assert-ProposalId ([string]$record.id) $kind
      if($seen.ContainsKey([string]$record.id)){throw ('Duplicate ledger patch identifier: '+$record.id)}
      $seen[[string]$record.id]=$true
      if($existing.ContainsKey([string]$record.id)){
        if((Get-ProposalRecordFingerprint $record $kind) -cne (Get-ProposalRecordFingerprint $existing[[string]$record.id] $kind)){throw ('Immutable ledger record changed: '+$record.id)}
      }else{
        $merged.$group=@($merged.$group)+@($record)
        if($kind -eq 'source'){$addedSources+=[string]$record.id}elseif($kind -eq 'identifier'){$addedIdentifiers+=[string]$record.id}else{$addedNumbers+=[string]$record.id}
      }
    }
  }
  $null=Assert-ProposalCase $merged -AllowDraft
  return [pscustomobject]@{case=$merged;added_source_ids=$addedSources;added_number_ids=$addedNumbers;added_identifier_ids=$addedIdentifiers;changed=($addedSources.Count+$addedNumbers.Count+$addedIdentifiers.Count -gt 0)}
}
