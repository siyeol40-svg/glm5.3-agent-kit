# Compile the procedure/table author brief without changing either input.
function ConvertTo-ProposalV5ProcedureTableStage($Brief,$FactIndex,[string[]]$NumberIds,[string]$SourceCaption){
    . (Join-Path $PSScriptRoot 'Proposal.ProblemV5.ps1')
    $textFields=@('title','subtitle','takeaway','comparison_title','baseline_title','observed_title','procedure_title','table_title','impact_title')
    $rowFields=@('citation','baseline_focus','baseline','observed_focus','observed','procedure','table_headers','table','impact')
    Assert-ProposalV5Object $Brief ($textFields+$rowFields) 'brief'
    foreach($field in $textFields){Assert-ProposalV5Text $Brief.$field ('brief.'+$field)}
    $caption=if([string]::IsNullOrWhiteSpace($SourceCaption)){$Brief.citation}else{$SourceCaption}
    Assert-ProposalV5Text $caption 'SourceCaption'
    Assert-ProposalV5TextItems $Brief.table_headers 2 2 'brief.table_headers'
    Assert-ProposalV5Array $Brief.impact 2 2 'brief.impact'

    $idPattern='^[A-Za-z][A-Za-z0-9_-]*\z'
    $comparer=[StringComparer]::Ordinal
    $facts=[Collections.Generic.Dictionary[string,object]]::new($comparer)
    if($FactIndex -isnot [array] -or -not $FactIndex.Count){throw 'needs_input: fact index must be a nonempty array'}
    foreach($fact in $FactIndex){
        Assert-ProposalV5Object $fact @('id','source_ids') 'fact index record'
        if($fact.id -isnot [string] -or $fact.id -cnotmatch $idPattern){throw 'needs_input: invalid fact index ID'}
        if($facts.ContainsKey($fact.id)){throw ('needs_input: duplicate fact index ID '+$fact.id)}
        Assert-ProposalV5Refs $fact.source_ids 'fact index record'
        foreach($sourceId in $fact.source_ids){
            if($sourceId -cnotmatch $idPattern){throw 'needs_input: invalid fact source ID'}
        }
        $facts.Add($fact.id,$fact.source_ids)
    }

    $usedFacts=[Collections.Generic.HashSet[string]]::new($comparer)
    $knownNumbers=[Collections.Generic.HashSet[string]]::new($comparer)
    foreach($id in $NumberIds){$null=$knownNumbers.Add($id)}
    $usedNumbers=[Collections.Generic.HashSet[string]]::new($comparer)
    $stageRefs=[Collections.Generic.List[string]]::new()

    function Read-V5AuthorRows($Rows,[int]$Count,[int]$Width,[string]$Where,[switch]$Procedure){
        Assert-ProposalV5Array $Rows $Count $Count $Where
        for($i=0;$i -lt $Rows.Count;$i++){
            $row=$Rows[$i]
            $at=$Where+'['+$i+']'
            Assert-ProposalV5Array $row $Width $Width $at
            $id=$row[0]
            if($id -isnot [string] -or $id -cnotmatch $idPattern -or -not $facts.ContainsKey($id)){
                throw ('needs_input: unknown fact ID at '+$at)
            }
            if(-not $usedFacts.Add($id)){throw ('needs_input: duplicate fact ID '+$id+' at '+$at)}
            $texts=@($row[1..($Width-1)])
            foreach($value in $texts){Assert-ProposalV5Text $value $at}

            # Procedure headings are labels. The detail alone counts as an information unit.
            $countedText=if($Procedure){$texts[1]}else{$texts -join ' '}
            $rowNumbers=[Collections.Generic.HashSet[string]]::new($comparer)
            foreach($match in [regex]::Matches($countedText,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')){
                $numberId=$match.Groups[1].Value
                if($knownNumbers.Contains($numberId) -and $rowNumbers.Add($numberId) -and -not $usedNumbers.Add($numberId)){
                    throw ('needs_input: duplicate numeric binding '+$numberId+' at '+$at)
                }
            }
            $refs=@($facts[$id])
            foreach($ref in $refs){$stageRefs.Add($ref)}
            [pscustomobject]@{texts=$texts;source_ids=$refs}
        }
    }

    $columns=@{}
    foreach($side in @('baseline','observed')){
        $focus=$Brief.($side+'_focus')
        if(($focus -isnot [int] -and $focus -isnot [long]) -or $focus -lt 0 -or $focus -gt 2){
            throw ('needs_input: brief.'+$side+'_focus must be an integer from 0 to 2')
        }
        $rows=@(Read-V5AuthorRows $Brief.$side 3 2 ('brief.'+$side))
        $columns[$side]=[pscustomobject][ordered]@{
            title=$Brief.($side+'_title')
            items=@($rows|ForEach-Object {$_.texts[0]})
            source_ids=@($rows.source_ids|Select-Object -Unique)
        }
    }

    $steps=@(foreach($row in @(Read-V5AuthorRows $Brief.procedure 4 3 'brief.procedure' -Procedure)){
        [pscustomobject][ordered]@{title=$row.texts[0];detail=$row.texts[1];icon='monitor';source_ids=$row.source_ids}
    })
    $table=@(Read-V5AuthorRows $Brief.table 4 3 'brief.table')
    $groups=@(for($i=0;$i -lt $Brief.impact.Count;$i++){
        $group=$Brief.impact[$i]
        $at='brief.impact['+$i+']'
        Assert-ProposalV5Object $group @('title','state','lines') $at
        Assert-ProposalV5Text $group.title ($at+'.title')
        if($group.state -isnot [string] -or $group.state -cnotin @('supported','risk')){
            throw ('needs_input: '+$at+'.state requires supported or risk')
        }
        $rows=@(Read-V5AuthorRows $group.lines 2 2 ($at+'.lines'))
        [pscustomobject][ordered]@{
            title=$group.title
            state=$group.state
            lines=@($rows|ForEach-Object {$_.texts[0]})
            source_ids=@($rows.source_ids|Select-Object -Unique)
        }
    })

    return [pscustomobject][ordered]@{
        id='problem'
        layout_profile='reference-v5-problem'
        title=$Brief.title
        subtitle=$Brief.subtitle
        takeaway=$Brief.takeaway
        citation=$caption
        source_ids=@($stageRefs|Select-Object -Unique)
        problem=[pscustomobject][ordered]@{
            comparison=[pscustomobject][ordered]@{
                title=$Brief.comparison_title
                baseline=$columns.baseline
                observed=$columns.observed
                focus=[pscustomobject][ordered]@{baseline_item=$Brief.baseline_focus;observed_item=$Brief.observed_focus}
            }
            path=[pscustomobject][ordered]@{title=$Brief.procedure_title;relationship='procedure';steps=$steps}
            evidence=[pscustomobject][ordered]@{
                title=$Brief.table_title
                kind='table'
                source_ids=@($table.source_ids|Select-Object -Unique)
                table=[pscustomobject][ordered]@{
                    headers=@($Brief.table_headers)
                    rows=@(foreach($row in $table){,$row.texts})
                }
            }
            impact=[pscustomobject][ordered]@{title=$Brief.impact_title;groups=$groups}
        }
    }
}
