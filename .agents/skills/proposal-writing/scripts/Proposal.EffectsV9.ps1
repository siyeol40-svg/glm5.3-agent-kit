# Generic, source-bound performance graphics. Pure native specifications.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')

function Assert-ProposalEffectsV9Visuals($Stage,[switch]$AllowResolved){
    if($Stage.id -cne 'effects' -or $Stage.layout_profile -cne 'reference-v9' -or $null -eq $Stage.visuals){throw 'V9_EFFECTS_PROFILE: effects and visuals are required'}
    $v=$Stage.visuals;$kind=[string]$v.kind
    if($kind -cnotin @('relative_comparison','series_comparison')){throw 'V9_EFFECTS_PROFILE: unsupported comparison kind'}
    $allowed=@('kind')
    if($kind -ceq 'series_comparison'){$allowed+='metric_states'}
    if($AllowResolved){$allowed+='resolved_metrics'}
    foreach($key in @($v.PSObject.Properties.Name)){
        if($key -cnotin $allowed){throw ('V9_EFFECTS_PROFILE: unsupported visuals field '+$key)}
    }
    $p=@($Stage.panels)
    if($p.Count -ne 4 -or (@($p.role)-join ',') -cne 'outcomes,details,operation,boundary' -or $p[0].kind -cne 'metrics' -or $p[1].kind -cnotin @('table','bullets') -or $p[2].kind -cne 'bullets' -or $p[3].kind -cne 'bullets'){throw 'V9_EFFECTS_PROFILE: unsupported panel roles or kinds'}
    foreach($panel in $p){
        if($panel.kind -ceq 'bullets' -and (@($panel.lines).Count -lt 1 -or @($panel.lines).Count -gt 6)){throw 'V9_EFFECTS_PROFILE: one to six lines required'}
        if($panel.kind -ceq 'table'){
            $cols=@($panel.table.headers).Count;$rows=@($panel.table.rows)
            if($cols -notin @(2,3,4) -or $rows.Count -lt 1 -or $rows.Count -gt 5){throw 'V9_EFFECTS_PROFILE: unsupported table size'}
            foreach($row in $rows){if(@($row).Count -ne $cols){throw 'V9_EFFECTS_PROFILE: mismatched table row'}}
        }
    }
    $count=@($p[0].metrics).Count
    if($kind -ceq 'relative_comparison'){
        if($count -ne 1){throw 'V9_EFFECTS_RATIO: exactly one ratio metric is required'}
    }else{
        if($count -notin @(2,3) -or $v.metric_states -isnot [array] -or $v.metric_states.Count -ne $count){throw 'V9_EFFECTS_SERIES: two or three metrics with matching states required'}
        foreach($state in $v.metric_states){
            if($state -isnot [string] -or $state -cnotin @('actual','forecast')){throw 'V9_EFFECTS_FORECAST: unsupported metric state'}
        }
        if(($v.metric_states -join ',') -cnotmatch '^actual(?:,actual)*(?:,forecast)*$'){throw 'V9_EFFECTS_FORECAST: actuals must precede forecasts'}
    }
}

