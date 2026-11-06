# Pure content-density gate. Reads only the developer-owned policy JSON.
# Shapes are the already compiled native specifications, never Office/image files.
function Get-ProposalDensityPolicy {
    [CmdletBinding()]param()
    $path=Join-Path $PSScriptRoot '../assets/content-density-policy.json'
    $policy=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
    if($policy.policy_version -cne 'content-density-v1'){throw 'CONTENT_DENSITY_UNSUPPORTED: unknown developer policy version'}
    foreach($id in @('problem','cause','actions','effects','rollout')){
        $rule=$policy.stages.$id
        if($null -eq $rule -or $rule.baseline -le 0 -or $rule.multiplier -le 0 -or $rule.minimum -ne [math]::Ceiling($rule.baseline*$rule.multiplier)){
            throw ('CONTENT_DENSITY_UNSUPPORTED: invalid developer policy for '+$id)
        }
    }
    # A fresh object on every call prevents edits of a returned report/policy from
    # changing the next gate. There are no caller-supplied counts or thresholds.
    return $policy
}

function Get-ProposalContentDensity {
    [CmdletBinding()]param(
        [Parameter(Mandatory,Position=0)][object]$RawStage,
        [Parameter(Mandatory,Position=1)][object]$ResolvedStage,
        [Parameter(Mandatory,Position=2)][AllowEmptyCollection()][object[]]$Shapes
    )
    $policy=Get-ProposalDensityPolicy
    $id=[string]$RawStage.id;$profile=[string]$RawStage.layout_profile
    if($id -cnotin @('problem','cause','actions','effects','rollout') -or $profile -cnotin @($policy.supported_profiles) -or ($profile -ceq 'reference-v5-problem' -and $id -cne 'problem') -or ($profile -ceq 'reference-v6' -and $id -ceq 'problem') -or ($profile -ceq 'reference-v7' -and $id -cnotin @('cause','effects','rollout')) -or ($profile -ceq 'reference-v8-actions' -and $id -cne 'actions') -or ($profile -ceq 'reference-v9' -and $id -cnotin @('cause','effects')) -or ($profile -ceq 'reference-v10-actions' -and $id -cne 'actions')){
        throw ('CONTENT_DENSITY_UNSUPPORTED: stage/profile '+$id+'/'+$profile)
    }
    if($id -cne [string]$ResolvedStage.id -or $profile -cne [string]$ResolvedStage.layout_profile){throw 'CONTENT_DENSITY_STRUCTURE_MISMATCH: raw and resolved stage/profile differ'}
    $candidates=[Collections.Generic.List[object]]::new()
    $units=[Collections.Generic.List[object]]::new()
    $excluded=[Collections.Generic.List[object]]::new()
    $missing=[Collections.Generic.List[object]]::new()

    function ConvertTo-DensityCanonicalText([string]$Text){
        # Compatibility forms (for example fullwidth colon/Latin letters) and
        # invisible format/control codes must not create distinct visible facts.
        # Whitespace controls become spaces; other controls and Cf are removed.
        $canonical=$Text.Normalize([Text.NormalizationForm]::FormKC)
        $canonical=[regex]::Replace($canonical,'[\t\r\n\v\f]',' ')
        return [regex]::Replace($canonical,'[\p{Cf}\p{Cc}]','')
    }

    function Add-DensityCandidate([string]$Path,[string]$Kind,[object[]]$RawParts,[object[]]$DisplayParts,[string]$NumberId=''){
        foreach($v in @($RawParts)+@($DisplayParts)){
            if($null -ne $v -and $v -isnot [string]){throw ('CONTENT_DENSITY_UNSUPPORTED: non-string content at '+$Path)}
        }
        if(@($RawParts).Count -eq @($DisplayParts).Count){
            for($i=0;$i -lt @($RawParts).Count;$i++){
                $literal=[regex]::Replace((ConvertTo-DensityCanonicalText ([string]$RawParts[$i])),'\s+','');$display=[regex]::Replace((ConvertTo-DensityCanonicalText ([string]$DisplayParts[$i])),'\s+','')
                if(-not $literal -or -not $display -or $display -match '\[\[.*?\]\]'){continue}
                $pattern='^';$cursor=0
                foreach($token in [regex]::Matches($literal,'\[\[[A-Za-z][A-Za-z0-9_-]*\]\]')){
                    $pattern+=[regex]::Escape($literal.Substring($cursor,$token.Index-$cursor))+'.+?';$cursor=$token.Index+$token.Length
                }
                $pattern+=[regex]::Escape($literal.Substring($cursor))+'$'
                if(-not [regex]::IsMatch($display,$pattern)){throw ('CONTENT_DENSITY_STRUCTURE_MISMATCH: resolved wording changed at '+$Path)}
            }
        }
        $ids=@([regex]::Matches((@($RawParts)-join ' '),'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]')|ForEach-Object {$_.Groups[1].Value})
        if($NumberId){$ids+=@($NumberId)}
        $candidates.Add([pscustomobject]@{path=$Path;kind=$Kind;raw_parts=@($RawParts);display_parts=@($DisplayParts);binding_ids=@($ids|Sort-Object -Unique -CaseSensitive)})
    }
    function Add-DensityStrings([string]$Path,[string]$Kind,[object[]]$RawValues,[object[]]$DisplayValues){
        if(@($DisplayValues).Count -gt @($RawValues).Count){throw ('CONTENT_DENSITY_STRUCTURE_MISMATCH: extra resolved content at '+$Path)}
        for($i=0;$i -lt @($RawValues).Count;$i++){
            $shown=if($i -lt @($DisplayValues).Count){@($DisplayValues)[$i]}else{$null}
            Add-DensityCandidate ($Path+'['+$i+']') $Kind @(@($RawValues)[$i]) @($shown)
        }
    }
    function Add-DensityRows([string]$Path,$RawTable,$DisplayTable){
        $rr=@($RawTable.rows);$dr=@($DisplayTable.rows)
        if($null -eq $RawTable.rows){$rr=@()};if($null -eq $DisplayTable.rows){$dr=@()}
        if($dr.Count -gt $rr.Count){throw ('CONTENT_DENSITY_STRUCTURE_MISMATCH: extra resolved rows at '+$Path)}
        for($i=0;$i -lt $rr.Count;$i++){
            $shown=if($i -lt $dr.Count){@($dr[$i])}else{@()}
            Add-DensityCandidate ($Path+'.rows['+$i+']') 'table_row' @($rr[$i]) @($shown)
        }
    }

    if($profile -ceq 'reference-v5-problem'){
        $rp=$RawStage.problem;$dp=$ResolvedStage.problem
        foreach($column in @('baseline','observed')){
            Add-DensityStrings ('problem.comparison.'+$column+'.items') 'bullet' @($rp.comparison.$column.items) @($dp.comparison.$column.items)
        }
        $rs=@($rp.path.steps);$ds=@($dp.path.steps)
        if($ds.Count -gt $rs.Count){throw 'CONTENT_DENSITY_STRUCTURE_MISMATCH: extra resolved V5 path steps'}
        for($i=0;$i -lt $rs.Count;$i++){
            $detail=if($i -lt $ds.Count){$ds[$i].detail}else{$null}
            Add-DensityCandidate ('problem.path.steps['+$i+'].detail') 'step' @($rs[$i].detail) @($detail)
        }
        if($rp.evidence.kind -cne $dp.evidence.kind){throw 'CONTENT_DENSITY_STRUCTURE_MISMATCH: evidence kind changed'}
        switch -CaseSensitive ([string]$rp.evidence.kind){
            'table' {Add-DensityRows 'problem.evidence.table' $rp.evidence.table $dp.evidence.table}
            'asset' {} # Assets and their descriptions are not information units.
            default {throw 'CONTENT_DENSITY_UNSUPPORTED: V5 evidence kind'}
        }
        $rg=@($rp.impact.groups);$dg=@($dp.impact.groups)
        if($dg.Count -gt $rg.Count){throw 'CONTENT_DENSITY_STRUCTURE_MISMATCH: extra resolved V5 impact groups'}
        for($i=0;$i -lt $rg.Count;$i++){
            $lines=if($i -lt $dg.Count){@($dg[$i].lines)}else{@()}
            Add-DensityStrings ('problem.impact.groups['+$i+'].lines') 'bullet' @($rg[$i].lines) @($lines)
        }
    }else{
        $rawPanels=@($RawStage.panels);$displayPanels=@($ResolvedStage.panels)
        if($displayPanels.Count -ne $rawPanels.Count){throw 'CONTENT_DENSITY_STRUCTURE_MISMATCH: panel count changed'}
        for($p=0;$p -lt $rawPanels.Count;$p++){
            $raw=$rawPanels[$p];$shown=$displayPanels[$p];$path='panels['+$p+']'
            if($raw.kind -cne $shown.kind){throw ('CONTENT_DENSITY_STRUCTURE_MISMATCH: panel kind changed at '+$path)}
            switch -CaseSensitive ([string]$raw.kind){
                'bullets' {Add-DensityStrings ($path+'.lines') 'bullet' @($raw.lines) @($shown.lines)}
                'flow' {Add-DensityStrings ($path+'.steps') 'step' @($raw.steps) @($shown.steps)}
                'timeline' {Add-DensityStrings ($path+'.steps') 'step' @($raw.steps) @($shown.steps)}
                'table' {Add-DensityRows ($path+'.table') $raw.table $shown.table}
                {$_ -cin @('metrics','bars')} {
                    $field=[string]$raw.kind;$kind=if($field -ceq 'metrics'){'metric'}else{'bar'}
                    $rv=@($raw.$field);$dv=@($shown.$field)
                    if($dv.Count -gt $rv.Count){throw ('CONTENT_DENSITY_STRUCTURE_MISMATCH: extra resolved '+$field)}
                    for($i=0;$i -lt $rv.Count;$i++){
                        $parts=if($i -lt $dv.Count){@($dv[$i].label,$dv[$i].value_text)}else{@()}
                        $nid=if($kind -ceq 'bar'){[string]$rv[$i].number_id}else{''}
                        Add-DensityCandidate ($path+'.'+$field+'['+$i+']') $kind @($rv[$i].label,$rv[$i].value_text) @($parts) $nid
                    }
                }
                'asset' {}
                default {throw ('CONTENT_DENSITY_UNSUPPORTED: panel kind '+$raw.kind)}
            }
        }
    }

    # Normalize wrapping whitespace for display matching. Punctuation remains:
    # removing punctuation is for duplicate detection, not a claim of visibility.
    function Normalize-DensityDisplay([string]$Text){return ([regex]::Replace((ConvertTo-DensityCanonicalText $Text),'\s+',''))}
    function Normalize-DensityStatement([string]$Text){
        $compact=[regex]::Replace((ConvertTo-DensityCanonicalText $Text),'\s+','')
        return [regex]::Replace($compact,'\p{P}',[Text.RegularExpressions.MatchEvaluator]{param($match)
            $at=$match.Index;$before=if($at -gt 0){$compact[$at-1]}else{[char]0};$after=if($at+1 -lt $compact.Length){$compact[$at+1]}else{[char]0}
            # Decimal/grouping separators and numeric signs carry quantity data.
            if(($match.Value -cin @('.',',') -and [char]::IsDigit($before) -and [char]::IsDigit($after)) -or ($match.Value -cin @('-','−','–') -and [char]::IsDigit($after))){return $match.Value}
            return ''
        })
    }
    function Test-DensityMissingOnly([string]$Text){
        $v=(ConvertTo-DensityCanonicalText $Text).Trim()
        if([string]::IsNullOrWhiteSpace($v) -or $v -match '^(?:[-–—?…._]+|TBD|TODO|N/?A|unknown|not\s+available|확인\s*필요|추가\s*확인\s*필요)[.!。]?$'){return $true}
        if($v -match '^(?:TBD|TODO|N/?A|unknown|not\s+available)\s*:\s*[^.!。]+[.!。]?$'){return $true}
        # A real bound value is concrete data even if another part is unknown.
        # Core separately checks the value's source and resolved display text.
        if($v -match '\[\[[A-Za-z][A-Za-z0-9_-]*\]\]'){return $false}
        $absence='(?:미\s*(?:공개|확인|제공|입력)|미정|(?:자료|정보|근거)(?:가|는|은)?\s*(?:없(?:음|다|습니다|어요|는)|부족(?:함|하다|합니다|한)?)|확인\s*불가|(?:공개|제공|확인)(?:이|가)?\s*되지\s*않(?:음|았다|았습니다|았음|습니다)|(?:제공받지|확보하지|확인하지)\s*못(?:함|했음|했다|했습니다)|확인할\s*수\s*없(?:음|다|습니다))'
        $absenceEnd=$absence+'(?:\s*(?:상태|사항|항목))?(?:입니다|이다|임)?\s*[\p{P}\p{S}]*$'
        if($v -notmatch $absenceEnd){return $false}
        # Do not cap the topic's length or require a particular colon. "A long
        # measurement topic: unavailable" is still absence, never a new fact.
        # Classification may examine clauses; it never counts clauses separately.
        # Preserve an independently stated concrete result before an unknown
        # qualifier, such as "filter/chlorine combined result; contribution unknown".
        $clauses=@([regex]::Split($v,'[·;.!。\r\n]|(?<!\d),(?!\d)|(?:하지만|다만|그러나|반면)|(?<=했다|하였다|되었다|됐다)(?:지만|으나)|(?:이며|이고)'))
        foreach($clause in $clauses){
            $part=$clause.Trim(' ',':','-')
            if(-not $part -or $part -match $absenceEnd){continue}
            # Numeric bindings carry concrete display data checked by Core.
            if($part -match '\[\[[A-Za-z][A-Za-z0-9_-]*\]\]'){return $false}
            $fact='(?:사용|발생|관찰|확인|적용|도입|설치|회수|제거|처리|분리|환류|혼합|병용|통합|증가|감소|변화|변동|검출|기록|발견)'
            if($part -match ($fact+'\s*(?:결과|효과|완료|중|흔적|가능|위험|했(?:다|음)|하였(?:다|음)|되었(?:다|음)|됐(?:다|음)|됨|함)?$')){return $false}
        }
        return $true
    }
    $shapeMap=@{}
    foreach($shape in @($Shapes)){
        if($null -eq $shape -or $shape.kind -cnotin @('text','rect','shape','line','asset')){throw 'CONTENT_DENSITY_UNSUPPORTED: unknown native shape kind'}
        if($shape.id){$shapeMap[[string]$shape.id]=$shape}
    }
    function Test-DensityDisplayed($Shape){
        $seen=@{};$cursor=$Shape
        while($null -ne $cursor){
            if(($null -ne $cursor.visible -and $cursor.visible -in @($false,0)) -or $cursor.hidden -eq $true){return $false}
            if($null -ne $cursor.w -and $null -ne $cursor.h -and ([double]$cursor.w -le 0 -or [double]$cursor.h -le 0)){
                # A zero-height line can be a connector parent only in malformed
                # input; no displayed text depends on such a parent in the layouts.
                return $false
            }
            $parent=[string]$cursor.parent
            if(-not $parent -or -not $shapeMap.ContainsKey($parent)){break}
            if($seen.ContainsKey($parent)){return $false};$seen[$parent]=$true;$cursor=$shapeMap[$parent]
        }
        if($null -eq $Shape.w -or $null -eq $Shape.h){return $false}
        foreach($key in @('x','y','w','h')){
            if($null -eq $Shape.$key -or [double]::IsNaN([double]$Shape.$key) -or [double]::IsInfinity([double]$Shape.$key)){return $false}
        }
        return ($Shape.x -ge 0 -and $Shape.y -ge 0 -and $Shape.x+$Shape.w -le 960.1 -and $Shape.y+$Shape.h -le 540.1)
    }
    $displayTexts=[Collections.Generic.List[object]]::new();$displayGroups=@{}
    foreach($shape in @($Shapes)){
        if($shape.kind -cne 'text' -or -not (Test-DensityDisplayed $shape)){continue}
        if($shape.role -cin @('title','section','subtitle','conclusion','source','decoration','background') -and [string]$shape.id -cnotmatch '-(?:sum|step)-\d+-label$'){continue}
        if([string]$shape.id -cmatch '^page-(?:title|subtitle|takeaway|citation|number)$|(?:-heading|-outcome|-concept)$' -and [string]$shape.id -cnotmatch '-linked-step-\d+-heading$'){continue}
        $entry=[pscustomobject]@{id=[string]$shape.id;parent=[string]$shape.parent;text=(Normalize-DensityDisplay ([string]$shape.text))}
        if(-not $entry.text){continue};$displayTexts.Add($entry)
        if($entry.parent){if(-not $displayGroups.ContainsKey($entry.parent)){$displayGroups[$entry.parent]=[Collections.Generic.List[object]]::new()};$displayGroups[$entry.parent].Add($entry)}
    }
    function Find-DensityVisibleParts([string[]]$Parts,[string]$Kind){
        $found=[Collections.Generic.List[string]]::new();$all=$true
        foreach($part in $Parts){
            $key=Normalize-DensityDisplay $part;$hit=@($displayTexts|Where-Object {$_.text -ceq $key})
            if(-not $key -or $hit.Count -eq 0){$all=$false;break};$found.Add($hit[0].id)
        }
        if($all -and $Kind -cin @('metric','bar')){
            # A value elsewhere on the slide is not the value of this label.
            # Current metric cards share a parent; bars may combine both strings
            # in one native text shape, handled below.
            $all=$false
            foreach($group in $displayGroups.Values){
                $groupIds=[Collections.Generic.List[string]]::new();$complete=$true
                foreach($part in $Parts){
                    $key=Normalize-DensityDisplay $part;$hits=@($group|Where-Object {$_.text -ceq $key})
                    if($hits.Count -eq 0){$complete=$false;break};$groupIds.Add($hits[0].id)
                }
                if($complete){$all=$true;$found=$groupIds;break}
            }
        }
        if($all){return [pscustomobject]@{visible=$true;shape_ids=@($found.ToArray()|Select-Object -Unique)}}
        $combined=Normalize-DensityDisplay ($Parts -join ' ')
        foreach($entry in $displayTexts){if($entry.text -ceq $combined){return [pscustomobject]@{visible=$true;shape_ids=@($entry.id)}}}
        # Monetary flow steps have separate label/value shapes in one native node.
        # Never split a source sentence into additional counted units.
        foreach($group in $displayGroups.Values){
            if((($group|ForEach-Object {$_.text})-join '') -ceq $combined){return [pscustomobject]@{visible=$true;shape_ids=@($group|ForEach-Object {$_.id})}}
        }
        return [pscustomobject]@{visible=$false;shape_ids=@()}
    }
    $seenStatements=@{};$seenBindings=@{}
    foreach($candidate in $candidates){
        $rawText=$candidate.raw_parts -join ' ';$text=$candidate.display_parts -join ' '
        $statement=Normalize-DensityStatement $text;$bindingKey=$candidate.binding_ids -join '|'
        if(Test-DensityMissingOnly $rawText){$excluded.Add([pscustomobject]@{path=$candidate.path;kind=$candidate.kind;reason='placeholder_or_missing_only';text=$rawText});continue}
        if($candidate.raw_parts.Count -ne $candidate.display_parts.Count -or @($candidate.display_parts|Where-Object {[string]::IsNullOrWhiteSpace([string]$_)}).Count -gt 0 -or $text -match '\[\[.*?\]\]'){
            $missing.Add([pscustomobject]@{path=$candidate.path;kind=$candidate.kind;reason='missing_resolved_display_data';text=$text});continue
        }
        if($seenStatements.ContainsKey($statement)){$excluded.Add([pscustomobject]@{path=$candidate.path;kind=$candidate.kind;reason='duplicate_statement';duplicate_of=$seenStatements[$statement];text=$text});continue}
        if($bindingKey -and $seenBindings.ContainsKey($bindingKey)){$excluded.Add([pscustomobject]@{path=$candidate.path;kind=$candidate.kind;reason='duplicate_binding_set';duplicate_of=$seenBindings[$bindingKey];binding_ids=@($candidate.binding_ids);text=$text});continue}
        $visibility=Find-DensityVisibleParts @($candidate.display_parts) $candidate.kind
        if(-not $visibility.visible){$missing.Add([pscustomobject]@{path=$candidate.path;kind=$candidate.kind;reason='not_in_displayed_shapes';text=$text;required_parts=@($candidate.display_parts)});continue}
        $seenStatements[$statement]=$candidate.path;if($bindingKey){$seenBindings[$bindingKey]=$candidate.path}
        $units.Add([pscustomobject]@{path=$candidate.path;kind=$candidate.kind;text=$text;binding_ids=@($candidate.binding_ids);shape_ids=@($visibility.shape_ids)})
    }
    $rule=$policy.stages.$id
    $errorCode=if($missing.Count){'CONTENT_DENSITY_NOT_VISIBLE'}elseif($units.Count -lt $rule.minimum){'CONTENT_DENSITY_BELOW_MINIMUM'}else{''}
    return [pscustomobject][ordered]@{
        policy_version=$policy.policy_version;stage=$id;baseline=$rule.baseline;multiplier=$rule.multiplier;minimum=$rule.minimum;counted=$units.Count
        status=$(if($errorCode){'fail'}else{'pass'});units=$units.ToArray();excluded=$excluded.ToArray();missing=$missing.ToArray();semantic_quality='not_proven_by_count';error_code=$errorCode
    }
}

function Assert-ProposalContentDensity {
    [CmdletBinding()]param(
        [Parameter(Mandatory,Position=0)][object]$RawStage,
        [Parameter(Mandatory,Position=1)][object]$ResolvedStage,
        [Parameter(Mandatory,Position=2)][AllowEmptyCollection()][object[]]$Shapes
    )
    $report=Get-ProposalContentDensity -RawStage $RawStage -ResolvedStage $ResolvedStage -Shapes $Shapes
    if($report.status -cne 'pass'){
        $exception=[InvalidOperationException]::new(('needs_input: {0}: {1} counted={2} minimum={3}' -f $report.error_code,$report.stage,$report.counted,$report.minimum))
        $exception.Data['report']=$report;$exception.Data['content_density']=$report
        throw $exception
    }
    return $report
}
