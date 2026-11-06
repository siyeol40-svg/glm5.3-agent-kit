# Bounded stdout-only reading from an already-open, explicitly selected presentation.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TargetName,
    [int]$SlideIndex=0,
    [int]$ShapeId=0,
    [ValidateSet('index','content')][string]$Mode='index',
    [ValidateRange(0,1000000)][int]$Offset=0,
    [ValidateRange(1,25)][int]$Limit=10,
    [ValidateRange(256,20000)][int]$MaxChars=6000
)
$ErrorActionPreference='Stop'
$nodeCap=200

function Get-RSNumber($Value) {
    if($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))){return $null}
    try {$number=[double]$Value;if([double]::IsNaN($number) -or [double]::IsInfinity($number)){return $null};return $number} catch {return $null}
}

function Get-RSValue($Object,[string]$Property) {
    if($null -eq $Object){return $null}
    try {return ,($Object.$Property)} catch {return $null}
}

function Get-RSPreview([string]$Text,[int]$Length=80) {
    if($null -eq $Text){return $null}
    return $Text.Substring(0,[math]::Min($Length,$Text.Length))
}

function Get-RSNodes($Collection,[int]$ParentId=0,[int]$Depth=0,[int]$Maximum=200) {
    $entries=New-Object 'Collections.Generic.List[object]'
    $scan=@{partial=$false;reason=$null}
    function Walk-RSCollection($Objects,[int]$Parent,[int]$Level) {
        $count=Get-RSNumber (Get-RSValue $Objects 'Count')
        if($null -eq $count){$scan.partial=$true;$scan.reason='collection_count_unavailable';return}
        if($Level -gt 16){$scan.partial=$true;$scan.reason='group_depth_cap';return}
        for($i=1;$i -le [int]$count;$i++){
            if($entries.Count -ge $Maximum){$scan.partial=$true;$scan.reason='node_cap';return}
            try {$shape=$Objects.Item([int]$i)} catch {$scan.partial=$true;$scan.reason='object_unavailable';continue}
            $id=Get-RSNumber (Get-RSValue $shape 'Id')
            $type=Get-RSNumber (Get-RSValue $shape 'Type')
            $entries.Add([pscustomobject]@{shape=$shape;id=$id;type=$type;parent_id=$Parent;depth=$Level})
            if($null -eq $id -or $null -eq $type){$scan.partial=$true;$scan.reason='identity_unavailable'}
            if($type -eq 6){
                try {$children=$shape.GroupItems;Walk-RSCollection $children ([int]$id) ($Level+1)} catch {$scan.partial=$true;$scan.reason='group_unavailable'}
            }
        }
    }
    Walk-RSCollection $Collection $ParentId $Depth
    return [pscustomobject]@{entries=$entries.ToArray();partial=[bool]$scan.partial;reason=$scan.reason;node_cap=$Maximum}
}

