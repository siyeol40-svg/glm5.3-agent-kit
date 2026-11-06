# Fixed, editable general EDR principle. No Office, image, network or model calls.
# Physical relation: water runs ALONG membrane channels; selected ions cross membranes.
# General principle source: https://www.watertechnologies.com/products/electrodialysis-reversal-edr
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')

function Get-ProposalMechanismV7Layout($Stage) {
    $p=@($Stage.panels)
    if($Stage.id -cne 'cause' -or $Stage.layout_profile -cne 'reference-v7' -or $Stage.visuals.kind -cne 'edr_mechanism' -or $Stage.visuals.scope -cne 'general_principle'){
        throw 'MECHANISM_V7_UNSUPPORTED_SCOPE: choose the registered general EDR principle only'
    }
    if($p.Count -ne 4){throw 'MECHANISM_V7_UNSUPPORTED_SLOT: four panels required'}
    $roles=@('system','evidence','causal','boundary');$kinds=@('bullets','table','bullets','bullets')
    foreach($i in 0..3){
        if($p[$i].role -cne $roles[$i] -or $p[$i].kind -cne $kinds[$i]){throw 'MECHANISM_V7_UNSUPPORTED_SLOT: fixed role/kind order required'}
        if($null -ne $p[$i].outcome){throw 'MECHANISM_V7_UNSUPPORTED_SLOT: action outcome is not a mechanism field'}
    }
    if(@($p[0].lines).Count -ne 4 -or @($p[2].lines).Count -ne 4 -or @($p[3].lines).Count -ne 3){throw 'MECHANISM_V7_UNSUPPORTED_LINES: four features, four parallel traits and three boundaries required'}
    if(@($p[1].table.headers).Count -ne 2 -or @($p[1].table.rows).Count -ne 5){throw 'MECHANISM_V7_UNSUPPORTED_TABLE: five evidence rows and two columns required'}
    foreach($row in $p[1].table.rows){if(@($row).Count -ne 2){throw 'MECHANISM_V7_UNSUPPORTED_TABLE: evidence row must match both columns'}}
    foreach($panel in @($p[0],$p[2],$p[3])){
        if($null -ne $panel.line_states){
            if(@($panel.line_states).Count -ne @($panel.lines).Count){throw 'MECHANISM_V7_UNSUPPORTED_STATE: one state per statement required'}
            foreach($state in $panel.line_states){if($state -cne 'supported'){throw 'MECHANISM_V7_UNSUPPORTED_STATE: this fixed general-principle variant supports sourced statements only'}}
        }
    }
    # Bind source statements by declared physical feature, never by list position.
    # This closed glossary is the registered variant's supported description contract.
    $featureMap=$Stage.visuals.feature_indices
    $featureKeys=@('electric_field','selective_membrane','separate_channels','water_channel')
    if($null -eq $featureMap){throw 'MECHANISM_V7_FEATURE_MAPPING_REQUIRED: declare all four feature indices'}
    $mapKeys=if($featureMap -is [Collections.IDictionary]){@($featureMap.Keys)}else{@($featureMap.PSObject.Properties.Name)}
    if($mapKeys.Count -ne 4){throw 'MECHANISM_V7_FEATURE_MAPPING_KEYS: exactly four registered feature keys required'}
    foreach($key in $featureKeys){if($key -cnotin $mapKeys){throw 'MECHANISM_V7_FEATURE_MAPPING_KEYS: missing or unsupported feature key'}}
    $usedIndices=@{}
    foreach($key in $featureKeys){
        $index=$featureMap.$key
        if(($index -isnot [int] -and $index -isnot [long]) -or $index -lt 0 -or $index -gt 3){throw 'MECHANISM_V7_FEATURE_MAPPING_INDEX: integer indices zero through three required'}
        if($usedIndices.ContainsKey([int]$index)){throw 'MECHANISM_V7_FEATURE_MAPPING_DUPLICATE: each feature needs its own source statement'}
        $usedIndices[[int]$index]=$true
        $line=[string]$p[0].lines[[int]$index]
        $matchesFeature=switch($key){
            'electric_field' {$line -match '(?i)(?<![a-z])Electric\s+Field(?![a-z])'}
            'selective_membrane' {$line -match '(?i)(?<![a-z])(?:Selective\s+Membrane|Cation|Anion)(?![a-z])'}
            'separate_channels' {($line -match '(?i)(?<![a-z])Diluate(?![a-z])') -and ($line -match '(?i)(?<![a-z])Concentrate(?![a-z])')}
            'water_channel' {($line -match '(?i)(?<![a-z])Water(?![a-z])') -and ($line -match '(?i)유로|(?<![a-z])channel(?![a-z])|(?<![a-z])surface(?![a-z])|표면')}
        }
        if(-not $matchesFeature){throw ('MECHANISM_V7_FEATURE_MAPPING_TEXT: mapped statement lacks the registered glossary markers for '+$key)}
    }
    # Optional references pair an observed selection condition with a sourced
    # general trait. They are reading references, not causal or test outcomes.
    $conditionLinks=$Stage.visuals.condition_links
    $hasConditionLinks=$null -ne $conditionLinks
    $byCondition=@{};$byTrait=@{}
    if($hasConditionLinks){
        function ConditionKeys($Value){if($Value -is [Collections.IDictionary]){return @($Value.Keys)};return @($Value.PSObject.Properties.Name)}
        $keys=@(ConditionKeys $conditionLinks);$requiredKeys=@('silica','bio','variation')
        if($keys.Count -ne 3){throw 'MECHANISM_V7_CONDITION_LINK_KEYS: exactly silica, bio and variation required'}
        foreach($key in $requiredKeys){
            if($key -cnotin $keys){throw 'MECHANISM_V7_CONDITION_LINK_KEYS: missing or unsupported reference type'}
            $pair=$conditionLinks.$key;$pairKeys=@(ConditionKeys $pair)
            if($null -eq $pair -or $pairKeys.Count -ne 2 -or 'condition' -cnotin $pairKeys -or 'trait' -cnotin $pairKeys){throw 'MECHANISM_V7_CONDITION_LINK_PAIR: only condition and trait indices are permitted'}
            $condition=$pair.condition;$trait=$pair.trait
            if(($condition -isnot [int] -and $condition -isnot [long]) -or $condition -lt 0 -or $condition -gt 4 -or ($trait -isnot [int] -and $trait -isnot [long]) -or $trait -lt 0 -or $trait -gt 3){throw 'MECHANISM_V7_CONDITION_LINK_INDEX: condition zero through four and trait zero through three must be integers'}
            if($byCondition.ContainsKey([int]$condition) -or $byTrait.ContainsKey([int]$trait)){throw 'MECHANISM_V7_CONDITION_LINK_DUPLICATE: each condition and trait has one reference type'}
            $conditionText=[string]$p[1].table.rows[[int]$condition][0];$traitText=[string]$p[2].lines[[int]$trait]
            $matchesRelation=switch($key){
                'silica' {($conditionText -match '(?i)(?<![a-z])Silica(?![a-z])') -and ($traitText -match '(?i)(?<![a-z])Silica(?![a-z])')}
                'bio' {($conditionText -match '(?i)(?<![a-z])(?:Temp|Organic|Biogrowth)(?![a-z])') -and ($traitText -match '(?i)(?<![a-z])Chlorine(?![a-z])')}
                'variation' {($conditionText -match '(?i)(?<![a-z])Feed(?:\s+Quality)?(?![a-z])|변동') -and ($traitText -match '(?i)(?<![a-z])(?:Voltage|TDS)(?![a-z])')}
            }
            if(-not $matchesRelation){throw ('MECHANISM_V7_CONDITION_LINK_TEXT: mapped condition and trait lack the registered markers for '+$key)}
            $info=[pscustomobject]@{key=$key;condition=[int]$condition;trait=[int]$trait;symbol=@{silica='A';bio='B';variation='C'}[$key]}
            $byCondition[[int]$condition]=$info;$byTrait[[int]$trait]=$info
        }
    }
    $s=New-ProposalV7Scene $Stage;$c=$s.theme
    function Meta($Pairs){foreach($key in $Pairs.Keys){$s.shapes[$s.shapes.Count-1]|Add-Member -NotePropertyName $key -NotePropertyValue $Pairs[$key]}}
    function ConditionBadge([string]$Id,[string]$Parent,[double]$X,[double]$Y,$Info,[string]$RelationRole){
        $color=switch($Info.key){'silica'{$c.blue};'bio'{$c.green};'variation'{$c.amber}}
        Add-PV7Box $s $Id $Parent $X $Y 18 18 $c.white $color 'roundrect'
        Add-PV7Text $s ($Id+'-label') $Id $X ($Y+1) 18 16 $Info.symbol 11.5 $color $true 'center' 'label'
        Meta @{condition_link_key=$Info.key;condition_index=$Info.condition;trait_index=$Info.trait;reference_symbol=$Info.symbol;relation_role=$RelationRole;relation_kind='condition_trait_reference'}
    }
    $heroWidth=if($hasConditionLinks){550}else{564}

    # The hero owns its four near-feature explanations and all native diagram parts.
    Add-PV7Box $s 'mechanism-system' 'canvas' 20 98 $heroWidth 267 $c.white $c.edge 'roundrect'
    Add-PV7Text $s 'mechanism-system-title' 'mechanism-system' 32 106 325 22 $p[0].title 13.5 $c.navy $true 'left' 'section'
    Add-PV7Text $s 'mechanism-scope' 'mechanism-system' 368 108 ($heroWidth-360) 18 '일반 원리 · 실제 설비 배치도 아님' 11 $c.muted $false 'right' 'detail'
    Add-PV7Box $s 'edr-diagram' 'mechanism-system' 32 174 ($heroWidth-24) 150 $c.light '' 'rect'
    Meta @{mechanism_role='general_edr';diagram_scope='general_principle';source_url='https://www.watertechnologies.com/products/electrodialysis-reversal-edr'}

    # Positive anode at left; negative cathode at right. The central Diluate channel
    # loses anions through AEM to the left and cations through CEM to the right.
    Add-PV7Box $s 'edr-anode' 'edr-diagram' 58 212 8 67 $c.navy '' 'rect'
    Add-PV7Box $s 'edr-cathode' 'edr-diagram' 462 212 8 67 $c.navy '' 'rect'
    Add-PV7Text $s 'edr-anode-label' 'edr-diagram' 40 187 80 18 'Anode +' 11.5 $c.navy $true 'center' 'label'
    Add-PV7Text $s 'edr-cathode-label' 'edr-diagram' 444 187 108 18 'Cathode −' 11.5 $c.navy $true 'center' 'label'
    Add-PV7Line $s 'edr-field' 'edr-diagram' 104 207 323 0 $c.muted $true .8
    Meta @{mechanism_role='electric_field';direction='anode_to_cathode'}

    $memX=@(126,210,294,378);$types=@('CEM','AEM','CEM','AEM')
    foreach($i in 0..3){
        $color=if($types[$i] -ceq 'CEM'){$c.blue}else{$c.cyan}
        Add-PV7Box $s ('edr-membrane-'+$i) 'edr-diagram' $memX[$i] 212 10 84 $color '' 'rect'
        Meta @{mechanism_role='selective_membrane';membrane_type=$types[$i];source_url='https://www.watertechnologies.com/products/electrodialysis-reversal-edr'}
        Add-PV7Text $s ('edr-membrane-label-'+$i) 'edr-diagram' ($memX[$i]-13) 303 39 16 $types[$i] 11 $color $true 'center' 'detail'
    }
    $channelX=@(142,226,310);$channelW=62
    foreach($i in 0..2){
        $label=if($i -eq 1){'Diluate'}else{'Concentrate'};$color=if($i -eq 1){$c.green}else{$c.blue}
        Add-PV7Text $s ('edr-channel-label-'+$i) 'edr-diagram' ($channelX[$i]-12) 183 82 18 $label 11.5 $color $true 'center' 'label'
        Add-PV7Line $s ('edr-water-flow-'+$i) 'edr-diagram' ($channelX[$i]+29) 216 0 75 $c.muted $true 1.1
        Meta @{mechanism_role='water_flow';channel_type=$label;direction='along_membrane';source_url='https://www.watertechnologies.com/products/electrodialysis-reversal-edr'}
    }

    # The transfer arrows are native editable shapes. Their positive bounds and
    # primitive direction avoid negative-width lines, image arrows and rotation.
    Add-PV7Box $s 'edr-cation-transfer' 'edr-diagram' 262 226 75 10 $c.blue '' 'rightArrow'
    Meta @{mechanism_role='ion_transfer';ion_type='cation';crosses_membrane='edr-membrane-2';direction='toward_cathode'}
    Add-PV7Box $s 'edr-anion-transfer' 'edr-diagram' 179 265 75 10 $c.cyan '' 'leftArrow'
    Meta @{mechanism_role='ion_transfer';ion_type='anion';crosses_membrane='edr-membrane-1';direction='toward_anode'}
    foreach($ion in @(@('cation-origin',246,222,'+',$c.blue),@('cation-destination',337,222,'+',$c.blue),@('anion-origin',246,260,'−',$c.cyan),@('anion-destination',163,260,'−',$c.cyan))){
        Add-PV7Box $s ('edr-'+$ion[0]+'-disc') 'edr-diagram' $ion[1] $ion[2] 17 17 $c.white $ion[4] 'ellipse'
        Add-PV7Text $s ('edr-'+$ion[0]+'-sign') 'edr-diagram' $ion[1] ($ion[2]-.4) 17 17 $ion[3] 11.5 $ion[4] $true 'center' 'label'
    }

    $callouts=@(
        @('electric',32,136,215,30,'edr-field','electric_field'),
        @('selective',270,136,($heroWidth-262),30,'edr-membrane-2','selective_membrane'),
        @('streams',310,331,($heroWidth-302),30,'edr-channel-label-1','separate_channels'),
        @('water',32,331,265,30,'edr-water-flow-0','water_channel')
    )
    foreach($v in $callouts){$featureKey=[string]$v[6];$lineIndex=[int]$featureMap.$featureKey;Add-PV7Text $s ('edr-feature-'+$v[0]) 'mechanism-system' $v[1] $v[2] $v[3] $v[4] $p[0].lines[$lineIndex] 11.5 $c.ink $false 'left' 'body';Meta @{mechanism_role='feature_callout';feature_target=$v[5];feature_key=$featureKey}}
    # Short leaders associate explanations with features; these do not join facts.
    Add-PV7Line $s 'edr-field-leader' 'mechanism-system' 95 164 0 17 $c.edge $false .7
    Add-PV7Line $s 'edr-selective-leader' 'mechanism-system' 395 164 0 17 $c.edge $false .7

    # Conditions are comparison rows, separate from the general physical principle.
    Add-PV7Text $s 'mechanism-evidence-title' 'canvas' 604 105 328 23 $p[1].title 13.5 $c.navy $true 'left' 'section'
    Add-PV7Box $s 'mechanism-evidence' 'canvas' 596 135 344 230 $c.white $c.edge 'rect'
    Add-PV7Box $s 'mechanism-evidence-header' 'mechanism-evidence' 596 135 344 25 $c.navy '' 'rect'
    Add-PV7Text $s 'evidence-header-0' 'mechanism-evidence-header' 605 139 116 18 $p[1].table.headers[0] 11.5 $c.white $true 'left' 'label'
    Add-PV7Text $s 'evidence-header-1' 'mechanism-evidence-header' 735 139 196 18 $p[1].table.headers[1] 11.5 $c.white $true 'left' 'label'
    foreach($i in 0..4){
        $y=160+$i*41
        if($i%2 -eq 0){Add-PV7Box $s ('evidence-row-fill-'+$i) 'mechanism-evidence' 596 $y 344 41 $c.light '' 'rect'}
        if($i -gt 0){Add-PV7Line $s ('evidence-row-rule-'+$i) 'mechanism-evidence' 604 $y 328 0 $c.edge $false .6}
        Add-PV7Text $s ('evidence-cell-'+$i+'-0') 'mechanism-evidence' 605 ($y+6) 119 31 $p[1].table.rows[$i][0] 11.5 $c.ink $true 'left' 'body'
        Add-PV7Text $s ('evidence-cell-'+$i+'-1') 'mechanism-evidence' 735 ($y+6) 196 31 $p[1].table.rows[$i][1] 11.5 $c.ink $false 'left' 'body'
        if($byCondition.ContainsKey($i)){ConditionBadge ('condition-reference-'+$i) 'canvas' 574 ($y+7) $byCondition[$i] 'condition'}
    }

    # These four properties are parallel, with no arrow between one and the next.
    Add-PV7Box $s 'mechanism-response' 'canvas' 20 376 $heroWidth 95 $c.white '' 'rect'
    Add-PV7Text $s 'mechanism-response-title' 'mechanism-response' 32 379 $(if($hasConditionLinks){336}else{540}) 21 $p[2].title 13.5 $c.navy $true 'left' 'section'
    if($hasConditionLinks){Add-PV7Text $s 'condition-reference-legend' 'mechanism-response' 392 381 166 16 '조건·특성 참조' 11 $c.muted $false 'right' 'detail'}
    foreach($i in 0..3){
        $x=32+($i%2)*278;$y=406+[math]::Floor($i/2)*32
        $textX=$x+10;$textWidth=if($hasConditionLinks -and $i%2){238}else{258}
        if($byTrait.ContainsKey($i)){
            ConditionBadge ('trait-reference-'+$i) 'mechanism-response' $x ($y+3) $byTrait[$i] 'trait'
            $textX=$x+26;$textWidth=if($i%2){222}else{242}
        }else{Add-PV7Box $s ('response-marker-'+$i) 'mechanism-response' $x ($y+3) 3 19 $c.blue '' 'rect'}
        Add-PV7Text $s ('response-line-'+$i) 'mechanism-response' $textX $y $textWidth 30 $p[2].lines[$i] 11.5 $c.ink $false 'left' 'body'
    }
    Add-PV7Box $s 'mechanism-boundary' 'canvas' 596 376 344 95 '#FBF6EC' '' 'rect'
    Add-PV7Box $s 'mechanism-boundary-accent' 'mechanism-boundary' 596 376 3 95 $c.amber '' 'rect'
    Add-PV7Text $s 'mechanism-boundary-title' 'mechanism-boundary' 608 379 320 21 $p[3].title 13.5 $c.amber $true 'left' 'section'
    foreach($i in 0..2){Add-PV7Text $s ('boundary-line-'+$i) 'mechanism-boundary' 608 (407+$i*20) 320 19 $p[3].lines[$i] 11.5 $c.ink $false 'left' 'body'}
    return @(Complete-ProposalV7Scene $s $Stage)
}
