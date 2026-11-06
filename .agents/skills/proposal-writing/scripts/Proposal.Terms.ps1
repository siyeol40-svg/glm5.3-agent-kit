# Fixed-glossary checks of resolved business text only. No Office/media/network IO.
function Get-ProposalTerminologyPolicy {
    [CmdletBinding()]param()
    $path=Join-Path $PSScriptRoot '../assets/terminology-policy.json'
    $policy=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
    if($policy.policy_version -cne 'ko-en-nouns-v1' -or @($policy.terms).Count -lt 1){throw 'TERMINOLOGY_POLICY_UNSUPPORTED: invalid fixed glossary'}
    foreach($term in @($policy.terms)){
        if($term.english -isnot [string] -or [string]::IsNullOrWhiteSpace($term.english) -or @($term.korean).Count -lt 1){throw 'TERMINOLOGY_POLICY_UNSUPPORTED: invalid glossary term'}
        foreach($alias in @($term.korean)){if($alias -isnot [string] -or [string]::IsNullOrWhiteSpace($alias)){throw 'TERMINOLOGY_POLICY_UNSUPPORTED: invalid Korean alias'}}
    }
    return $policy
}
function Get-ProposalTerminologyReport {
    [CmdletBinding()]param([Parameter(Mandatory)][object]$Stage)
    $policy=Get-ProposalTerminologyPolicy
    $leaves=[Collections.Generic.List[object]]::new()
    function Add-TermText([string]$Path,$Value){
        if($null -eq $Value){return}
        if($Value -isnot [string]){throw ('TERMINOLOGY_INPUT_UNSUPPORTED: non-string visible field '+$Path)}
        if(-not [string]::IsNullOrWhiteSpace($Value)){$leaves.Add([pscustomobject]@{path=$Path;text=$Value})}
    }
    function Add-TermStrings([string]$Path,$Values){for($i=0;$i -lt @($Values).Count;$i++){Add-TermText ($Path+'['+$i+']') @($Values)[$i]}}
    function Add-TermTable([string]$Path,$Table){
        if($null -eq $Table){return}
        Add-TermStrings ($Path+'.headers') $Table.headers
        $rows=@($Table.rows)
        for($r=0;$r -lt $rows.Count;$r++){Add-TermStrings ($Path+'.rows['+$r+']') @($rows[$r])}
    }
    $base=[string]$Stage.id
    foreach($field in @('title','subtitle','takeaway','citation')){Add-TermText ($base+'.'+$field) $Stage.$field}
    if($Stage.layout_profile -ceq 'reference-v10-actions'){
        Add-TermStrings ($base+'.visuals.group_titles') $Stage.visuals.group_titles
    }
    if($Stage.layout_profile -ceq 'reference-v5-problem'){
        $p=$Stage.problem
        foreach($name in @('comparison','path','evidence','impact')){foreach($field in @('title','note')){Add-TermText ($base+'.problem.'+$name+'.'+$field) $p.$name.$field}}
        foreach($name in @('baseline','observed')){
            Add-TermText ($base+'.problem.comparison.'+$name+'.title') $p.comparison.$name.title
            Add-TermStrings ($base+'.problem.comparison.'+$name+'.items') $p.comparison.$name.items
        }
        $steps=@($p.path.steps)
        for($i=0;$i -lt $steps.Count;$i++){foreach($field in @('title','detail')){Add-TermText ($base+'.problem.path.steps['+$i+'].'+$field) $steps[$i].$field}}
        if($p.evidence.kind -ceq 'table'){Add-TermTable ($base+'.problem.evidence.table') $p.evidence.table}
        elseif($p.evidence.kind -ceq 'asset'){Add-TermText ($base+'.problem.evidence.asset.description') $p.evidence.asset.description}
        if($null -ne $p.overview_photo){Add-TermText ($base+'.problem.overview_photo.asset.description') $p.overview_photo.asset.description}
        $groups=@($p.impact.groups)
        for($i=0;$i -lt $groups.Count;$i++){
            Add-TermText ($base+'.problem.impact.groups['+$i+'].title') $groups[$i].title
            Add-TermStrings ($base+'.problem.impact.groups['+$i+'].lines') $groups[$i].lines
        }
    }else{
        # V7 and explicit V8 actions reuse visible V6 panel fields. V7 visuals selects fixed
        # semantics and relationships; it is metadata, never visible business text.
        $panels=@($Stage.panels)
        for($i=0;$i -lt $panels.Count;$i++){
            $p=$panels[$i];$path=$base+'.panels['+$i+']'
            foreach($field in @('title','outcome')){Add-TermText ($path+'.'+$field) $p.$field}
            switch([string]$p.kind){
                'bullets' {Add-TermStrings ($path+'.lines') $p.lines}
                'flow' {Add-TermStrings ($path+'.steps') $p.steps}
                'timeline' {Add-TermStrings ($path+'.steps') $p.steps}
                'table' {Add-TermTable ($path+'.table') $p.table}
                'metrics' {for($j=0;$j -lt @($p.metrics).Count;$j++){foreach($field in @('label','value_text','detail')){Add-TermText ($path+'.metrics['+$j+'].'+$field) @($p.metrics)[$j].$field}}}
                'bars' {for($j=0;$j -lt @($p.bars).Count;$j++){foreach($field in @('label','value_text')){Add-TermText ($path+'.bars['+$j+'].'+$field) @($p.bars)[$j].$field}}}
                'asset' {Add-TermText ($path+'.asset.description') $p.asset.description}
            }
        }
    }
    function Normalize-TermText([string]$Text){
        $canonical=$Text.Normalize([Text.NormalizationForm]::FormKC)
        # Preserve semantic word separators: "준수 위험" must not manufacture
        # the unrelated noun "수위". Declared compact/spaced aliases remain
        # separate glossary entries; Unicode whitespace maps to one space.
        $canonical=[regex]::Replace($canonical,'\s+',' ')
        return [regex]::Replace($canonical,'[\p{Cf}\p{Cc}]','')
    }
    $aliases=@{}
    foreach($term in @($policy.terms)){
        foreach($alias in @($term.korean)){
            $key=Normalize-TermText $alias
            if(-not $key){throw 'TERMINOLOGY_POLICY_UNSUPPORTED: empty normalized alias'}
            if($aliases.ContainsKey($key)){
                if($aliases[$key].english -cne $term.english){throw 'TERMINOLOGY_POLICY_UNSUPPORTED: conflicting Korean alias'}
            }else{$aliases[$key]=[pscustomobject]@{korean=$alias;english=$term.english;normalized=$key}}
        }
    }
    $findings=[Collections.Generic.List[object]]::new();$count=0
    foreach($leaf in $leaves){
        $text=Normalize-TermText $leaf.text
        $candidates=[Collections.Generic.List[object]]::new()
        foreach($alias in $aliases.Values){foreach($hit in [regex]::Matches($text,[regex]::Escape($alias.normalized))){$candidates.Add([pscustomobject]@{start=$hit.Index;span=$hit.Length;korean=$alias.korean;english=$alias.english;normalized=$alias.normalized})}}
        # Longest matching noun wins over nested aliases (Fine Silica over Silica).
        # Sorting is deterministic and never creates additional business units.
        $accepted=[Collections.Generic.List[object]]::new()
        foreach($candidate in @($candidates|Sort-Object @{Expression='span';Descending=$true},@{Expression='start';Ascending=$true},@{Expression='english';Ascending=$true})){
            $overlaps=$false
            foreach($previous in $accepted){if($candidate.start -lt $previous.start+$previous.span -and $previous.start -lt $candidate.start+$candidate.span){$overlaps=$true;break}}
            if(-not $overlaps){$accepted.Add($candidate)}
        }
        $grouped=@{}
        foreach($hit in @($accepted|Sort-Object start)){
            $key=$hit.english+'|'+$hit.normalized
            if($grouped.ContainsKey($key)){$grouped[$key].count++}
            else{
                $finding=[pscustomobject][ordered]@{path=$leaf.path;korean=$hit.korean;english=$hit.english;canonical_english=$hit.english;count=1;text=$leaf.text}
                $grouped[$key]=$finding;$findings.Add($finding)
            }
            $count++
        }
    }
    return [pscustomobject][ordered]@{policy_version=$policy.policy_version;stage=$Stage.id;status=$(if($count){'fail'}else{'pass'});count=$count;finding_count=$findings.Count;findings=@($findings.ToArray());coverage='fixed glossary only; not general Korean noun recognition';source_mutated=$false}
}
function Assert-ProposalTerminology {
    [CmdletBinding()]param([Parameter(Mandatory)][object]$Stage)
    $report=Get-ProposalTerminologyReport -Stage $Stage
    if($report.status -cne 'pass'){
        $exception=[InvalidOperationException]::new(('needs_input: TERMINOLOGY_NEEDS_ENGLISH: '+$Stage.id+' glossary occurrences='+$report.count))
        $exception.Data['terminology']=$report
        throw $exception
    }
    return $report
}
