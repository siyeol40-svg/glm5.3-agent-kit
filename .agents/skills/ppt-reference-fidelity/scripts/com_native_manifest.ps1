<# DRM profile: read permitted PowerPoint objects only. No package extraction,
image/PDF export, document hashing, save, screenshot capture, or DRM removal.
Run in the authorized interactive Windows user's session under approved policy.
#>
param(
    [Parameter(Mandatory=$true)][string]$Pptx,
    [Parameter(Mandatory=$true)][string]$Output,
    [switch]$UseOpenPresentation
)
$ErrorActionPreference='Stop'
$app=$null;$deck=$null;$ownsApp=$false;$ownsDeck=$false
$unknown=New-Object 'System.Collections.Generic.List[string]'
$report=[ordered]@{schema='kit.com-manifest.v1';status='FAIL';identity=$null;slides=@();
    slide_size=$null;unreadable_properties=@();errors=@();
    scope='Slide-local objects/groups and readable COM properties; no package/media byte validation'}
function Get-NativeValue([scriptblock]$Reader,[string]$Label) {
    try { return (& $Reader) } catch { $unknown.Add($Label);return $null }
}
try {
    if ($env:OS -ne 'Windows_NT') { throw 'Interactive Windows PowerPoint is required' }
    $inputPath=(Resolve-Path -LiteralPath $Pptx).Path
    if (Test-Path -LiteralPath $Output) { throw 'Use a new output JSON path' }
    $outputPath=[IO.Path]::GetFullPath($Output)
    if ($outputPath -eq $inputPath) { throw 'Output must not be the presentation' }
    if ($UseOpenPresentation) {
        # Available in Windows PowerShell/.NET Framework. Failure is not bypassed.
        $app=[Runtime.InteropServices.Marshal]::GetActiveObject('PowerPoint.Application')
        foreach ($presentation in $app.Presentations) {
            if ([string]$presentation.FullName -eq $inputPath) { $deck=$presentation;break }
        }
        if ($null -eq $deck) { throw 'Requested presentation is not open in the authorized PowerPoint instance' }
    } else {
        $app=New-Object -ComObject PowerPoint.Application;$ownsApp=$true
        $deck=$app.Presentations.Open($inputPath,-1,0,-1);$ownsDeck=$true
    }
    if ([int]$deck.Saved -ne -1) { throw 'Unsaved presentation cannot be bound to a saved-file revision; do not auto-save the original' }
    $file=Get-Item -LiteralPath $inputPath
    $report.identity=[ordered]@{path=$inputPath;size_bytes=[long]$file.Length;mtime_ticks_utc=[long]$file.LastWriteTimeUtc.Ticks}
    $report.slide_size=@([double]$deck.PageSetup.SlideWidth,[double]$deck.PageSetup.SlideHeight)
    for ($i=1;$i -le $deck.Slides.Count;$i++) {
        $slide=$deck.Slides.Item($i)
        $items=New-Object 'System.Collections.Generic.List[object]'
        function Visit-NativeShape($shape,[string]$prefix) {
            $key=$prefix+'shape-'+[string]$shape.Id
            $label='slide-'+$i+'/'+$key
            $entry=[ordered]@{key=$key;type=[int]$shape.Type;name=[string]$shape.Name;
                parent=$prefix.TrimEnd('/');z_order=[int]$shape.ZOrderPosition;
                geometry=@([double]$shape.Left,[double]$shape.Top,[double]$shape.Width,[double]$shape.Height,[double]$shape.Rotation);
                text='';font_runs=@();
                fill=(Get-NativeValue { @([int]$shape.Fill.Type,[int]$shape.Fill.Visible,[int]$shape.Fill.ForeColor.RGB,[double]$shape.Fill.Transparency) } ($label+'/fill'));
                line=(Get-NativeValue { @([int]$shape.Line.Visible,[int]$shape.Line.ForeColor.RGB,[double]$shape.Line.Weight,[double]$shape.Line.Transparency) } ($label+'/line'));
                shadow=(Get-NativeValue { @([int]$shape.Shadow.Visible,[int]$shape.Shadow.Type,[double]$shape.Shadow.Blur,[double]$shape.Shadow.OffsetX,[double]$shape.Shadow.OffsetY,[double]$shape.Shadow.Transparency) } ($label+'/shadow'));
                picture_crop=$null;text_frame=$null;text_bounds=$null}
            if ([int]$shape.Type -in @(11,13,28,29)) {
                $entry.picture_crop=Get-NativeValue { @([double]$shape.PictureFormat.CropLeft,[double]$shape.PictureFormat.CropTop,[double]$shape.PictureFormat.CropRight,[double]$shape.PictureFormat.CropBottom) } ($label+'/picture_crop')
            }
            if ([int]$shape.HasTextFrame -eq -1 -and [int]$shape.TextFrame2.HasText -eq -1) {
                $tf=$shape.TextFrame2;$tr=$tf.TextRange;$entry.text=[string]$tr.Text
                $entry.text_frame=Get-NativeValue { @([double]$tf.MarginLeft,[double]$tf.MarginTop,[double]$tf.MarginRight,[double]$tf.MarginBottom,[int]$tf.AutoSize,[int]$tf.VerticalAnchor,[int]$tf.WordWrap,[int]$tf.Orientation) } ($label+'/text_frame')
                $entry.text_bounds=Get-NativeValue { @([double]$tr.BoundLeft,[double]$tr.BoundTop,[double]$tr.BoundWidth,[double]$tr.BoundHeight) } ($label+'/text_bounds')
                $runs=New-Object 'System.Collections.Generic.List[object]'
                for ($k=1;$k -le $tr.Runs().Count;$k++) {
                    $run=$tr.Runs($k,1)
                    $runs.Add([ordered]@{text=[string]$run.Text;font=(Get-NativeValue { @([string]$run.Font.Name,[double]$run.Font.Size,[int]$run.Font.Bold,[int]$run.Font.Italic,[int]$run.Font.Fill.ForeColor.RGB) } ($label+'/run-'+$k))})
                }
                $entry.font_runs=@($runs.ToArray())
            }
            if ([int]$shape.HasTable -eq -1) { $unknown.Add($label+'/native-table-cell-content') }
            if ([int]$shape.HasChart -eq -1) { $unknown.Add($label+'/native-chart-data') }
            $items.Add($entry)
            if ([int]$shape.Type -eq 6) {
                for ($n=1;$n -le $shape.GroupItems.Count;$n++) { Visit-NativeShape $shape.GroupItems.Item($n) ($key+'/') }
            }
        }
        for ($j=1;$j -le $slide.Shapes.Count;$j++) { Visit-NativeShape $slide.Shapes.Item($j) '' }
        $report.slides+=@{slide=$i;shapes=@($items.ToArray())}
    }
    $report.unreadable_properties=@($unknown.ToArray())
    $report.status='PASS'
} catch {
    $report.errors+=@($_.Exception.Message);$report.status='FAIL'
} finally {
    # Never close the user's already-open presentation or quit their application.
    if ($ownsDeck -and $null -ne $deck) { try {$deck.Close()} catch {} }
    if ($ownsApp -and $null -ne $app) { try {$app.Quit()} catch {} }
}
# Local evidence output must itself be permitted by the company's policy.
$parent=Split-Path -Parent ([IO.Path]::GetFullPath($Output))
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
if (-not (Test-Path -LiteralPath $Output)) {
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($Output),($report | ConvertTo-Json -Depth 30),(New-Object Text.UTF8Encoding($false)))
}
if ($report.status -ne 'PASS') { exit 1 }
exit 0