function Get-ProposalEffectsV9Numbers($Stage,$Ledger){
    Assert-ProposalEffectsV9Visuals $Stage
    $panel=$Stage.panels[0];$relative=$Stage.visuals.kind -ceq 'relative_comparison'
    $forecastPattern='전망|예상|예측|추정|\b(?:projected|projection|forecast(?:ed)?|estimated)\b'
    $culture=[Globalization.CultureInfo]::InvariantCulture
    $records=[Collections.Generic.List[object]]::new()
    $seenIds=@{};$seenLabels=@{};$comparisonRoot='';$comparisonBasis='';$comparisonUnit=''
    for($i=0;$i -lt @($panel.metrics).Count;$i++){
        $metric=$panel.metrics[$i]
        if([string]$metric.value_text -cnotmatch '^\[\[([A-Za-z][A-Za-z0-9_-]*)\]\]$'){throw 'V9_EFFECTS_NUMBER: each comparison value must be a single ledger binding'}
        $id=$Matches[1]
        if($seenIds.ContainsKey($id) -or -not $Ledger.numbers.ContainsKey($id)){throw ('V9_EFFECTS_NUMBER: missing or duplicated binding '+$id)}
        $seenIds[$id]=$true;$number=$Ledger.numbers[$id]
        if($null -eq $number.value -or $number.kind -cne 'reported' -or $number.qualifier -or $number.value -lt 0){throw 'V9_EFFECTS_NUMBER: an exact, nonnegative reported value is required'}
        $support=@($number.source_ids|Where-Object {$_ -cin @($panel.source_ids) -and $_ -cin @($Stage.source_ids) -and $Ledger.sources.ContainsKey([string]$_) -and $Ledger.sources[[string]$_].kind -cne 'synthetic_asset'})
        if($support.Count -eq 0){throw ('V9_EFFECTS_NUMBER: directly linked source is required for '+$id)}
        $label=Convert-ProposalDisplayText ([string]$metric.label) $Ledger.bindings 'V9 comparison label'
        $detail=if([string]$metric.detail){Convert-ProposalDisplayText ([string]$metric.detail) $Ledger.bindings 'V9 comparison basis'}else{''}
        $state=if($relative){'actual'}else{$Stage.visuals.metric_states[$i]}
        $marked=($label+' '+$detail) -match $forecastPattern
        $forecastSource=@($support|Where-Object {[string]$Ledger.sources[[string]$_].text -match $forecastPattern})
        if($state -ceq 'forecast'){
            if(-not $marked -or $forecastSource.Count -eq 0){throw 'V9_EFFECTS_FORECAST: both displayed text and directly linked evidence must mark a forecast'}
        }elseif($marked -or $forecastSource.Count -gt 0){
            throw 'V9_EFFECTS_FORECAST: projection cannot be labeled as an actual result'
        }
        if($relative){
            if($number.unit -cne '배' -or $number.currency -or $number.period -or $number.value -le 0 -or $detail -notmatch '기존|기준|대비|baseline|compared|before|previous'){throw 'V9_EFFECTS_RATIO: positive exact multiplier with an explicit comparison baseline is required'}
        }else{
            if(-not $number.unit -and -not $number.currency){throw 'V9_EFFECTS_SERIES: a common quantity unit or currency is required'}
            $root=[regex]::Replace($label,'(?i)\b(?:19|20)\d{2}\s*(?:년\s*(?:이후)?|onward\b)?|'+$forecastPattern+'|실적|actual','')
            $root=($root -replace '[\s\p{P}]','').ToUpperInvariant()
            $basis=($detail -replace '\s+','').ToUpperInvariant()
            $unit=@([string]$number.unit,[string]$number.currency,[string]$number.period)-join '|'
            if(-not $root -or -not $basis -or $seenLabels.ContainsKey($label)){throw 'V9_EFFECTS_SERIES: use distinct labels and an explicit common comparison basis'}
            $seenLabels[$label]=$true
            if($i -eq 0){$comparisonRoot=$root;$comparisonBasis=$basis;$comparisonUnit=$unit}
            if($root -cne $comparisonRoot -or $basis -cne $comparisonBasis -or $unit -cne $comparisonUnit){throw 'V9_EFFECTS_SERIES: measures, comparison basis, unit, currency and period must match'}
        }
        $records.Add([pscustomobject]@{value=[decimal]$number.value;display=[string]$number.display;state=[string]$state})
    }
    if(-not $relative -and @($records|Where-Object value -gt 0).Count -eq 0){throw 'V9_EFFECTS_SERIES: no positive value for a comparison scale'}
    return $records.ToArray()
}