function Get-RSNodeIndex($Entry,[bool]$Preview=$true) {
    $shape=$Entry.shape;$unavailable=New-Object 'Collections.Generic.List[string]'
    $position=[ordered]@{}
    foreach($pair in @(@('left','Left'),@('top','Top'),@('width','Width'),@('height','Height'),@('rotation','Rotation'))){
        $value=Get-RSNumber (Get-RSValue $shape $pair[1]);$position[$pair[0]]=$value
        if($null -eq $value){$unavailable.Add($pair[0])}
    }
    $children=if($null -eq $Entry.type){$null}else{0}
    if($Entry.type -eq 6){$children=Get-RSNumber (Get-RSValue (Get-RSValue $shape 'GroupItems') 'Count')}
    if($null -eq $children){$unavailable.Add('children_count')}
    $role=$null
    try {$role=[string]$shape.Tags.Item('PW_ROLE');if(-not $role){$role=[string]$shape.Tags.Item('qa_role')}} catch {$unavailable.Add('role')}
    $previewText=$null;$textLength=$null
    $hasText=Get-RSNumber (Get-RSValue $shape 'HasTextFrame')
    $hasTable=Get-RSNumber (Get-RSValue $shape 'HasTable')
    if($null -eq $hasText){$unavailable.Add('has_text_frame')}
    if($null -eq $hasTable){$unavailable.Add('has_native_table')}
    if($Preview -and $hasText -eq -1){
        try {
            $range=$shape.TextFrame.TextRange;$textLength=Get-RSNumber $range.Length
            if($null -eq $textLength){$unavailable.Add('text_length')}
            elseif($textLength -eq 0){$previewText=''}
            else {$previewValue=$range.Characters([int]1,[int]([math]::Min(80,$textLength))).Text;if($null -eq $previewValue){throw 'preview unavailable'};$previewText=[string]$previewValue}
        } catch {$unavailable.Add('text_preview')}
    }
    $transformed=$Entry.depth -gt 0 -or $null -eq $position.rotation -or [math]::Abs([double]$position.rotation) -gt 0.01
    return [pscustomobject][ordered]@{
        shape_id=$Entry.id;name=(Get-RSValue $shape 'Name');type=$Entry.type;role=$role
        parent_shape_id=$(if($Entry.parent_id){$Entry.parent_id}else{$null});depth=$Entry.depth
        position=$position;geometry_interpretation=$(if($transformed){'raw_COM_group_or_rotation_transform_unresolved'}else{'raw_COM_values_not_pixel_measurements'})
        ancestor_group_present=($Entry.depth -gt 0);children_count=$children
        has_text_frame=$hasText;has_native_table=$hasTable;text_preview=$previewText;text_length=$textLength
        preview_limit=80;preview_truncated=$(if($null -eq $textLength){$null}else{$textLength -gt 80});unavailable=$unavailable.ToArray()
    }
}

function Get-RSNodeContent($Entry,[int]$CellOffset=0) {
    $index=Get-RSNodeIndex $Entry $false
    $shape=$Entry.shape;$partial=$false;$content=[ordered]@{}
    if($index.has_text_frame -eq -1){
        try {
            $range=$shape.TextFrame.TextRange;$length=Get-RSNumber $range.Length
            if($null -eq $length){throw 'text length unavailable'}
            if($length -gt $MaxChars-256){$content.text=[ordered]@{status='needs_split';length=$length;hint='Select a smaller text object or request a larger bounded MaxChars'};$partial=$true}
            else {$rawText=$range.Text;if($null -eq $rawText){throw 'text unavailable'};$content.text=[ordered]@{status='read';raw=[string]$rawText;length=$length}}
        } catch {$content.text=[ordered]@{status='unavailable';length=$null};$partial=$true}
    }
    if($index.has_native_table -eq -1){
        try {
            $table=$shape.Table;$rows=Get-RSNumber $table.Rows.Count;$columns=Get-RSNumber $table.Columns.Count
            if($null -eq $rows -or $null -eq $columns -or $rows -lt 1 -or $columns -lt 1){throw 'table dimensions unavailable'}
            $cellCount=[long]$rows*[long]$columns;$cells=New-Object 'Collections.Generic.List[object]'
            $end=[math]::Min($cellCount,[long]$CellOffset+$Limit)
            for($cell=$CellOffset;$cell -lt $end;$cell++){
                $row=[int]([math]::Floor($cell/$columns)+1);$column=[int]($cell%$columns+1)
                try {
                    $range=$table.Cell($row,$column).Shape.TextFrame.TextRange;$length=Get-RSNumber $range.Length
                    if($null -eq $length){throw 'cell text length unavailable'}
                    if($length -gt $MaxChars-256){$cells.Add([pscustomobject]@{row=$row;column=$column;status='needs_split';length=$length});$partial=$true}
                    else {$rawText=$range.Text;if($null -eq $rawText){throw 'cell text unavailable'};$cells.Add([pscustomobject]@{row=$row;column=$column;status='read';raw=[string]$rawText;length=$length})}
                } catch {$cells.Add([pscustomobject]@{row=$row;column=$column;status='unavailable'});$partial=$true}
            }
            $next=if($end -lt $cellCount){[long]$end}else{$null}
            if($null -ne $next){$partial=$true}
            $content.table=[ordered]@{rows=[int]$rows;columns=[int]$columns;cell_count=$cellCount;cell_offset=$CellOffset;next_cell_offset=$next;cells=$cells.ToArray()}
        } catch {$content.table=[ordered]@{status='unavailable'};$partial=$true}
    }
    # Read object metadata only: never ChartData, OLE contents, image pixels or a file path.
    $content.title=Get-RSValue $shape 'Title';$content.alternative_text=Get-RSValue $shape 'AlternativeText'
    $content.media_interpretation=if($Entry.type -in @(3,7,10,11,13,24)){'unsupported_meaning_metadata_only'}elseif($Entry.type -eq 6){'group_children_separately_read_no_visual_judgment'}else{'text_and_object_metadata_only'}
    $index|Add-Member -NotePropertyName content -NotePropertyValue $content
    $index|Add-Member -NotePropertyName content_partial -NotePropertyValue $partial
    return $index
}

