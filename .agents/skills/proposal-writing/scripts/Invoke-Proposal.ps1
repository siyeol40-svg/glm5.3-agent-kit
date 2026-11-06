[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('init','status','context','prepare-problem','validate','render','repair','qa','save','update-ledger')][string]$Action,
  [Parameter(Mandatory)][string]$RunDir,
  [string]$CasePath,[ValidateSet('problem','cause','actions','effects','rollout')][string]$StageId,[string]$TargetName,[string]$SavePath,[string]$LedgerPath,
  [string]$BriefPath,[string]$FactsPath,[string]$SourceCaption,
  [switch]$AllowLegacyFixture
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Proposal.Core.ps1')
. (Join-Path $PSScriptRoot 'Proposal.Density.ps1')
. (Join-Path $PSScriptRoot 'Proposal.Terms.ps1')
$run=[IO.Path]::GetFullPath($RunDir)
$statePath=Join-Path $run 'state.json'
$state=$null;$activeEntry=$null;$sideEffectsStarted=$false
$repairEvent=$null;$repairEventPath='';$repairOriginalStatus=''
$utf8=[Text.UTF8Encoding]::new($false)
$validatingV5Draft=$false
$authorInputPattern='^(TEXT_NEEDS_SHORTEN: V5 invalid text slots|Unregistered raw number in |Malformed number binding in |Unknown number binding )'
function Write-JsonFile([string]$Path,$Value){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 60),$utf8)}
function Write-RunState([switch]$TolerateResumeFailure){
  $state.updated_at=[DateTimeOffset]::Now.ToString('o')
  $temp=Join-Path $run ('.state-'+[guid]::NewGuid().ToString('N')+'.tmp')
  try{
    Write-JsonFile $temp $state
    if([IO.File]::Exists($statePath)){[IO.File]::Replace($temp,$statePath,($statePath+'.previous.json'))}else{[IO.File]::Move($temp,$statePath)}
  }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
  $next=Get-ProposalNextStageId $state
  $resume=@(
    '# 제안 작성 재개',
    ('- run: '+$state.run_id),('- case: '+$state.case_id),('- 열린 문서: '+$state.target_name),
    ('- 다음 단계: '+$(if($next){$next}else{'모든 페이지 비시각 검사 완료'})),
    ('- 상태: '+$state.status),'- 시각/픽셀 QA: 정책상 미수행. 회사 DLP 호환성 별도 미검증.',
    '- 다음 단계 지침과 stages/<id>.json만 읽습니다. 전체 코드/과거 로그를 재독하지 않습니다.'
  )
  foreach($entry in @($state.stages)){
    $resume+=('- '+$entry.id+': '+$entry.status+$(if($entry.last_error){' / '+$entry.last_error}else{''}))
    if($entry.qa_counts){$resume+=('  - COM QA: '+$entry.qa_status+' / '+($entry.qa_counts|ConvertTo-Json -Compress))}
    if($entry.last_repair){$resume+=('  - repair: '+$entry.last_repair.status+' / '+$entry.last_repair.report_path)}
  }
  $revision=if($null -ne $state.ledger_revision_count){$state.ledger_revision_count}else{0}
  $currentFile=if($state.current_case_file){$state.current_case_file}else{'case.json'}
  $addedSourceIds=@($state.ledger_added_source_ids|Where-Object {$null -ne $_});$addedNumberIds=@($state.ledger_added_number_ids|Where-Object {$null -ne $_});$addedIdentifierIds=@($state.ledger_added_identifier_ids|Where-Object {$null -ne $_})
  $resume+=('- 원장 revision: '+$revision+' / '+$currentFile)
  $resume+=('- 마지막 추가: 근거 '+$addedSourceIds.Count+'개 ['+(@($addedSourceIds|Select-Object -First 8) -join ', ')+'], 수치 '+$addedNumberIds.Count+'개 ['+(@($addedNumberIds|Select-Object -First 8) -join ', ')+']')
  $resume+=('- 식별자 추가: '+$addedIdentifierIds.Count+'개 ['+(@($addedIdentifierIds|Select-Object -First 8) -join ', ')+']')
  try{[IO.File]::WriteAllText((Join-Path $run 'resume.md'),($resume -join [Environment]::NewLine),$utf8)}
  catch{if($TolerateResumeFailure){return ('State committed; resume write failed: '+$_.Exception.Message)};throw}
}
function Get-CurrentCaseFileName{
  $leaf=if($state.current_case_file){[string]$state.current_case_file}else{'case.json'}
  if($leaf -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.json$' -or [IO.Path]::GetFileName($leaf) -cne $leaf){throw 'Invalid local current_case_file name'}
  return $leaf
}
function Assert-WorkflowLayoutProfile($Case,[string]$Id=''){
  # Explicit developer replay only; this switch is never persisted as run authority.
  if($AllowLegacyFixture){return}
  foreach($stage in @($Case.stages)){
    if($Id -and $stage.id -cne $Id){continue}
    if((@($stage.panels|Where-Object {$null -ne $_}).Count -gt 0 -or $null -ne $stage.problem) -and [string]$stage.layout_profile -cnotin @('reference-v2','reference-v3','reference-v4','reference-v5-problem','reference-v6','reference-v7','reference-v8-actions','reference-v9','reference-v10-actions')){
      throw ('needs_input: '+$stage.id+' with panel content requires layout_profile reference-v2, reference-v3, reference-v4, reference-v5-problem, reference-v6, reference-v7, reference-v8-actions, reference-v9 or reference-v10-actions; legacy layout is limited to explicit developer fixture replay')
    }
  }
}
function Read-RunCase([string]$Id){
  $basePath=Join-Path $run (Get-CurrentCaseFileName)
  $raw=Get-Content -LiteralPath $basePath -Raw -Encoding UTF8
  if((Get-ProposalTextHash $raw) -ne $state.case_hash){throw 'Case ledger revision changed; create an explicit new run revision'}
  $case=$raw|ConvertFrom-Json
  if($Id){
    $stagePath=Join-Path (Join-Path $run 'stages') ($Id+'.json')
    $stage=Get-Content -LiteralPath $stagePath -Raw -Encoding UTF8|ConvertFrom-Json
    if($stage.id -cne $Id){throw 'Stage file identifier differs from requested stage'}
    $case.stages=@($case.stages|ForEach-Object {if($_.id -eq $Id){$stage}else{$_}})
  }
  $null=Assert-ProposalCase $case -AllowDraft
  if($Id){Assert-WorkflowLayoutProfile $case $Id}
  return $case
}
function Get-Entry([string]$Id){
  $entries=@($state.stages|Where-Object {$_.id -eq $Id})
  if($entries.Count -ne 1){throw 'Unknown stage state'}
  return $entries[0]
}
function Get-WorkflowStateSummary{
  $summary=Get-ProposalStateSummary $state
  $summary|Add-Member -NotePropertyName current_content_density_policy -NotePropertyValue (Get-ProposalDensityPolicy)
  $summary|Add-Member -NotePropertyName current_content_density_acceptance -NotePropertyValue 'not_recertified'
  $summary|Add-Member -NotePropertyName current_terminology_policy_version -NotePropertyValue (Get-ProposalTerminologyPolicy).policy_version
  $summary|Add-Member -NotePropertyName current_terminology_acceptance -NotePropertyValue 'not_recertified'
  return $summary
}
function Set-StageDensityReport($Entry,$Report){
  # Explicit members permit old schema states with no density fields to be checked.
  $Entry|Add-Member -NotePropertyName content_density -NotePropertyValue $Report -Force
  $Entry|Add-Member -NotePropertyName content_density_policy_version -NotePropertyValue $Report.policy_version -Force
  $state|Add-Member -NotePropertyName content_density_policy_version -NotePropertyValue $Report.policy_version -Force
}
function Set-StageTerminologyReport($Entry,$Report){
  $Entry|Add-Member -NotePropertyName terminology -NotePropertyValue $Report -Force
  $Entry|Add-Member -NotePropertyName terminology_policy_version -NotePropertyValue $Report.policy_version -Force
  $state|Add-Member -NotePropertyName terminology_policy_version -NotePropertyValue $Report.policy_version -Force
}
function Get-PreparedWorkflowStage($Case,[string]$Id){
  $rawStage=@($Case.stages|Where-Object {$_.id -ceq $Id})[0]
  $resolved=Get-ProposalResolvedStage $Case $Id
  . (Join-Path $PSScriptRoot 'Proposal.Layout.ps1')
  $shapes=@(Get-ProposalLayout $resolved)
  $entry=Get-Entry $Id
  try{$density=Assert-ProposalContentDensity $rawStage $resolved $shapes}
  catch{
    $report=$_.Exception.Data['report']
    if($report){Set-StageDensityReport $entry $report}
    throw
  }
  Set-StageDensityReport $entry $density
  try{$terminology=Assert-ProposalTerminology -Stage $resolved}
  catch{
    $report=$_.Exception.Data['terminology']
    if($report){Set-StageTerminologyReport $entry $report}
    throw
  }
  Set-StageTerminologyReport $entry $terminology
  return [pscustomobject]@{stage=$resolved;shapes=$shapes;content_density=$density;terminology=$terminology;content_hash=(Get-ProposalTextHash ($resolved|ConvertTo-Json -Depth 60 -Compress))}
}
function Find-ManagedSlide($Presentation,$Entry){
  if(-not $Entry.slide_id){throw 'No recorded managed slide for this stage'}
  for($i=1;$i -le $Presentation.Slides.Count;$i++){
    $slide=$Presentation.Slides.Item([int]$i)
    if($slide.SlideID -eq $Entry.slide_id){return ,$slide}
  }
  throw 'Recorded slide no longer exists in the named open document'
}
function Get-BoundPresentation{
  $name=if($TargetName){$TargetName}else{$state.target_name}
  if(-not $name){throw 'TargetName of an already open working document is required'}
  if($state.target_name -and $name -ne $state.target_name -and $name -ne $state.target_fullname){throw 'Target document changed within this run'}
  return ,(Get-ProposalPowerPoint $name)
}
function Update-StageQa($Presentation,$Entry,$Prepared){
  $hash=$Prepared.content_hash
  if($Entry.content_hash -and $Entry.content_hash -ne $hash){throw 'Stage data changed after rendering; explicit new revision required'}
  $shapes=@($Prepared.shapes)
  $slide=Find-ManagedSlide $Presentation $Entry
  $qa=Get-ProposalSlideQa $slide $shapes
  Write-JsonFile (Join-Path $run ('qa-'+$Entry.id+'.json')) $qa
  $Entry.qa_status=$qa.status;$Entry.qa_counts=$qa.counts
  if($qa.status -eq 'pass_with_limitations'){$Entry.status='complete';$Entry.last_error=''}else{$Entry.status=$(if($qa.status -eq 'unknown'){'unknown'}else{'failed'});$Entry.last_error=(@($qa.errors)+@($qa.unknowns) -join '; ')}
  return $qa
}
try{
  if($Action -eq 'init'){
    if(-not $CasePath){throw 'CasePath is required for init'}
    if([IO.Directory]::Exists($run) -and @(Get-ChildItem -LiteralPath $run -Force).Count){throw 'RunDir is not empty; never overwrite an existing run'}
    $case=Read-ProposalCase $CasePath -AllowDraft
    Assert-WorkflowLayoutProfile $case
    if(-not [IO.Directory]::Exists($run)){$null=[IO.Directory]::CreateDirectory($run)}
    $null=[IO.Directory]::CreateDirectory((Join-Path $run 'stages'))
    $null=[IO.Directory]::CreateDirectory((Join-Path $run 'sources'))
    Write-JsonFile (Join-Path $run 'case.json') $case
    foreach($stage in @($case.stages)){Write-JsonFile (Join-Path (Join-Path $run 'stages') ($stage.id+'.json')) $stage}
    foreach($source in @($case.sources)){Write-JsonFile (Join-Path (Join-Path $run 'sources') ($source.id+'.json')) $source}
    $raw=Get-Content -LiteralPath (Join-Path $run 'case.json') -Raw -Encoding UTF8
    $entries=@($script:ProposalStageOrder|ForEach-Object {[pscustomobject]@{id=$_;status='pending';content_hash='';slide_id=$null;slide_index=$null;qa_status='not_run';qa_counts=$null;content_density=$null;content_density_policy_version='';last_error=''}})
    $state=[pscustomobject]@{schema_version='1.1';content_density_policy_version=(Get-ProposalDensityPolicy).policy_version;run_id=($case.case_id+'-'+[guid]::NewGuid().ToString('N').Substring(0,10));case_id=$case.case_id;case_hash=(Get-ProposalTextHash $raw);current_case_file='case.json';ledger_revision_count=0;ledger_added_source_ids=@();ledger_added_number_ids=@();ledger_added_identifier_ids=@();target_name=$TargetName;target_fullname='';status='initialized';stages=$entries;visual_qa='not_performed_policy';saved=$false;saved_path='';save_intent_path='';save_reopen_status='not_tested';created_at=[DateTimeOffset]::Now.ToString('o');updated_at=''}
    Write-RunState
    Get-WorkflowStateSummary|ConvertTo-Json -Depth 8
    exit 0
  }
  $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
  $requested=if($StageId){$StageId}else{Get-ProposalNextStageId $state}
  switch($Action){
    'status' {Get-WorkflowStateSummary|ConvertTo-Json -Depth 8;exit 0}
    'update-ledger' {
      if(-not $LedgerPath){throw 'LedgerPath is required for update-ledger'}
      Assert-ProposalJsonPath $LedgerPath
      $currentCase=Read-RunCase ''
      $patch=Get-Content -LiteralPath $LedgerPath -Raw -Encoding UTF8|ConvertFrom-Json
      $merge=Merge-ProposalLedger $currentCase $patch
      $revision=if($null -ne $state.ledger_revision_count){[int]$state.ledger_revision_count}else{0}
      if(-not $merge.changed){[pscustomobject]@{status='ledger_unchanged';revision_count=$revision;current_case_file=(Get-CurrentCaseFileName);added_source_ids=@();added_number_ids=@();added_identifier_ids=@()}|ConvertTo-Json;exit 0}
      foreach($entry in @($state.stages|Where-Object {$_.status -eq 'complete'})){
        if(-not $entry.content_hash){throw 'Completed stage lacks its content hash; inspect the run before updating ledger'}
        $beforeCase=Read-RunCase $entry.id
        $before=Get-ProposalResolvedStage $beforeCase $entry.id
        $beforeHash=Get-ProposalTextHash ($before|ConvertTo-Json -Depth 60 -Compress)
        if($beforeHash -ne $entry.content_hash){throw ('Completed stage data changed before ledger update: '+$entry.id)}
        $afterCase=$merge.case|ConvertTo-Json -Depth 60|ConvertFrom-Json
        $liveStage=@($beforeCase.stages|Where-Object {$_.id -eq $entry.id})[0]
        $afterCase.stages=@($afterCase.stages|ForEach-Object {if($_.id -eq $entry.id){$liveStage}else{$_}})
        $after=Get-ProposalResolvedStage $afterCase $entry.id
        if((Get-ProposalTextHash ($after|ConvertTo-Json -Depth 60 -Compress)) -ne $beforeHash){throw ('Ledger append changes completed stage output: '+$entry.id)}
      }
      $leaf='case-revision-'+[guid]::NewGuid().ToString('N')+'.json'
      $newCasePath=Join-Path $run $leaf
      $newRaw=$merge.case|ConvertTo-Json -Depth 60
      $bytes=$utf8.GetBytes($newRaw)
      $stream=[IO.File]::Open($newCasePath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
      # Read/validate the new ordinary JSON before committing its state pointer.
      $null=Read-ProposalCase $newCasePath -AllowDraft
      $newRaw=Get-Content -LiteralPath $newCasePath -Raw -Encoding UTF8
      foreach($id in @($merge.added_source_ids)){
        $source=@($merge.case.sources|Where-Object {$_.id -eq $id})[0]
        $cachePath=Join-Path (Join-Path $run 'sources') ($id+'.json')
        if([IO.File]::Exists($cachePath)){
          $cached=Get-Content -LiteralPath $cachePath -Raw -Encoding UTF8|ConvertFrom-Json
          if((Get-ProposalRecordFingerprint $cached 'source') -cne (Get-ProposalRecordFingerprint $source 'source')){throw ('Source cache collision; old ledger remains active: '+$id)}
        }else{Write-JsonFile $cachePath $source}
      }
      $oldState=$state
      $nextState=$state|ConvertTo-Json -Depth 60|ConvertFrom-Json
      foreach($pair in @(
        @('current_case_file',$leaf),@('case_hash',(Get-ProposalTextHash $newRaw)),@('ledger_revision_count',($revision+1)),
        @('ledger_added_source_ids',@($merge.added_source_ids)),@('ledger_added_number_ids',@($merge.added_number_ids)),@('ledger_added_identifier_ids',@($merge.added_identifier_ids))
      )){$nextState|Add-Member -NotePropertyName $pair[0] -NotePropertyValue $pair[1] -Force}
      $state=$nextState
      try{$resumeWarning=Write-RunState -TolerateResumeFailure}catch{$state=$oldState;throw ('Ledger state commit failed; original ledger remains active; uncommitted file '+$leaf+': '+$_.Exception.Message)}
      [pscustomobject]@{status=$(if($resumeWarning){'ledger_updated_with_resume_warning'}else{'ledger_updated'});revision_count=($revision+1);current_case_file=$leaf;added_source_ids=@($merge.added_source_ids|Select-Object -First 8);added_number_ids=@($merge.added_number_ids|Select-Object -First 8);added_identifier_ids=@($merge.added_identifier_ids|Select-Object -First 8);counts=[pscustomobject]@{sources=$merge.added_source_ids.Count;numbers=$merge.added_number_ids.Count;identifiers=$merge.added_identifier_ids.Count};warning=[string]$resumeWarning}|ConvertTo-Json -Depth 6
      exit 0
    }
    'context' {
      if(-not $requested){[pscustomobject]@{next_stage=$null;module='references/06-finalize.md';status=$state.status;current_content_density_policy=(Get-ProposalDensityPolicy);current_content_density_acceptance='not_recertified'}|ConvertTo-Json -Depth 8;exit 0}
      $case=Read-RunCase $requested;$ledger=Get-ProposalLedger $case;$stage=@($case.stages|Where-Object {$_.id -eq $requested})[0]
      $refs=@($stage.source_ids)+@($stage.panels|ForEach-Object {$_.source_ids})
      $selected=@($case.sources|Where-Object {$_.id -in $refs})
      $sourceIndex=@($case.sources|ForEach-Object {[pscustomobject]@{id=$_.id;kind=$_.kind;summary=$_.text.Substring(0,[math]::Min(100,$_.text.Length));path=('sources/'+$_.id+'.json')}})
      $bindings=[regex]::Matches(($stage|ConvertTo-Json -Depth 40),'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')|ForEach-Object {$_.Groups[1].Value}|Select-Object -Unique
      $numberIndex=@($ledger.numbers.Values|Where-Object {@($bindings).Count -eq 0 -or $_.id -in $bindings}|Select-Object id,metric,display,source_ids)
      $identifierIndex=@($ledger.identifiers.Values|Where-Object {$_.id -in @($bindings)}|Select-Object id,value,source_ids)
      $modules=@{problem='01-problem.md';cause='02-cause.md';actions='03-actions.md';effects='04-effects.md';rollout='05-rollout.md'}
      if($stage.layout_profile -ceq 'reference-v5-problem'){$modules.problem='v5/problem.md'}
      if($stage.layout_profile -ceq 'reference-v6'){$modules[$requested]='v6/'+$requested+'.md'}
      if($stage.layout_profile -ceq 'reference-v7'){$modules[$requested]='v7/'+$requested+'.md'}
      if($stage.layout_profile -ceq 'reference-v8-actions'){$modules[$requested]='v8/actions.md'}
      if($stage.layout_profile -ceq 'reference-v9'){$modules[$requested]='v9/'+$requested+'.md'}
      if($stage.layout_profile -ceq 'reference-v10-actions'){$modules[$requested]='v10/actions.md'}
      $context=[pscustomobject]@{run_id=$state.run_id;next_stage=(Get-ProposalNextStageId $state);requested_stage=$requested;stage_state=(Get-Entry $requested).status;module=('references/'+$modules[$requested]);stage_file=('stages/'+$requested+'.json');stage=$stage;sources=$selected;source_index=$(if($selected.Count -eq 0){$sourceIndex}else{@()});numbers=$numberIndex;identifiers=$identifierIndex;current_content_density_policy=(Get-ProposalDensityPolicy);current_content_density_acceptance='not_recertified';visual_qa='not_performed_policy'}
      $contextJson=$context|ConvertTo-Json -Depth 30
      if($contextJson.Length -gt 8000){
        [pscustomobject]@{status='needs_split';stage=$requested;characters=$contextJson.Length;module=$context.module;layout_profile=$stage.layout_profile;stage_file=$context.stage_file;source_files=@($selected|ForEach-Object {'sources/'+$_.id+'.json'});number_ids=@($numberIndex.id);current_content_density_policy=$context.current_content_density_policy;current_content_density_acceptance='not_recertified';message='Read only the selected source files and current stage in smaller parts; no silent truncation'}|ConvertTo-Json -Depth 6 -Compress
        exit 3
      }
      Write-Output $contextJson
      exit 0
    }
    'prepare-problem' {
      if($StageId -and $StageId -cne 'problem'){throw 'prepare-problem only accepts the problem stage'}
      if(-not $BriefPath -or -not $FactsPath){throw 'BriefPath and FactsPath are required'}
      Assert-ProposalStageOrder $state 'problem'
      $entry=Get-Entry 'problem'
      if($entry.status -notin @('pending','needs_input') -or $entry.qa_status -ne 'not_run' -or $entry.slide_id -or $entry.content_hash){
        throw 'Problem stage has already reached production or requires inspection'
      }
      Assert-ProposalJsonPath $BriefPath
      Assert-ProposalJsonPath $FactsPath
      $brief=Get-Content -LiteralPath $BriefPath -Raw -Encoding UTF8|ConvertFrom-Json
      $factIndex=@(Get-Content -LiteralPath $FactsPath -Raw -Encoding UTF8|ConvertFrom-Json)
      $case=Read-RunCase ''
      . (Join-Path $PSScriptRoot 'Proposal.ProblemV5.ps1')
      . (Join-Path $PSScriptRoot 'Proposal.ProblemAuthor.ps1')
      $draft=ConvertTo-ProposalV5ProcedureTableStage $brief $factIndex @($case.numbers.id) $SourceCaption
      $case.stages[0]=$draft
      $prepared=Get-PreparedWorkflowStage $case 'problem'

      $stagePath=Join-Path $run 'stages/problem.json'
      $lockPath=Join-Path $run '.prepare-problem.lock'
      $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      $temp=Join-Path $run ('problem-'+[guid]::NewGuid().ToString('N')+'.tmp')
      try{
        $stub=Get-Content -LiteralPath $stagePath -Raw -Encoding UTF8|ConvertFrom-Json
        if($stub.id -cne 'problem' -or $stub.layout_profile -notin @($null,'reference-v5-problem') -or @($stub.PSObject.Properties.Name|Where-Object {$_ -cnotin @('id','layout_profile')}).Count){
          throw 'Existing problem stage is not an empty authoring stub; preserve it in this run'
        }
        Write-JsonFile $temp $draft
        [IO.File]::Replace($temp,$stagePath,($temp+'.stub'))
        [IO.File]::Delete(($temp+'.stub'))
      }finally{
        $lock.Dispose()
        [IO.File]::Delete($temp)
        [IO.File]::Delete($lockPath)
      }
      [pscustomobject]@{
        status='problem_prepared';stage='problem';stage_file='stages/problem.json'
        density_count=$prepared.content_density.counted;minimum=$prepared.content_density.minimum
        content_hash=$prepared.content_hash;office_calls=0
      }|ConvertTo-Json -Compress
      exit 0
    }
    'validate' {
      if(-not $requested){throw 'StageId is required after all stages are complete'}
      $activeEntry=Get-Entry $requested
      $case=Read-RunCase $requested
      $stage=@($case.stages|Where-Object {$_.id -ceq $requested})[0]
      $validatingV5Draft=(
        $stage.layout_profile -ceq 'reference-v5-problem' -and
        $activeEntry.status -in @('pending','needs_input') -and
        $activeEntry.qa_status -eq 'not_run' -and
        -not $activeEntry.slide_id -and -not $activeEntry.content_hash
      )
      $prepared=Get-PreparedWorkflowStage $case $requested
      if($validatingV5Draft -and $activeEntry.last_error -match ('^needs_input: '+$authorInputPattern.Substring(1))){
        $activeEntry.status='pending';$activeEntry.last_error=''
        if($state.status -eq 'needs_input' -and -not @($state.stages|Where-Object {$_.status -ne 'pending'}).Count){$state.status='initialized'}
      }
      Write-RunState
      [pscustomobject]@{status='data_valid';stage=$requested;content_hash=$prepared.content_hash;content_density=$prepared.content_density;terminology=$prepared.terminology;office_calls=0}|ConvertTo-Json -Depth 12
      exit 0
    }
    'render' {
      if(-not $requested){throw 'All stages already complete; use qa or save'}
      Assert-ProposalStageOrder $state $requested
      $candidateEntry=Get-Entry $requested
      if($candidateEntry.status -in @('rendering','failed','unknown')){throw 'Previous render attempt is unresolved; inspect QA or create an explicit new revision, never blindly retry'}
      $activeEntry=$candidateEntry
      $case=Read-RunCase $requested;$prepared=Get-PreparedWorkflowStage $case $requested;$resolved=$prepared.stage;$shapes=@($prepared.shapes)
      . (Join-Path $PSScriptRoot 'Proposal.Com.ps1')
      $pres=Get-BoundPresentation
      $state.target_name=$pres.Name;$state.target_fullname=$pres.FullName
      $activeEntry.status='rendering';$activeEntry.content_hash=$prepared.content_hash;$state.status='working'
      Write-RunState
      $sideEffectsStarted=$true
      $slide=Add-ProposalStageSlide $pres $resolved $shapes $state.run_id $activeEntry.content_hash
      $activeEntry.slide_id=$slide.SlideID;$activeEntry.slide_index=$slide.SlideIndex
      $qa=Get-ProposalSlideQa $slide $shapes
      Write-JsonFile (Join-Path $run ('qa-'+$requested+'.json')) $qa
      $activeEntry.qa_status=$qa.status;$activeEntry.qa_counts=$qa.counts
      if($qa.status -eq 'pass_with_limitations'){$activeEntry.status='complete';$activeEntry.last_error='';$state.status=$(if(Get-ProposalNextStageId $state){'working'}else{'structure_checked_with_limitations'})}
      else{$activeEntry.status=$(if($qa.status -eq 'unknown'){'unknown'}else{'failed'});$activeEntry.last_error=(@($qa.errors)+@($qa.unknowns) -join '; ');$state.status='blocked'}
      Write-RunState
      [pscustomobject]@{stage=$requested;status=$activeEntry.status;qa_status=$qa.status;counts=$qa.counts;next_stage=(Get-ProposalNextStageId $state);visual_qa='not_performed_policy'}|ConvertTo-Json -Depth 10
      if($activeEntry.status -ne 'complete'){exit 2};exit 0
    }
    'repair' {
      if(-not $StageId){throw 'StageId is required for repair'}
      $candidateEntry=Get-Entry $StageId
      if($candidateEntry.status -notin @('complete','failed') -or -not $candidateEntry.slide_id){throw 'Repair requires a recorded complete or current failed stage with slide_id'}
      if($candidateEntry.status -eq 'failed' -and (Get-ProposalNextStageId $state) -ne $StageId){throw 'Repair is permitted only for a completed stage or the current failed stage'}
      $activeEntry=$candidateEntry;$repairOriginalStatus=[string]$activeEntry.status
      $case=Read-RunCase $StageId;$resolved=Get-ProposalResolvedStage $case $StageId
      $contentHash=Get-ProposalTextHash ($resolved|ConvertTo-Json -Depth 60 -Compress)
      if(-not $activeEntry.content_hash -or $activeEntry.content_hash -cne $contentHash){throw 'Repair does not allow content changes; restore the original stage input or create a new run'}
      . (Join-Path $PSScriptRoot 'Proposal.Layout.ps1')
      $shapes=@(Get-ProposalLayout $resolved)
      if(@($shapes|Where-Object {$_.kind -eq 'asset'}).Count){throw 'ASSET_REPAIR_UNSUPPORTED: existing media objects require a new run'}
      # Pure repair eligibility guards retain their original order. Every repair
      # that can reach Office still passes the same mandatory preparation gate.
      $prepared=Get-PreparedWorkflowStage $case $StageId;$resolved=$prepared.stage;$shapes=@($prepared.shapes)
      . (Join-Path $PSScriptRoot 'Proposal.Com.ps1')
      $pres=Get-BoundPresentation;$existingSlide=Find-ManagedSlide $pres $activeEntry
      $slideId=[int]$activeEntry.slide_id;$eventId=[guid]::NewGuid().ToString('N')
      $beforeLeaf='qa-'+$StageId+'-before-repair-'+$eventId+'.json';$afterLeaf='qa-'+$StageId+'-after-repair-'+$eventId+'.json'
      # This is a fresh measurement against the fixed layout, not an invented historical result.
      $beforeQa=Get-ProposalSlideQa $existingSlide $shapes
      Write-JsonFile (Join-Path $run $beforeLeaf) $beforeQa
      $repairEventPath=Join-Path $run ('repair-'+$StageId+'-'+$eventId+'.json')
      $repairEvent=[pscustomobject]@{event_id=$eventId;stage=$StageId;slide_id=$slideId;content_hash=$contentHash;status='prepared';qa_before_path=$beforeLeaf;qa_after_path='';created_at=[DateTimeOffset]::Now.ToString('o');completed_at='';error=''}
      Write-JsonFile $repairEventPath $repairEvent
      $activeEntry|Add-Member -NotePropertyName last_repair -NotePropertyValue ([pscustomobject]@{status='prepared';report_path=[IO.Path]::GetFileName($repairEventPath)}) -Force
      $activeEntry.status='repairing';$state.status='working';Write-RunState
      $sideEffectsStarted=$true
      $state.saved=$false
      $slide=Repair-ProposalStageSlide $pres $resolved $shapes $state.run_id $contentHash
      if([int]$slide.SlideID -ne $slideId){throw 'Repair returned a different slide; the recorded ownership was preserved and inspection is required'}
      $activeEntry.slide_index=$slide.SlideIndex
      $qa=Get-ProposalSlideQa $slide $shapes
      Write-JsonFile (Join-Path $run $afterLeaf) $qa
      Write-JsonFile (Join-Path $run ('qa-'+$StageId+'.json')) $qa
      $activeEntry.qa_status=$qa.status;$activeEntry.qa_counts=$qa.counts
      if($qa.status -eq 'pass_with_limitations'){$activeEntry.status='complete';$activeEntry.last_error='';$state.status=$(if(Get-ProposalNextStageId $state){'working'}else{'structure_checked_with_limitations'})}
      else{$activeEntry.status=$(if($qa.status -eq 'unknown'){'unknown'}else{'failed'});$activeEntry.last_error=(@($qa.errors)+@($qa.unknowns) -join '; ');$state.status='blocked'}
      $repairEvent.status=$activeEntry.status;$repairEvent.qa_after_path=$afterLeaf;$repairEvent.completed_at=[DateTimeOffset]::Now.ToString('o')
      Write-JsonFile $repairEventPath $repairEvent
      $activeEntry.last_repair.status=$repairEvent.status;Write-RunState
      [pscustomobject]@{stage=$StageId;status=$activeEntry.status;qa_status=$qa.status;counts=$qa.counts;next_stage=(Get-ProposalNextStageId $state);slide_id=$slideId;report_path=[IO.Path]::GetFileName($repairEventPath);visual_qa='not_performed_policy'}|ConvertTo-Json -Depth 8
      if($activeEntry.status -ne 'complete'){exit 2};exit 0
    }
    'qa' {
      if(-not $StageId){throw 'StageId is required for qa'}
      $activeEntry=Get-Entry $StageId;$case=Read-RunCase $StageId;$prepared=Get-PreparedWorkflowStage $case $StageId
      . (Join-Path $PSScriptRoot 'Proposal.Com.ps1')
      $pres=Get-BoundPresentation;$qa=Update-StageQa $pres $activeEntry $prepared
      $state.status=$(if($qa.status -eq 'pass_with_limitations'){$(if(Get-ProposalNextStageId $state){'working'}else{'structure_checked_with_limitations'})}else{'blocked'})
      Write-RunState
      [pscustomobject]@{stage=$StageId;status=$activeEntry.status;counts=$qa.counts;visual_qa='not_performed_policy'}|ConvertTo-Json -Depth 8
      if($activeEntry.status -ne 'complete'){exit 2};exit 0
    }
    'save' {
      # Check every live stage input before any Office connection, including historical runs.
      $preparedStages=@{}
      foreach($entry in @($state.stages)){$activeEntry=$entry;$case=Read-RunCase $entry.id;$preparedStages[$entry.id]=Get-PreparedWorkflowStage $case $entry.id}
      $activeEntry=$null
      Assert-ProposalSaveReady $state
      if(-not $SavePath){throw 'Explicit SavePath is required; no implicit save'}
      $destination=[IO.Path]::GetFullPath($SavePath)
      if([IO.Path]::GetExtension($destination) -ine '.pptx'){throw 'SavePath must be an explicit .pptx path'}
      if([IO.File]::Exists($destination)){throw 'SavePath already exists; choose a new output name'}
      if(-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($destination))){throw 'SavePath directory does not exist'}
      . (Join-Path $PSScriptRoot 'Proposal.Com.ps1')
      $pres=Get-BoundPresentation
      foreach($entry in @($state.stages)){
        $activeEntry=$entry;$qa=Update-StageQa $pres $entry $preparedStages[$entry.id]
        if($qa.status -ne 'pass_with_limitations'){$state.status='blocked';Write-RunState;throw 'Final QA blocked save'}
      }
      $state|Add-Member -NotePropertyName save_intent_path -NotePropertyValue $destination -Force
      $state.status='saving';Write-RunState
      $pres.SaveAs($destination,[int]24)
      $state.saved=$true;$state.saved_path=$pres.FullName;$state.target_name=$pres.Name;$state.target_fullname=$pres.FullName;$state.status='saved_with_nonvisual_limitations'
      # Current-object readback is separate from a future user UI reopen.
      $activeEntry=$null
      foreach($entry in @($state.stages)){$qa=Update-StageQa $pres $entry $preparedStages[$entry.id];if($qa.status -ne 'pass_with_limitations'){$state.status='saved_readback_failed';Write-RunState;throw 'Saved but current-object readback failed'}}
      Write-RunState
      [pscustomobject]@{status=$state.status;path=$state.saved_path;current_object_readback='checked';manual_reopen='not_tested';visual_qa='not_performed_policy'}|ConvertTo-Json
      exit 0
    }
  }
}catch{
  $message=$_.Exception.Message
  $textFit=$null
  if($Action -in @('validate','prepare-problem')){
    $issues=@($_.Exception.Data['text_errors']|Where-Object {$null -ne $_})
    if($issues.Count){
      $slots=@($issues|Select-Object -First 8|ForEach-Object {
        $slot=[pscustomobject]@{slot=$_.slot;required_lines=$_.required_lines;allowed_lines=$_.allowed_lines}
        if($null -ne $_.required_word_width){
          $slot|Add-Member -NotePropertyName required_word_width -NotePropertyValue ([math]::Round($_.required_word_width,1))
          $slot|Add-Member -NotePropertyName allowed_word_width -NotePropertyValue ([math]::Round(($_.width-2),1))
        }elseif($_.slot -ceq 'evidence-table'){
          $slot|Add-Member -NotePropertyName constraint -NotePropertyValue 'table_height'
        }elseif($_.reason -like 'V5_LAYOUT_EMPTY:*'){
          $slot|Add-Member -NotePropertyName constraint -NotePropertyValue 'required_text'
        }
        $slot
      })
      $textFit=[pscustomobject]@{count=$issues.Count;slots=$slots}
      $message=($message -split '\r?\n',2)[0]
    }
  }
  if($state -and $Action -in @('validate','render','repair','qa','save') -and ($activeEntry -or $Action -eq 'save')){
    if($validatingV5Draft -and $message -match $authorInputPattern){
      $message='needs_input: '+$message
      $activeEntry.status='needs_input';$activeEntry.last_error=$message
      if($state.status -eq 'initialized'){$state.status='needs_input'}
    }elseif($message -match 'CONTENT_DENSITY_(BELOW_MINIMUM|NOT_VISIBLE)|TERMINOLOGY_NEEDS_ENGLISH'){
      if($activeEntry){
        if($activeEntry.status -ne 'needs_input'){$activeEntry|Add-Member -NotePropertyName previous_status -NotePropertyValue $activeEntry.status -Force}
        $activeEntry.status='needs_input';$activeEntry.last_error=$message
      }
      $state.status='needs_input'
    }elseif($Action -in @('render','repair') -and -not $sideEffectsStarted){
      if($message -notlike 'needs_input:*'){$message='needs_input: '+$message}
      if($activeEntry){$activeEntry.status=$(if($Action -eq 'repair'){$repairOriginalStatus}else{'needs_input'});$activeEntry.last_error=$message}
      $state.status='needs_input'
    }else{
      if($activeEntry -and ($activeEntry.status -ne 'complete' -or $Action -eq 'repair')){$activeEntry.status=$(if($message -like 'needs_input:*'){'needs_input'}else{'failed'});$activeEntry.last_error=$message}
      if($state.status -notin @('saved_readback_failed','saved_with_nonvisual_limitations')){$state.status='blocked'}
    }
    if($repairEvent){
      $repairEvent.status=$(if($sideEffectsStarted){'failed_after_repair_call'}else{'failed_before_repair_call'});$repairEvent.completed_at=[DateTimeOffset]::Now.ToString('o');$repairEvent.error=$message
      if($activeEntry.last_repair){$activeEntry.last_repair.status=$repairEvent.status}
      try{Write-JsonFile $repairEventPath $repairEvent}catch{$message+='; repair event write failed: '+$_.Exception.Message}
    }
    try{Write-RunState}catch{$message+='; state write failed: '+$_.Exception.Message}
  }
  $report=[pscustomobject]@{status=$(if($message -like 'needs_input:*'){'needs_input'}else{'error'});action=$Action;stage=$StageId;error=$message;terminology=$_.Exception.Data['terminology'];save_completed=$(if($state){[bool]$state.saved}else{$false});saved_path=$(if($state){$state.saved_path}else{''});save_intent_path=$(if($state){$state.save_intent_path}else{''});visual_qa='not_performed_policy'}
  if($Action -ceq 'prepare-problem'){$report.stage='problem';$report|Add-Member -NotePropertyName office_calls -NotePropertyValue 0}
  if($textFit){$report|Add-Member -NotePropertyName text_fit -NotePropertyValue $textFit}
  $report|ConvertTo-Json -Depth 7
  Write-Error -Message $message -ErrorAction Continue
  exit 2
}
