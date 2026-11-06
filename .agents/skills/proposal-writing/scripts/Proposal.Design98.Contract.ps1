# Reference V7 semantic contract. Pure business objects only; no Office/media/network IO.
function ConvertTo-ProposalDesign98BaseStage($Stage){
    # Never replace properties on the caller's live stage. V6 remains the single
    # authority for panel shapes, ledger bindings, exact labels and source guards.
    $base=$Stage|ConvertTo-Json -Depth 60|ConvertFrom-Json
    $base.layout_profile='reference-v6'
    $base.PSObject.Properties.Remove('visuals')
    return $base
}
function ConvertTo-ProposalActionsV8BaseStage($Stage){
    $base=$Stage|ConvertTo-Json -Depth 60|ConvertFrom-Json
    $base.layout_profile='reference-v6'
    return $base
}
function Assert-ProposalActionsV8Shape($Stage){
    if([string]$Stage.id -cne 'actions'){throw ('V8 actions unsupported stage: '+$Stage.id)}
    if(@($Stage.panels|Where-Object {$null -ne $_}).Count -gt 0){
        . (Join-Path $PSScriptRoot 'Proposal.ActionIcons.ps1')
        $null=Assert-ProposalActionIconSemantics $Stage
    }
}
function Assert-ProposalActionsV8Stage($Stage){
    Assert-ProposalActionsV8Shape $Stage
    if(@($Stage.panels).Count -ne 6){throw 'V8 actions requires exactly six action panels'}
    foreach($panel in @($Stage.panels)){
        if($panel.lines -isnot [array] -or @($panel.lines).Count -ne 3){throw 'V8 actions requires exactly three source statements per panel'}
    }
    return $true
}
function Assert-ProposalDesign98ExactKeys($Value,[string[]]$Fields,[string]$Where){
    if($null -eq $Value -or ($Value -isnot [pscustomobject] -and $Value -isnot [Collections.IDictionary])){throw ('V7 '+$Where+' requires an object')}
    Assert-ProposalAllowedProperties $Value $Fields $Where
    $keys=if($Value -is [Collections.IDictionary]){@($Value.Keys)}else{@($Value.PSObject.Properties.Name)}
    foreach($field in $Fields){if($field -cnotin $keys){throw ('V7 '+$Where+'.'+$field+' is required')}}
}
function Assert-ProposalDesign98StringKinds($Value,[string[]]$Expected,[string]$Where){
    if($Value -isnot [array] -or @($Value).Count -ne $Expected.Count){throw ('V7 '+$Where+' requires exactly '+$Expected.Count+' supported kinds')}
    for($i=0;$i -lt $Expected.Count;$i++){if($Value[$i] -isnot [string] -or $Value[$i] -cne $Expected[$i]){throw ('V7 '+$Where+' has an unsupported kind or position')}}
}
function Assert-ProposalDesign98ConditionLinkShape($Links){
    $kinds=@('silica','bio','variation')
    Assert-ProposalDesign98ExactKeys $Links $kinds 'visuals.condition_links'
    $conditions=@{};$traits=@{}
    foreach($kind in $kinds){
        $link=$Links.$kind
        Assert-ProposalDesign98ExactKeys $link @('condition','trait') ('visuals.condition_links.'+$kind)
        if(-not (Test-ProposalEvidenceIndexInteger $link.condition) -or $link.condition -lt 0 -or $link.condition -gt 4 -or -not (Test-ProposalEvidenceIndexInteger $link.trait) -or $link.trait -lt 0 -or $link.trait -gt 3){throw 'V7 condition_links require integer condition indices zero to four and trait indices zero to three'}
        if($conditions.ContainsKey([string]$link.condition) -or $traits.ContainsKey([string]$link.trait)){throw 'V7 condition_links require unique condition rows and trait statements; duplicate references are unsupported'}
        $conditions[[string]$link.condition]=$true;$traits[[string]$link.trait]=$true
    }
}
function Assert-ProposalDesign98Shape($Stage){
    if([string]$Stage.id -cnotin @('cause','effects','rollout')){throw ('V7 unsupported stage: '+$Stage.id)}
    Assert-ProposalAllowedProperties $Stage @('id','title','subtitle','takeaway','source_ids','panels','scope','layout_profile','citation','visuals') 'stage'
    $v=$Stage.visuals
    switch -CaseSensitive ([string]$Stage.id){
        cause {
            $keys=if($v -is [Collections.IDictionary]){@($v.Keys)}else{@($v.PSObject.Properties.Name)}
            $fields=@('kind','scope','feature_indices')
            if('condition_links' -cin $keys){$fields+='condition_links'}
            Assert-ProposalDesign98ExactKeys $v $fields 'visuals'
            if($v.kind -isnot [string] -or $v.kind -cne 'edr_mechanism'){throw 'V7 cause visuals kind must be edr_mechanism'}
            if($v.scope -isnot [string] -or $v.scope -cne 'general_principle'){throw 'V7 mechanism supports only general_principle scope'}
            $features=@('electric_field','selective_membrane','separate_channels','water_channel')
            Assert-ProposalDesign98ExactKeys $v.feature_indices $features 'visuals.feature_indices'
            $seen=@{}
            foreach($feature in $features){
                $index=$v.feature_indices.$feature
                if(-not (Test-ProposalEvidenceIndexInteger $index) -or $index -lt 0 -or $index -gt 3 -or $seen.ContainsKey([string]$index)){throw 'V7 feature_indices require unique integer indices zero to three'}
                $seen[[string]$index]=$true
            }
            if('condition_links' -cin $keys){Assert-ProposalDesign98ConditionLinkShape $v.condition_links}
        }
        effects {
            Assert-ProposalDesign98ExactKeys $v @('kind','metric_kinds','detail_kinds','interval_line') 'visuals'
            if($v.kind -isnot [string] -or $v.kind -cne 'performance'){throw 'V7 effects visuals kind must be performance'}
            Assert-ProposalDesign98StringKinds $v.metric_kinds @('recovery_percent','removal_percent','upper_bound') 'visuals.metric_kinds'
            Assert-ProposalDesign98StringKinds $v.detail_kinds @('combined_multiplier','projected_lifetime','supply_spec','biogrowth_control','silica_observation') 'visuals.detail_kinds'
            if(-not (Test-ProposalEvidenceIndexInteger $v.interval_line) -or $v.interval_line -ne 0){throw 'V7 interval_line currently supports only integer line zero'}
        }
        rollout {
            Assert-ProposalDesign98ExactKeys $v @('kind','check_gates','acceptance_gates') 'visuals'
            if($v.kind -isnot [string] -or $v.kind -cne 'gate_board'){throw 'V7 rollout visuals kind must be gate_board'}
            foreach($field in @('check_gates','acceptance_gates')){
                if($v.$field -isnot [array] -or @($v.$field).Count -ne 6){throw ('V7 '+$field+' requires six gate indices')}
                foreach($gate in $v.$field){if(-not (Test-ProposalEvidenceIndexInteger $gate) -or $gate -lt 0 -or $gate -gt 3){throw ('V7 '+$field+' requires integer gate indices zero to three')}}
            }
        }
    }
}
function Get-ProposalDesign98NumberBinding([string]$Text,$Ledger,[string]$Where){
    $match=[regex]::Match($Text,'^\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]$')
    if(-not $match.Success -or -not $Ledger.numbers.ContainsKey($match.Groups[1].Value)){throw ('V7 '+$Where+' requires exactly one quantity binding')}
    return $Ledger.numbers[$match.Groups[1].Value]
}
function Test-ProposalDesign98CombinedSource([string]$Text){
    # Deliberately narrow evidence grammar for this initial Filter + Residual
    # Chlorine component. Mere keyword co-occurrence cannot establish co-use.
    $text=[regex]::Replace($Text.Normalize([Text.NormalizationForm]::FormKC),'\s+',' ')
    $negativeKo='단독|(?:Filter|필터)만\s*(?:사용|적용)|미사용|미적용|(?:별도|분리)\s*(?:사용|적용)|(?:사용|적용|병용|투입|혼합|조합)(?:하|되)?지(?:는|도)?\s*(?:않|못)|(?:사용|적용|병용)\s*(?:안|아니|없|금지|제외)|검토|예정|가정|계획|제안|여부|불명|불확실|추정|추측'
    $negativeEn='\b(?:alone|separately|without|never)\b|\bonly\s+(?:the\s+)?Filter\b|\bFilter\s+only\b|\bnot\s+(?:(?:used|applied|added)\s+)?(?:together|combined|in\s+combination|with|used|applied|added|mixed)\b|\bno\s+(?:co[- ]?use|combined\s+use|combination|(?:Residual\s+)?Chlorine)\b|\b(?:if|planned?|planning|proposed?|hypothetical|consider(?:ed)?|appears?|seems?|may|might|would|could)\b|\bChlorine\s+(?:was|is)\s+(?:absent|not\s*[.!?])'
    if($text -match $negativeKo -or $text -match $negativeEn){return $false}
    foreach($sentence in @($text -split '[.!?。\r\n]+')){
        if($sentence -notmatch 'Filter|필터' -or $sentence -notmatch 'Chlorine|염소'){continue}
        $positiveKo='병용(?:으로|하|한|했|되|해|하였|됨|사용|적용|\s+시험)|동시\s*(?:사용|적용|투입|운전)|함께\s*(?:사용|적용|투입)'
        $positiveEn='\bcombined\b|\bin\s+combination\b|\bFilters?(?:\s+(?:was|were|is|are))?(?:\s+(?:used|combined))?\s+with\s+(?:Residual\s+)?Chlorine\b|\bChlorine(?:\s+(?:was|were|is|are))?(?:\s+(?:used|combined))?\s+with\s+(?:the\s+)?Filters?\b'
        if($sentence -match $positiveKo -or $sentence -match $positiveEn){return $true}
    }
    return $false
}
function Assert-ProposalDesign98Stage($Stage,$Ledger){
    Assert-ProposalDesign98Shape $Stage
    $panels=@($Stage.panels)
    switch -CaseSensitive ([string]$Stage.id){
        cause {
            # A general EDR diagram may sit beside independently supported facts;
            # those facts must never be rendered as an invented causal sequence.
            $features=$Stage.visuals.feature_indices;$lines=@($panels[0].lines)
            if($lines.Count -ne 4){throw 'V7 feature semantic mapping requires exactly four system statements'}
            if([string]$lines[$features.electric_field] -notmatch 'Electric\s+Field'){throw 'V7 feature semantic mismatch: electric_field requires Electric Field'}
            if([string]$lines[$features.selective_membrane] -notmatch 'Selective\s+Membrane|Cation|Anion'){throw 'V7 feature semantic mismatch: selective_membrane requires its selective Membrane or Ion marker'}
            if([string]$lines[$features.separate_channels] -notmatch 'Diluate' -or [string]$lines[$features.separate_channels] -notmatch 'Concentrate'){throw 'V7 feature semantic mismatch: separate_channels requires Diluate and Concentrate'}
            if([string]$lines[$features.water_channel] -notmatch 'Water' -or [string]$lines[$features.water_channel] -notmatch '유로|channel|surface|표면'){throw 'V7 feature semantic mismatch: water_channel requires Water and its channel or surface marker'}
            if($panels[2].kind -cne 'bullets'){throw 'V7 general mechanism causal panel currently requires bullets, not an arrow chain'}
            foreach($line in @($panels[2].lines)){if([string]$line -match '[→⇒➜↔]|-+>'){throw 'V7 general mechanism causal bullets cannot contain an unverified arrow chain'}}
            $keys=if($Stage.visuals -is [Collections.IDictionary]){@($Stage.visuals.Keys)}else{@($Stage.visuals.PSObject.Properties.Name)}
            if('condition_links' -cin $keys){
                $rows=@($panels[1].table.rows);$traits=@($panels[2].lines)
                if($rows.Count -ne 5 -or $traits.Count -ne 4){throw 'V7 condition_links require five condition rows and four supported trait statements'}
                foreach($state in @($panels[2].line_states|Where-Object {$null -ne $_})){if($state -cne 'supported'){throw 'V7 condition_links require supported trait statements only'}}
                foreach($kind in @('silica','bio','variation')){
                    $link=$Stage.visuals.condition_links.$kind
                    $condition=[string]$rows[$link.condition][0];$trait=[string]$traits[$link.trait]
                    $match=switch($kind){
                        silica {$condition -match 'Silica' -and $trait -match 'Silica'}
                        bio {$condition -match 'Temp|Organic|Biogrowth' -and $trait -match 'Chlorine'}
                        variation {$condition -match 'Feed\s+Quality|Feed|변동' -and $trait -match 'Voltage|TDS'}
                    }
                    if(-not $match){throw ('V7 condition_links '+$kind+' semantic markers do not match the selected original condition and trait')}
                }
            }
        }
        effects {
            $metrics=@($panels[0].metrics)
            if($metrics.Count -ne 3){throw 'V7 performance requires exactly three metric_kinds and metrics'}
            for($i=0;$i -lt 2;$i++){
                $n=Get-ProposalDesign98NumberBinding ([string]$metrics[$i].value_text) $Ledger 'percent metric'
                if($n.unit -cne '%' -or $n.qualifier -or $n.period -or $n.currency -or $n.value -lt 0 -or $n.value -gt 100){throw 'V7 proportion visual requires an exact unqualified percent between zero and one hundred'}
            }
            $upper=Get-ProposalDesign98NumberBinding ([string]$metrics[2].value_text) $Ledger 'upper bound metric'
            if(-not $upper.unit -or $upper.unit -ceq '%' -or $upper.qualifier -cne '미만' -or $upper.currency -or $upper.period -or $upper.value -le 0){throw 'V7 upper bound requires a positive nonpercent quantity with strict 미만 qualifier'}
            if($panels[1].kind -cne 'table' -or @($panels[1].table.rows).Count -ne 5 -or @($panels[1].table.headers).Count -ne 2){throw 'V7 detail_kinds require exactly five two-column detail table rows'}
            $rows=@($panels[1].table.rows)
            $mult=Get-ProposalDesign98NumberBinding ([string]$rows[0][1]) $Ledger 'combined multiplier'
            if($mult.unit -cne '배' -or $mult.value -le 0 -or $mult.qualifier -or $mult.currency -or $mult.period){throw 'V7 combined multiplier requires a positive exact quantity with unit 배'}
            # This initial component means Filter + Residual Chlorine, not an
            # arbitrary multiple. Its own quantity evidence must carry both terms.
            $combinedSources=@($mult.source_ids|Where-Object {Test-ProposalDesign98CombinedSource ([string]$Ledger.sources[[string]$_].text)})
            if($combinedSources.Count -eq 0){throw 'V7 combined multiplier source must support Filter with Residual Chlorine'}
            $life=Get-ProposalDesign98NumberBinding ([string]$rows[1][1]) $Ledger 'projected lifetime'
            if($life.unit -cne '년' -or $life.value -le 0 -or $life.qualifier -cne '초과' -or $life.period -or $life.currency -or $life.metric -notmatch '전망|예상|Forecast|Projected'){throw 'V7 projected lifetime requires unit 년, strict 초과 and an explicit forecast metric'}
            $line=[string]@($panels[2].lines)[0]
            $bindings=@([regex]::Matches($line,'\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]'))
            if($bindings.Count -ne 2 -or $bindings[0].Groups[1].Value -ceq $bindings[1].Groups[1].Value){throw 'V7 interval requires two distinct month quantity bindings'}
            $lo=$Ledger.numbers[$bindings[0].Groups[1].Value];$hi=$Ledger.numbers[$bindings[1].Groups[1].Value]
            if($null -eq $lo -or $null -eq $hi -or $lo.unit -cne '개월' -or $hi.unit -cne '개월' -or $lo.qualifier -or $hi.qualifier -or $lo.currency -or $hi.currency -or $lo.period -or $hi.period -or $lo.value -le 0 -or $lo.value -gt $hi.value){throw 'V7 interval requires ordered positive exact quantities with the same month unit'}
            if($line -cnotmatch '^CIP(?:\s+(?:간격|Interval))?\s+\[\[[A-Za-z][A-Za-z0-9_-]*\]\]\s*[–~-]\s*\[\[[A-Za-z][A-Za-z0-9_-]*\]\]$'){throw 'V7 interval requires a canonical CIP range, never a before and after improvement'}
        }
        rollout {
            if($Stage.scope -cne 'proposal'){throw 'V7 gate board supports proposal scope only; actual rollout is not supported'}
            if(@($panels[0].table.rows).Count -ne 5 -or @($panels[1].steps).Count -ne 4){throw 'V7 gate board requires five coverage rows and four planned gates'}
            if(@($panels[2].lines).Count -ne 6 -or @($panels[3].lines).Count -ne 6){throw 'V7 gate board requires exactly six check and six acceptance statements'}
            $text=@($Stage.title,$Stage.subtitle,$Stage.takeaway)
            foreach($p in $panels){$text+=@($p.title)+@($p.steps)+@($p.lines);foreach($row in @($p.table.rows)){$text+=@($row)}}
            if(($text -join ' ') -match '(?:적용|조사|검증|시험|설계|승인|확대|개선)\s*완료|적용\s*달성|완료율|진도율|진척률|\bCompleted\b|\bDone\b|\bProgress\b|[✅☑]'){throw 'V7 proposal gate board rejects completion or progress claims'}
        }
    }
    return $true
}