function ConvertTo-RSBoundedJson($Envelope,[object[]]$IndexItems=@()) {
    $json=$Envelope|ConvertTo-Json -Depth 16 -Compress
    if($json.Length -le $MaxChars){return $json}
    $short=New-Object 'Collections.Generic.List[object]'
    foreach($item in @($IndexItems | Select-Object -First 10)){
        $short.Add([pscustomobject]@{shape_id=$item.shape_id;name=(Get-RSPreview ([string]$item.name));type=$item.type;parent_shape_id=$item.parent_shape_id;children_count=$item.children_count})
    }
    $fallback=[ordered]@{status='needs_split';reason='max_chars';partial=$true;read_all_material=$false;requested_offset=$Offset;requested_limit=$Limit;hint='Reduce Limit or select a ShapeId; no raw content was silently trimmed';index=$short.ToArray()}
    $json=$fallback|ConvertTo-Json -Depth 8 -Compress
    while($json.Length -gt $MaxChars -and $short.Count -gt 0){$short.RemoveAt($short.Count-1);$fallback.index=$short.ToArray();$json=$fallback|ConvertTo-Json -Depth 8 -Compress}
    if($json.Length -gt $MaxChars){return '{"status":"needs_split","reason":"max_chars","partial":true}'}
    return $json
}

