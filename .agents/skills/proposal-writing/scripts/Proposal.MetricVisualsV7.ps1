# Data-type-specific performance graphics. Source values remain native editable text.
. (Join-Path $PSScriptRoot 'Proposal.V7.Common.ps1')
function Get-ProposalMetricVisualsV7Layout($Stage){
    if($Stage.id -cne 'effects' -or $Stage.layout_profile -cne 'reference-v7' -or $Stage.visuals.kind -cne 'performance'){throw 'V7_METRICS_UNSUPPORTED: stage/profile/kind'}
    $p=@($Stage.panels)
    if($p.Count -ne 4 -or $p[0].kind -cne 'metrics' -or @($p[0].metrics).Count -ne 3 -or $p[1].kind -cne 'table' -or @($p[1].table.rows).Count -ne 5 -or @($p[1].table.headers).Count -ne 2 -or @($p[2].lines).Count -ne 4 -or @($p[3].lines).Count -ne 3){throw 'V7_METRICS_UNSUPPORTED: fixed content slots'}
    $ratios=@()
    foreach($m in @($p[0].metrics[0],$p[0].metrics[1])){
        if([string]$m.value_text -notmatch '^(\d+(?:\.\d+)?)%$'){throw 'V7_PERCENT_UNSUPPORTED: exact percentage required'}
        $value=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture)
        if($value -lt 0 -or $value -gt 100){throw 'V7_PERCENT_UNSUPPORTED: zero to one hundred'};$ratios+=@($value)
    }
    if([string]$p[0].metrics[2].value_text -notmatch '\s미만$'){throw 'V7_UPPER_BOUND_REQUIRED: strict concentration bound'}
    if([string]$p[1].table.rows[1][0] -notmatch '전망|예상|Forecast|Projected' -or [string]$p[1].table.rows[1][1] -notmatch '\s초과$'){throw 'V7_FORECAST_REQUIRED: source forecast and bound'}
    if([string]$p[2].lines[0] -notmatch '^CIP(?:\s+(?:간격|Interval))?\s+\d+(?:\.\d+)?개월\s*[~–-]\s*\d+(?:\.\d+)?개월$'){throw 'V7_RANGE_REQUIRED: canonical cleaning interval, not before/after'}
    $s=New-ProposalV7Scene $Stage;$c=$s.theme
    Add-PV7Section $s 'outcomes' 'canvas' 20 90 920 $p[0].title $c.navy
    Add-PV7Line $s 'metric-divider-0' 'canvas' 319 118 0 108 $c.edge
    Add-PV7Line $s 'metric-divider-1' 'canvas' 633 118 0 108 $c.edge
    Add-PV7Line $s 'metric-baseline' 'canvas' 20 238 920 0 $c.edge

    # Recovery: a continuous, source-bound water column, not an inferred flow rate.
    $m=$p[0].metrics[0]
    Add-PV7Text $s 'recovery-label' 'canvas' 32 119 264 19 $m.label 12 $c.blue $true 'left' 'label'
    Add-PV7Text $s 'recovery-value' 'canvas' 32 145 207 45 $m.value_text 35 $c.navy $true 'left' 'metric'
    Add-PV7Text $s 'recovery-detail' 'canvas' 33 201 199 18 $m.detail 11 $c.muted $false 'left' 'detail'
    Add-PV7Box $s 'recovery-column' 'canvas' 253 140 40 86 '#E7F0F5' $c.blue 'roundrect'
    if($ratios[0] -gt 0){$height=86*$ratios[0]/100;Add-PV7Box $s 'recovery-fill' 'recovery-column' 255 (226-$height) 36 $height $c.cyan}
    Add-PV7Line $s 'recovery-waterline' 'recovery-column' 256 (226-86*$ratios[0]/100) 34 0 $c.blue

    # Removal: one hundred neutral units; filled area equals the registered ratio.
    $m=$p[0].metrics[1]
    Add-PV7Text $s 'removal-label' 'canvas' 339 119 276 19 $m.label 12 $c.green $true 'left' 'label'
    for($i=0;$i -lt 100;$i++){
        $x=537+($i%10)*7;$y=148+[math]::Floor($i/10)*7
        Add-PV7Box $s ('removal-unit-'+$i) 'canvas' $x $y 5 5 '#E7ECEF'
        $fraction=[math]::Min(1,[math]::Max(0,$ratios[1]-$i))
        if($fraction -gt 0){Add-PV7Box $s ('removal-fill-'+$i) ('removal-unit-'+$i) $x $y (5*$fraction) 5 $c.green}
    }
    Add-PV7Text $s 'removal-value' 'canvas' 339 145 184 45 $m.value_text 35 $c.navy $true 'left' 'metric'
    Add-PV7Text $s 'removal-detail' 'canvas' 339 201 183 18 $m.detail 11 $c.muted $false 'left' 'detail'

    # Effluent: an open boundary, no unsupported baseline concentration scale.
    $m=$p[0].metrics[2]
    Add-PV7Text $s 'effluent-label' 'canvas' 654 119 274 19 $m.label 12 $c.blue $true 'left' 'label'
    Add-PV7Text $s 'effluent-value' 'canvas' 654 146 274 40 $m.value_text 29 $c.navy $true 'left' 'metric'
    Add-PV7Text $s 'effluent-detail' 'canvas' 654 201 274 18 $m.detail 11 $c.muted $false 'left' 'detail'
    Add-PV7Line $s 'effluent-open-interval' 'canvas' 654 191 191 0 $c.cyan $false 2
    Add-PV7Line $s 'effluent-boundary' 'canvas' 845 183 0 16 $c.blue $false 1
    Add-PV7Box $s 'effluent-boundary-open' 'canvas' 841 187 8 8 $c.white $c.blue 'ellipse'

    # Two emphasized life outcomes plus three concise source rows.
    Add-PV7Section $s 'details' 'canvas' 20 250 350 $p[1].title $c.navy
    $rows=@($p[1].table.rows)
    Add-PV7Box $s 'life-ratio-panel' 'canvas' 23 281 164 111 $c.mint
    Add-PV7Text $s 'life-ratio-label' 'life-ratio-panel' 31 289 148 20 ([string]$rows[0][0]) 11.5 $c.ink $true
    Add-PV7Text $s 'life-ratio-value' 'life-ratio-panel' 31 315 148 33 ([string]$rows[0][1]) 24 $c.green $true 'left' 'metric'
    Add-PV7Text $s 'life-combined-condition' 'life-ratio-panel' 31 360 148 29 'Filter + Residual Chlorine' 11 $c.muted $false 'left' 'detail'
    Add-PV7Box $s 'life-forecast-panel' 'canvas' 195 281 164 111 $c.sand
    Add-PV7Text $s 'life-forecast-label' 'life-forecast-panel' 203 289 148 20 ([string]$rows[1][0]) 11.5 $c.ink $true
    Add-PV7Text $s 'life-forecast-marker' 'life-forecast-panel' 203 360 148 14 'Projected' 10 $c.amber $true 'left' 'source'
    Add-PV7Text $s 'life-forecast-value' 'life-forecast-panel' 203 315 148 33 ([string]$rows[1][1]) 24 $c.amber $true 'left' 'metric'
    Add-PV7Text $s 'details-header-0' 'canvas' 27 399 155 17 $p[1].table.headers[0] 11 $c.muted $true 'left' 'detail'
    Add-PV7Text $s 'details-header-1' 'canvas' 199 399 160 17 $p[1].table.headers[1] 11 $c.muted $true 'left' 'detail'
    Add-PV7Line $s 'details-header-rule' 'canvas' 23 420 337 0 $c.edge
    for($i=2;$i -lt 5;$i++){
        $y=424+($i-2)*18
        Add-PV7Text $s ('detail-label-'+$i) 'canvas' 27 $y 155 17 ([string]$rows[$i][0]) 11.5 $c.ink $true
        Add-PV7Text $s ('detail-value-'+$i) 'canvas' 199 $y 160 17 ([string]$rows[$i][1]) 11.5 $c.ink
        if($i -lt 4){Add-PV7Line $s ('detail-row-rule-'+$i) 'canvas' 23 ($y+18) 337 0 $c.edge $false .5}
    }

    Add-PV7Section $s 'operation' 'canvas' 390 250 314 $p[2].title $c.navy
    Add-PV7Box $s 'cip-panel' 'canvas' 391 281 311 69 $c.light
    Add-PV7Text $s 'cip-range-text' 'cip-panel' 402 289 290 32 $p[2].lines[0] 12.5 $c.blue $true
    Add-PV7Text $s 'cip-range-label' 'cip-panel' 402 328 70 14 'Interval' 10 $c.muted $false 'left' 'source'
    Add-PV7Line $s 'cip-range-band' 'cip-panel' 485 335 112 0 $c.cyan $false 2
    Add-PV7Line $s 'cip-range-lower' 'cip-panel' 485 331 0 8 $c.cyan
    Add-PV7Line $s 'cip-range-upper' 'cip-panel' 597 331 0 8 $c.cyan
    $opIcons=@('monitor','factory','energy')
    for($i=1;$i -lt 4;$i++){
        $y=361+($i-1)*36
        Add-PV7Figure $s ('operation-figure-'+$i) 'canvas' $opIcons[$i-1] 393 ($y+1) 36 36 $c.blue
        Add-PV7Text $s ('operation-line-'+$i) 'canvas' 437 $y 265 31 $p[2].lines[$i] 11.5 $c.ink
    }

    Add-PV7Section $s 'qualitative' 'canvas' 724 250 216 $p[3].title $c.navy
    $badges=@('CAPEX','OPEX','ENV')
    for($i=0;$i -lt 3;$i++){
        $y=286+$i*60
        Add-PV7Box $s ('qualitative-badge-'+$i) 'canvas' 725 ($y+2) 48 24 $c.mint
        Add-PV7Text $s ('qualitative-badge-label-'+$i) 'canvas' 726 ($y+6) 46 16 $badges[$i] 11.5 $c.green $true 'center' 'label'
        Add-PV7Text $s ('qualitative-line-'+$i) 'canvas' 782 $y 155 46 $p[3].lines[$i] 11.5 $c.ink
        if($i -lt 2){Add-PV7Line $s ('qualitative-rule-'+$i) 'canvas' 725 ($y+51) 211 0 $c.edge $false .5}
    }
    return @(Complete-ProposalV7Scene $s $Stage)
}