function Get-ProposalEffectsV9Layout($Stage){
    Assert-ProposalEffectsV9Visuals $Stage -AllowResolved
    $p=$Stage.panels;$metrics=@($p[0].metrics);$records=@($Stage.visuals.resolved_metrics)
    $relative=$Stage.visuals.kind -ceq 'relative_comparison'
    if($records.Count -ne $metrics.Count){throw 'V9_EFFECTS_RESOLVED: matched ledger records are required'}
    $culture=[Globalization.CultureInfo]::InvariantCulture
    for($i=0;$i -lt $records.Count;$i++){
        $r=$records[$i];$expected=if($relative){'actual'}else{$Stage.visuals.metric_states[$i]}
        if($null -eq $r.value -or $r.state -cne $expected -or [string]$r.display -cne [string]$metrics[$i].value_text -or [string]$r.display -notmatch '^(?:[A-Z]{3} )?(\d+(?:,\d{3})*(?:\.\d+)?)'){
            throw 'V9_EFFECTS_RESOLVED: displayed comparison differs from the ledger record'
        }
        $encoded=[decimal]::Parse($Matches[1],[Globalization.NumberStyles]::Number,$culture)
        if($encoded -ne [decimal]$r.value -or $encoded -lt 0 -or ($relative -and ($encoded -le 0 -or $r.display -notmatch '배$'))){throw 'V9_EFFECTS_RESOLVED: invalid comparison magnitude'}
    }

    $s=New-ProposalV7Scene $Stage;$c=$s.theme
    Add-PV7Section $s 'outcomes' 'canvas' 20 91 920 $p[0].title
    Add-PV7Line $s 'effect-outcome-divider' 'canvas' 20 239 920 0 $c.edge
    if($relative){
        $m=$metrics[0];$value=[double]$records[0].value;$scale=[math]::Max(1,$value)
        Add-PV7Box $s 'effect-metric-panel' 'canvas' 20 119 314 108 $c.light
        Add-PV7Text $s 'effect-metric-0-label' 'effect-metric-panel' 34 130 285 24 $m.label 13 $c.navy $true 'left' 'label'
        Add-PV7Text $s 'effect-metric-0-value' 'effect-metric-panel' 34 158 285 41 $m.value_text 31 $c.blue $true 'left' 'metric'
        Add-PV7Text $s 'effect-metric-0-detail' 'effect-metric-panel' 35 204 284 18 $m.detail 11 $c.muted $false 'left' 'detail'
        Add-PV7Text $s 'effect-normalization-note' 'canvas' 359 121 570 20 '기존값을 1.0으로 환산한 상대 비교' 11.5 $c.muted
        Add-PV7Line $s 'effect-relative-zero' 'canvas' 480 146 0 77 $c.edge $false 1.25
        Add-PV7Text $s 'effect-baseline-label' 'canvas' 360 150 107 23 '기존 기준' 12 $c.ink $true 'left' 'label'
        Add-PV7Text $s 'effect-result-label' 'canvas' 360 190 107 23 '개선 후' 12 $c.ink $true 'left' 'label'
        Add-PV7Box $s 'effect-baseline-bar' 'canvas' 480 153 (354/$scale) 15 '#A9BDCD'
        Add-PV7Box $s 'effect-result-bar' 'canvas' 480 193 (354*$value/$scale) 15 $c.blue
        Add-PV7Text $s 'effect-baseline-index' 'canvas' 848 148 84 25 '1.0' 16 $c.muted $true
        Add-PV7Text $s 'effect-result-index' 'canvas' 848 188 84 25 $m.value_text 16 $c.blue $true
    }else{
        $scale=[double](($records|Measure-Object value -Maximum).Maximum)
        if($scale -le 0){throw 'V9_EFFECTS_RESOLVED: no positive scale'}
        Add-PV7Text $s 'effect-series-basis' 'canvas' 31 114 898 17 $metrics[0].detail 11 $c.muted $false 'left' 'detail'
        $rowH=32.0
        $top=if($metrics.Count -eq 2){150.0}else{134.0}
        for($i=0;$i -lt $metrics.Count;$i++){
            $row='effect-series-row-'+$i;$y=$top+$i*$rowH;$m=$metrics[$i];$r=$records[$i]
            $isForecast=$r.state -ceq 'forecast'
            Add-PV7Box $s $row 'canvas' 20 $y 920 30 $(if($isForecast){$c.sand}else{$c.light})
            Add-PV7Text $s ('effect-metric-'+$i+'-label') $row 31 ($y+2) 226 28 $m.label 11.5 $c.navy $true 'left' 'label'
            if($r.value -gt 0){
                Add-PV7Box $s ('effect-series-bar-'+$i) $row 269 ($y+8) (327*[double]$r.value/$scale) 14 $(if($isForecast){'#E7C990'}else{$c.blue}) $(if($isForecast){$c.amber}else{''})
            }
            Add-PV7Text $s ('effect-metric-'+$i+'-value') $row 608 ($y+1) 239 27 $m.value_text 20 $(if($isForecast){$c.amber}else{$c.navy}) $true 'left' 'metric'
            Add-PV7Text $s ('effect-series-state-'+$i) $row 860 ($y+5) 67 20 $(if($isForecast){'전망'}else{'실적'}) 11.5 $(if($isForecast){$c.amber}else{$c.blue}) $true 'center' 'label'
        }
        Add-PV7Line $s 'effect-series-zero' 'canvas' 269 $top 0 ($rowH*$metrics.Count-2) $c.muted $false .8
    }

    Add-PV7Line $s 'effect-details-divider' 'canvas' 443 254 0 215 $c.edge
    Add-PV7Line $s 'effect-operation-divider' 'canvas' 699 254 0 215 $c.edge
    Add-PV7Section $s 'details' 'canvas' 20 252 409 $p[1].title
    Add-PV7Section $s 'operation' 'canvas' 458 252 227 $p[2].title
    Add-PV7Section $s 'boundary' 'canvas' 714 252 226 $p[3].title $c.amber

    if($p[1].kind -ceq 'table'){
        $headers=@($p[1].table.headers);$rows=@($p[1].table.rows)
        $colWidths=switch($headers.Count){2{@(176,234)}3{@(106,152,152)}4{@(94,105,105,106)}}
        $tableX=20.0;$tableY=281.0;$headerH=20.0;$rowH=(470-$tableY-$headerH)/$rows.Count
        for($i=0;$i -lt $headers.Count;$i++){
            $colWidth=$colWidths[$i];$headerId='effect-table-head-'+$i
            Add-PV7Box $s $headerId 'canvas' $tableX $tableY $colWidth $headerH $c.navy
            Add-PV7Text $s ($headerId+'-text') $headerId ($tableX+5) ($tableY+2) ($colWidth-10) 16 $headers[$i] 11.5 $c.white $true
            for($j=0;$j -lt $rows.Count;$j++){
                $y=$tableY+$headerH+$j*$rowH;$id='effect-table-'+$j+'-'+$i
                $fill=if($j%2 -eq 0){$c.light}else{$c.white}
                Add-PV7Box $s $id 'canvas' $tableX $y $colWidth $rowH $fill
                Add-PV7Text $s ($id+'-text') $id ($tableX+5) ($y+1.5) ($colWidth-10) ($rowH-3) ([string]$rows[$j][$i]) 11.5 $c.ink ($i -eq 0)
            }
            $tableX+=$colWidth
        }
    }

    function Add-EffectList($Panel,[string]$Prefix,[double]$X,[double]$W,[string]$Accent){
        $lines=@($Panel.lines);$rowH=188.0/$lines.Count
        for($i=0;$i -lt $lines.Count;$i++){
            $y=281+$i*$rowH;$id=$Prefix+'-'+$i;$state='';$fill=$c.light;$ink=$c.ink
            if($Panel.line_states){
                switch -CaseSensitive ($Panel.line_states[$i]){
                    'supported' {}
                    'hypothesis' {$state='가설';$fill=$c.sand;$ink=$c.amber}
                    'boundary' {$state='조건';$ink=$c.blue}
                    'unknown' {$state='미확인';$ink=$c.muted}
                    default {throw 'V9_EFFECTS_PROFILE: unsupported detail state'}
                }
            }
            $fillHeight=[math]::Min($rowH-2,46.0)
            Add-PV7Box $s ($id+'-row') 'canvas' $X $y $W $fillHeight $fill
            Add-PV7Box $s ($id+'-accent') ($id+'-row') ($X+5) ($y+5) 3 12 $Accent
            $offset=13
            if($state){
                Add-PV7Text $s ($id+'-state') ($id+'-row') ($X+$offset) ($y+1) 48 ($fillHeight-2) $state 11 $ink $true 'left' 'detail'
                $offset+=52
            }
            Add-PV7Text $s ($id+'-text') ($id+'-row') ($X+$offset) ($y+1) ($W-$offset-5) ($fillHeight-2) $lines[$i] 11.5 $ink
        }
    }
    if($p[1].kind -ceq 'bullets'){Add-EffectList $p[1] 'effect-details' 20 410 $c.blue}
    Add-EffectList $p[2] 'effect-operation' 458 227 $c.blue
    Add-EffectList $p[3] 'effect-boundary' 714 226 $c.amber

    $shapes=@(Complete-ProposalV7Scene $s $Stage)
    foreach($shape in $shapes){$shape.layout_revision='proposal-reference-r9'}
    return $shapes
}