try {
    if($PSBoundParameters.ContainsKey('SlideIndex') -and $SlideIndex -lt 1){throw 'SlideIndex must be a positive existing slide position'}
    if($PSBoundParameters.ContainsKey('ShapeId') -and $ShapeId -lt 1){throw 'ShapeId must be a positive COM shape ID'}
    . (Join-Path $PSScriptRoot 'Proposal.Com.ps1')
    $presentation=Get-ProposalPowerPoint $TargetName
    $slideCount=[int](ConvertTo-ProposalFiniteNumber $presentation.Slides.Count 'Slides.Count')
    $envelope=[ordered]@{status='read';target_name=[string]$presentation.Name;mode=$Mode;offset=$Offset;limit=$Limit;partial=$false;read_all_material=$false;facts_verified=$false;untrusted_source_text=$true;null_semantics='unavailable_or_not_observed_not_zero_or_absence';visual_qa='not_performed_policy';items=@();next_offset=$null}
    if($SlideIndex -eq 0){
        $items=New-Object 'Collections.Generic.List[object]'
        $end=[math]::Min($slideCount,$Offset+$Limit)
        for($i=$Offset;$i -lt $end;$i++){
            $slide=$presentation.Slides.Item([int]($i+1))
            $items.Add([pscustomobject]@{slide_index=($i+1);slide_id=(Get-RSNumber (Get-RSValue $slide 'SlideID'));name=[string](Get-RSValue $slide 'Name');shape_count=(Get-RSNumber (Get-RSValue $slide.Shapes 'Count'))})
        }
        $envelope.mode='slide_index';$envelope.items=$items.ToArray();$envelope.total_slides=$slideCount
        if($end -lt $slideCount){$envelope.next_offset=$end;$envelope.partial=$true}
        if($Mode -eq 'content' -or $ShapeId){$envelope.status='needs_selection';$envelope.hint='ShapeId is slide-scoped; choose SlideIndex and ShapeId before requesting raw content'}
        Write-Output (ConvertTo-RSBoundedJson $envelope)
        exit 0
    }
    if($SlideIndex -gt $slideCount){throw 'Requested slide is not open in the selected presentation'}
    $slide=$presentation.Slides.Item([int]$SlideIndex)
    $scan=Get-RSNodes $slide.Shapes
    $entries=@($scan.entries);$selected=$null
    if($ShapeId){
        $found=@($entries | Where-Object {$null -ne $_.id -and $_.id -eq $ShapeId})
        if($found.Count -gt 1){throw 'ShapeId is ambiguous within the selected slide'}
        if($found.Count -eq 0){
            $envelope.status=if($scan.partial){'needs_split'}else{'not_found'};$envelope.partial=[bool]$scan.partial;$envelope.reason=if($scan.partial){$scan.reason}else{'shape_id_not_found'}
            $envelope.slide_index=$SlideIndex;$envelope.items=@();Write-Output (ConvertTo-RSBoundedJson $envelope);exit 0
        }
        $selected=$found[0]
        if($selected.type -eq 6){
            $groupScan=Get-RSNodes $selected.shape.GroupItems ([int]$selected.id) ($selected.depth+1) ($nodeCap-1)
            $entries=@($selected)+@($groupScan.entries)
            if($groupScan.partial){$scan.partial=$true;$scan.reason=$groupScan.reason}
        } else {$entries=@($selected)}
    }
    $items=New-Object 'Collections.Generic.List[object]'
    $tableSelection=$Mode -eq 'content' -and $null -ne $selected -and (Get-RSNumber (Get-RSValue $selected.shape 'HasTable')) -eq -1
    if($tableSelection){
        $item=Get-RSNodeContent $selected $Offset;$items.Add($item)
        $envelope.pagination_unit='table_cells';$envelope.next_offset=$item.content.table.next_cell_offset
        if($item.content_partial){$envelope.partial=$true}
        if(@($item.unavailable).Count){$envelope.partial=$true}
        if(@($item.content.table.cells | Where-Object {$_.status -eq 'needs_split'}).Count){$envelope.status='needs_split';$envelope.hint='A table cell exceeds the bounded content size'}
    } else {
        $end=[math]::Min($entries.Count,$Offset+$Limit)
        for($i=$Offset;$i -lt $end;$i++){
            $item=if($Mode -eq 'content' -and $null -ne $selected){Get-RSNodeContent $entries[$i]}else{Get-RSNodeIndex $entries[$i]}
            $items.Add($item)
            if($item.content_partial){$envelope.partial=$true}
            if(@($item.unavailable).Count){$envelope.partial=$true}
            if($item.content.text.status -eq 'needs_split'){$envelope.status='needs_split';$envelope.hint='Select a smaller ShapeId or increase bounded MaxChars; character slicing is not supported'}
        }
        $envelope.pagination_unit='nodes'
        if($end -lt $entries.Count){$envelope.next_offset=$end;$envelope.partial=$true}
        if($Mode -eq 'content' -and $null -eq $selected){$envelope.status='needs_selection';$envelope.hint='Select a ShapeId from this index before reading raw content'}
    }
    $envelope.slide_index=$SlideIndex;$envelope.items=$items.ToArray();$envelope.observed_node_count=$entries.Count
    $envelope.traversal_complete=-not [bool]$scan.partial;$envelope.node_cap=$nodeCap
    if($scan.partial){
        $envelope.partial=$true;$envelope.traversal_limit_reason=$scan.reason
        if($null -eq $selected -or $selected.type -eq 6){$envelope.status='needs_split';$envelope.hint='Traversal was bounded; select a returned ShapeId to narrow the requested material'}
    }
    Write-Output (ConvertTo-RSBoundedJson $envelope $items.ToArray())
    exit 0
} catch {
    $message=[string]$_.Exception.Message
    $failure=[ordered]@{status='blocked';reason=(Get-RSPreview $message 180);partial=$true;read_all_material=$false;visual_qa='not_performed_policy'}
    Write-Output (ConvertTo-RSBoundedJson $failure)
    exit 1
}
