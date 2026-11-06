# Deterministic editable-shape layouts. No COM, file, image, model or network calls.
function Get-ProposalLayout([object]$Stage) {
    if($Stage.layout_profile -ceq 'reference-v10-actions'){
        . (Join-Path $PSScriptRoot 'Proposal.ActionsV10.ps1')
        return @(Get-ProposalActionsV10Layout $Stage)
    }
    if($Stage.layout_profile -ceq 'reference-v9'){
        switch -CaseSensitive ([string]$Stage.id){
            'cause' {. (Join-Path $PSScriptRoot 'Proposal.CauseV9.ps1');return @(Get-ProposalCauseV9Layout $Stage)}
            'effects' {. (Join-Path $PSScriptRoot 'Proposal.EffectsV9.ps1');return @(Get-ProposalEffectsV9Layout $Stage)}
            default {throw ('V9 unsupported stage: '+$Stage.id)}
        }
    }
    if($Stage.layout_profile -ceq 'reference-v8-actions'){
        if($Stage.id -cne 'actions'){throw ('V8 actions unsupported stage: '+$Stage.id)}
        . (Join-Path $PSScriptRoot 'Proposal.ActionsGridV8.ps1')
        return @(Get-ProposalActionsGridV8Layout $Stage)
    }
    if($Stage.layout_profile -ceq 'reference-v7'){
        switch -CaseSensitive ([string]$Stage.id){
            'cause' {. (Join-Path $PSScriptRoot 'Proposal.MechanismV7.ps1');return @(Get-ProposalMechanismV7Layout $Stage)}
            'effects' {. (Join-Path $PSScriptRoot 'Proposal.MetricVisualsV7.ps1');return @(Get-ProposalMetricVisualsV7Layout $Stage)}
            'rollout' {. (Join-Path $PSScriptRoot 'Proposal.GateBoardV7.ps1');return @(Get-ProposalGateBoardV7Layout $Stage)}
            default {throw ('V7 unsupported stage: '+$Stage.id)}
        }
    }
    if($Stage.layout_profile -ceq 'reference-v6'){
        . (Join-Path $PSScriptRoot 'Proposal.DenseLayoutV6.ps1')
        $specs=@(Get-ProposalDenseV6Layout $Stage)
        if($Stage.id -ceq 'actions'){
            . (Join-Path $PSScriptRoot 'Proposal.Frame.ps1')
            return @(Get-ProposalDesign98FrameLayout $Stage $specs)
        }
        return $specs
    }
    if($Stage.layout_profile -ceq 'reference-v5-problem'){
        . (Join-Path $PSScriptRoot 'Proposal.ProblemLayoutV5.ps1')
        $specs=@(Get-ProposalProblemV5Layout $Stage)
        . (Join-Path $PSScriptRoot 'Proposal.Frame.ps1')
        return @(Get-ProposalDesign98FrameLayout $Stage $specs)
    }
    if($Stage.layout_profile -eq 'reference-v4'){
        . (Join-Path $PSScriptRoot 'Proposal.Composition.ps1')
        return @(Get-ProposalCompositionLayout $Stage)
    }
    if($Stage.layout_profile -eq 'reference-v3'){
        . (Join-Path $PSScriptRoot 'Proposal.Design.ps1')
        return @(Get-ProposalDesignLayout $Stage)
    }
    if($Stage.layout_profile -eq 'reference-v2'){
        . (Join-Path $PSScriptRoot 'Proposal.Reference.ps1')
        return @(Get-ProposalReferenceLayout $Stage)
    }
    $labels=@{problem='문제 현상';cause='원인 분석';actions='개선 사항';effects='효과 파악';rollout='횡전개'}
    $numbers=@{problem='02';cause='03';actions='04';effects='05';rollout='06'}
    $stageId=[string]$Stage.id
    if(-not $labels.ContainsKey($stageId)){throw 'Unsupported proposal stage'}
    if([string]::IsNullOrWhiteSpace([string]$Stage.title) -or [string]::IsNullOrWhiteSpace([string]$Stage.takeaway)){throw 'Stage title and takeaway are required'}
    $panels=@($Stage.panels)
    $limit=if($stageId -eq 'actions'){6}else{4}
    if($panels.Count -lt 1 -or $panels.Count -gt $limit){throw ('Unsupported panel count for '+$stageId)}
    $shapes=New-Object 'Collections.Generic.List[object]'
    $navy='#082C64';$ink='#172B4D';$border='#CCD6E4';$light='#F3F6FB';$red='#B42318';$green='#1F7A49'
    function Add-PLSpec([string]$Id,[string]$Role,[string]$Parent,[string]$Kind,[double]$X,[double]$Y,[double]$W,[double]$H,[string]$Text='',[double]$Font=14,[string]$Fill='',[string]$Color='#172B4D',[bool]$Bold=$false,[string]$Line='') {
        $shapes.Add([pscustomobject][ordered]@{id=$Id;role=$Role;parent=$Parent;kind=$Kind;x=$X;y=$Y;w=$W;h=$H;text=$Text;font_size=$Font;font_bold=$Bold;fill=$Fill;color=$Color;line_color=$Line})
    }
    Add-PLSpec 'canvas' 'background' '' 'rect' 0 0 960 540 '' 14 '#FFFFFF' $ink $false ''
    Add-PLSpec 'page-band' 'decoration' 'canvas' 'rect' 0 0 76 82 '' 14 $navy
    Add-PLSpec 'page-number' 'label' 'page-band' 'text' 12 19 52 42 $numbers[$stageId] 28 '' '#FFFFFF' $true
    Add-PLSpec 'section-name' 'section' 'canvas' 'text' 90 17 126 36 $labels[$stageId] 24 '' $navy $true
    Add-PLSpec 'page-title' 'title' 'canvas' 'text' 230 17 706 36 ([string]$Stage.title) 26 '' $navy $true
    Add-PLSpec 'page-subtitle' 'subtitle' 'canvas' 'text' 90 58 846 30 ([string]$Stage.subtitle) 14 '' $navy
    Add-PLSpec 'header-rule' 'decoration' 'canvas' 'line' 24 96 912 0 '' 14 '' $ink $false $border
    Add-PLSpec 'footer-band' 'decoration' 'canvas' 'rect' 16 478 928 44 '' 14 $navy
    Add-PLSpec 'page-takeaway' 'conclusion' 'footer-band' 'text' 30 484 900 32 ([string]$Stage.takeaway) 14 '' '#FFFFFF' $true

    # Coordinate choices depend only on the stage and supported panel count.
    $boxes=@()
    if($stageId -eq 'actions'){
        $widths=@{1=912.0;2=448.0;3=293.333333;4=216.0;5=169.6;6=138.666667}
        $w=$widths[$panels.Count]
        for($i=0;$i -lt $panels.Count;$i++){$boxes+=,@((24+$i*($w+16)),112,$w,350)}
    } elseif($panels.Count -eq 1){$boxes+=,@(24,112,912,350)
    } elseif($panels.Count -eq 2){$boxes+=,@(24,112,448,350);$boxes+=,@(488,112,448,350)
    } elseif($panels.Count -eq 3){
        if($stageId -eq 'rollout'){$boxes+=,@(24,112,440,350);$boxes+=,@(480,112,456,165);$boxes+=,@(480,293,456,169)}
        elseif($stageId -eq 'cause'){$boxes+=,@(24,112,300,350);$boxes+=,@(340,112,596,165);$boxes+=,@(340,293,596,169)}
        else{$boxes+=,@(24,112,448,210);$boxes+=,@(488,112,448,210);$boxes+=,@(24,338,912,124)}
    } else {
        if($stageId -eq 'problem'){$boxes+=,@(24,112,294,210);$boxes+=,@(334,112,602,210);$boxes+=,@(24,338,380,124);$boxes+=,@(420,338,516,124)}
        elseif($stageId -eq 'cause'){$boxes+=,@(24,112,300,210);$boxes+=,@(340,112,596,210);$boxes+=,@(24,338,440,124);$boxes+=,@(480,338,456,124)}
        else{$boxes+=,@(24,112,448,165);$boxes+=,@(488,112,448,165);$boxes+=,@(24,293,448,169);$boxes+=,@(488,293,448,169)}
    }
    for($p=0;$p -lt $panels.Count;$p++){
        $panel=$panels[$p];$box=$boxes[$p];$panelId='panel-'+($p+1)
        $x=[double]$box[0];$y=[double]$box[1];$w=[double]$box[2];$h=[double]$box[3]
        $accent=if($panel.tone -eq 'danger'){$red}elseif($panel.tone -eq 'success'){$green}else{$navy}
        Add-PLSpec $panelId 'panel' 'canvas' 'rect' $x $y $w $h '' 14 '#FFFFFF' $ink $false $border
        Add-PLSpec ($panelId+'-bar') 'decoration' $panelId 'rect' $x $y $w 32 '' 14 $accent
        Add-PLSpec ($panelId+'-heading') 'section' ($panelId+'-bar') 'text' ($x+10) ($y+3) ($w-20) 26 ([string]$panel.title) 16 '' '#FFFFFF' $true
        $cx=$x+10;$cy=$y+42;$cw=$w-20;$ch=$h-52
        $sourceLabel=[string]$panel.source_label
        if(-not $sourceLabel -and @($panel.source_ids).Count -gt 0 -and $panel.source_ids){$sourceLabel='근거: '+(@($panel.source_ids) -join ', ')}
        if($sourceLabel){
            Add-PLSpec ($panelId+'-source') 'source' $panelId 'text' ($x+10) ($y+$h-23) ($w-20) 17 $sourceLabel 12 '' '#52647C'
            $ch-=24
        }
        $kind=[string]$panel.kind
        if(-not $kind){$kind='bullets'}
        switch($kind){
            'bullets' {
                $lines=@($panel.lines)
                if($null -eq $panel.lines -or $lines.Count -lt 1 -or $lines.Count -gt 6){throw 'Bullets require one to six lines'}
                foreach($line in $lines){if([string]::IsNullOrWhiteSpace([string]$line)){throw 'Blank bullet text is not observed evidence'}}
                $slotH=$ch/$lines.Count
                if($slotH -lt 22){throw 'PANEL_NEEDS_SPLIT: not enough room for readable bullet text'}
                for($i=0;$i -lt $lines.Count;$i++){
                    Add-PLSpec ($panelId+'-item-'+($i+1)) 'body' $panelId 'text' $cx ($cy+$i*$slotH) $cw ($slotH-4) ([string]$lines[$i]) 14 '' $ink
                }
            }
            'flow' {
                $steps=@($panel.steps)
                if($steps.Count -lt 2 -or $steps.Count -gt 4){throw 'Flow requires two to four supported steps'}
                $gap=14.0;$slotH=($ch-($steps.Count-1)*$gap)/$steps.Count
                if($slotH -lt 36){throw 'PANEL_NEEDS_SPLIT: flow steps need at least 36 points'}
                for($i=0;$i -lt $steps.Count;$i++){
                    $sid=$panelId+'-step-'+($i+1);$sy=$cy+$i*($slotH+$gap)
                    Add-PLSpec $sid 'card' $panelId 'rect' $cx $sy $cw $slotH '' 14 $light $ink $false $border
                    Add-PLSpec ($sid+'-text') 'body' $sid 'text' ($cx+8) ($sy+6) ($cw-16) ($slotH-12) ([string]$steps[$i]) 14 '' $ink $true
                    if($i -lt $steps.Count-1){Add-PLSpec ($sid+'-arrow') 'connector' $panelId 'line' ($cx+$cw/2) ($sy+$slotH+2) 0 ($gap-4) '' 14 '' $ink $false $accent}
                }
            }
            'timeline' {
                $steps=@($panel.steps)
                if($steps.Count -lt 2 -or $steps.Count -gt 4){throw 'Timeline requires two to four supplied labels'}
                if($cw -lt 300 -or $ch -lt 90){throw 'PANEL_NEEDS_SPLIT: timeline needs a wide panel'}
                $nodeW=$cw/$steps.Count;$axisY=$cy+22
                Add-PLSpec ($panelId+'-axis') 'connector' $panelId 'line' ($cx+$nodeW/2) $axisY ($cw-$nodeW) 0 '' 14 '' $ink $false $navy
                for($i=0;$i -lt $steps.Count;$i++){
                    $center=$cx+$nodeW*($i+0.5)
                    Add-PLSpec ($panelId+'-node-'+$i) 'decoration' $panelId 'rect' ($center-5) ($axisY-5) 10 10 '' 14 $accent
                    Add-PLSpec ($panelId+'-time-'+$i) 'body' $panelId 'text' ($cx+$nodeW*$i+4) ($axisY+18) ($nodeW-8) ($ch-44) ([string]$steps[$i]) 14 '' $ink $true
                }
            }
            'table' {
                $headers=@($panel.table.headers);$rows=@($panel.table.rows)
                if($null -eq $panel.table.headers -or $null -eq $panel.table.rows -or $headers.Count -lt 1 -or $headers.Count -gt 4 -or $rows.Count -lt 1 -or $rows.Count -gt 5){throw 'Unsupported table dimensions'}
                $rowH=$ch/($rows.Count+1);$colW=$cw/$headers.Count
                if($rowH -lt 25 -or $colW -lt 75){throw 'PANEL_NEEDS_SPLIT: table is too dense'}
                for($r=0;$r -le $rows.Count;$r++){
                    $values=if($r -eq 0){$headers}else{@($rows[$r-1])}
                    if(@($values).Count -ne $headers.Count){throw 'Table row column count does not match headers'}
                    for($c=0;$c -lt $headers.Count;$c++){
                        $cell=$panelId+'-cell-'+$r+'-'+$c;$fill=if($r -eq 0){$light}elseif($r%2 -eq 0){'#F9FBFE'}else{'#FFFFFF'}
                        Add-PLSpec $cell 'cell' $panelId 'rect' ($cx+$c*$colW) ($cy+$r*$rowH) $colW $rowH '' 14 $fill $ink $false $border
                        Add-PLSpec ($cell+'-text') 'table_text' $cell 'text' ($cx+$c*$colW+5) ($cy+$r*$rowH+4) ($colW-10) ($rowH-8) ([string]$values[$c]) 14 '' $ink ($r -eq 0)
                    }
                }
            }
            'metrics' {
                $metrics=@($panel.metrics)
                if($null -eq $panel.metrics -or $metrics.Count -lt 1 -or $metrics.Count -gt 3){throw 'Metrics require one to three supplied values'}
                $metricW=$cw/$metrics.Count
                if($metricW -lt 100 -or $ch -lt 86){throw 'PANEL_NEEDS_SPLIT: metric cards need more room'}
                for($i=0;$i -lt $metrics.Count;$i++){
                    $mx=$cx+$i*$metricW;$m=$metrics[$i];$valueFont=if($metricW -lt 180){20}else{26}
                    if([string]::IsNullOrWhiteSpace([string]$m.label) -or [string]::IsNullOrWhiteSpace([string]$m.value_text)){throw 'A metric requires a supplied label and value; missing is not zero'}
                    # Two predeclared components, selected by available fixed panel height.
                    $labelH=42;$valueOffset=45;$valueH=40;$detailOffset=89
                    if($ch -lt 116){$labelH=24;$valueOffset=27;$valueH=36;$detailOffset=67}
                    Add-PLSpec ($panelId+'-metric-label-'+$i) 'body' $panelId 'text' ($mx+4) $cy ($metricW-8) $labelH ([string]$m.label) 14 '' $ink $true
                    Add-PLSpec ($panelId+'-metric-value-'+$i) 'metric' $panelId 'text' ($mx+2) ($cy+$valueOffset) ($metricW-4) $valueH ([string]$m.value_text) $valueFont '' $accent $true
                    if($m.detail){Add-PLSpec ($panelId+'-metric-detail-'+$i) 'detail' $panelId 'text' ($mx+4) ($cy+$detailOffset) ($metricW-8) ($ch-$detailOffset) ([string]$m.detail) 12 '' '#52647C'}
                }
            }
            'bars' {
                $bars=@($panel.bars)
                if($null -eq $panel.bars -or $bars.Count -lt 1 -or $bars.Count -gt 4){throw 'Bars require one to four supplied measures'}
                $barH=$ch/$bars.Count
                if($barH -lt 44){throw 'PANEL_NEEDS_SPLIT: bars need more vertical room'}
                for($i=0;$i -lt $bars.Count;$i++){
                    $b=$bars[$i]
                    if($null -eq $b.ratio -or [string]::IsNullOrWhiteSpace([string]$b.label) -or [string]::IsNullOrWhiteSpace([string]$b.value_text)){throw 'A bar requires supplied ratio, label and value; missing is not zero'}
                    $ratio=[double]$b.ratio
                    if($ratio -lt 0 -or $ratio -gt 1 -or [double]::IsNaN($ratio)){throw 'Bar ratio must be a supplied value from zero to one'}
                    $by=$cy+$i*$barH
                    Add-PLSpec ($panelId+'-barlabel-'+$i) 'body' $panelId 'text' $cx $by $cw 22 (([string]$b.label)+'  '+([string]$b.value_text)) 14 '' $ink
                    Add-PLSpec ($panelId+'-barbg-'+$i) 'decoration' $panelId 'rect' $cx ($by+28) $cw 10 '' 14 '#E7ECF3'
                    if($ratio -gt 0){Add-PLSpec ($panelId+'-barvalue-'+$i) 'decoration' $panelId 'rect' $cx ($by+28) ($cw*$ratio) 10 '' 14 $accent}
                }
            }
            'asset' {
                $asset=$panel.asset
                if($null -eq $asset -or [string]::IsNullOrWhiteSpace([string]$asset.document_name) -or [string]::IsNullOrWhiteSpace([string]$asset.shape_name) -or [string]::IsNullOrWhiteSpace([string]$asset.description) -or $null -eq $asset.slide_index -or $asset.reference_kind -notin @('picture','diagram')){throw 'ASSET_REFERENCE_REQUIRED: supply an existing same-document object and its description'}
                if($cw -lt 100 -or $ch -lt 100){throw 'PANEL_NEEDS_SPLIT: media frame and description need more room'}
                $frameId=$panelId+'-asset-frame'
                Add-PLSpec $frameId 'asset_frame' $panelId 'rect' $cx $cy $cw ($ch-48) '' 14 $light $ink $false $border
                Add-PLSpec ($panelId+'-asset') 'evidence_asset' $frameId 'asset' $cx $cy $cw ($ch-48)
                $shapes[$shapes.Count-1] | Add-Member -NotePropertyName asset -NotePropertyValue $asset
                Add-PLSpec ($panelId+'-asset-description') 'detail' $panelId 'text' $cx ($cy+$ch-40) $cw 40 ([string]$asset.description) 12 '' '#52647C'
            }
            default {throw ('Unsupported panel kind: '+$kind)}
        }
    }
    # Geometry is deterministic; caller must still inspect COM text bounds after rendering.
    foreach($s in $shapes){
        if($s.x -lt -0.001 -or $s.y -lt -0.001 -or $s.x+$s.w -gt 960.001 -or $s.y+$s.h -gt 540.001 -or $s.w -lt 0 -or $s.h -lt 0){throw ('Layout outside canvas: '+$s.id)}
    }
    $leafText=@($shapes | Where-Object {$_.kind -eq 'text'})
    for($i=0;$i -lt $leafText.Count;$i++){
        for($j=$i+1;$j -lt $leafText.Count;$j++){
            $a=$leafText[$i];$b=$leafText[$j]
            $overlapW=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x)
            $overlapH=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
            if($overlapW -gt 0.75 -and $overlapH -gt 0.75){throw ('LEAF_TEXT_OVERLAP: '+$a.id+' / '+$b.id)}
        }
    }
    return $shapes.ToArray()
}
