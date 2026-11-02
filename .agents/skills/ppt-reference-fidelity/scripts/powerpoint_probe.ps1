<# Run under the interactive Windows user's approved policy. Never changes input PPTX.
Without -Pptx, only tests desktop PowerPoint COM startup; no inspection PASS is claimed.
Native measurements are intentionally limited to unrotated, ungrouped text frames.
#>
param(
    [string]$Pptx,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [int]$Width=1600,
    [int]$Height=900
)
$ErrorActionPreference='Stop'
$report=[ordered]@{schema='kit.powerpoint-snapshot.v1';status='FAIL';artifact_sha256=$null;
    renderer=$null;environment=$null;text_shapes=@();slides=@();errors=@()}
$app=$null;$deck=$null;$fontCollection=$null
try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows desktop PowerPoint is required' }
    if ($Width -lt 100 -or $Height -lt 100 -or $Width -gt 7680 -or $Height -gt 4320) { throw 'Invalid export dimensions' }
    $out=[IO.Path]::GetFullPath($OutputDir)
    if (Test-Path -LiteralPath $out) {
        if (@(Get-ChildItem -LiteralPath $out -Force).Count -gt 0) { throw 'Use a new empty output directory' }
    } else { New-Item -ItemType Directory -Path $out -Force | Out-Null }
    Add-Type -AssemblyName System.Drawing
    $fontCollection=New-Object System.Drawing.Text.InstalledFontCollection
    $fonts=@($fontCollection.Families | ForEach-Object {$_.Name} | Sort-Object -Unique)
    $fontBytes=[Text.Encoding]::UTF8.GetBytes(($fonts -join "`n"))
    $hasher=[Security.Cryptography.SHA256]::Create()
    $fontHash=([BitConverter]::ToString($hasher.ComputeHash($fontBytes))).Replace('-','').ToLowerInvariant()
    $hasher.Dispose()
    $app=New-Object -ComObject PowerPoint.Application
    $report.renderer='Microsoft.PowerPoint '+[string]$app.Version
    $report.environment=[ordered]@{os=[Environment]::OSVersion.VersionString;fonts_sha256=$fontHash;
        export_width=$Width;export_height=$Height;office_build=[string]$app.Build}
    if (-not $Pptx) {
        $report.schema='kit.powerpoint-capability.v1'
        $report.status='AVAILABLE'
    } else {
        $inputPath=(Resolve-Path -LiteralPath $Pptx).Path
        $report.artifact_sha256=(Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        # ReadOnly=true, Untitled=false, WithWindow=false. Desktop user session required.
        $deck=$app.Presentations.Open($inputPath,-1,0,0)
        $items=New-Object 'System.Collections.Generic.List[object]'
        function Visit-Shape($shape,[string]$prefix,[int]$slideIndex,[int]$depth) {
            $key=$prefix+'shape-'+[string]$shape.Id
            if ([int]$shape.Type -eq 6) {
                for ($j=1;$j -le $shape.GroupItems.Count;$j++) {
                    Visit-Shape $shape.GroupItems.Item($j) ($key+'/') $slideIndex ($depth+1)
                }
                return
            }
            if ([int]$shape.HasTable -eq -1) {
                $items.Add([ordered]@{slide=$slideIndex;key=$key;supported=$false;reason='Table cells require a dedicated layout checker'})
                return
            }
            if ([int]$shape.HasTextFrame -ne -1 -or [int]$shape.TextFrame2.HasText -ne -1) { return }
            $frame=$shape.TextFrame2;$tr=$frame.TextRange
            $reason=''
            if ($depth -gt 0) { $reason='Grouped text transforms require target-environment qualification' }
            if ([Math]::Abs([double]$shape.Rotation) -gt 0.01) { $reason='Rotated text requires dedicated geometry checking' }
            if ([int]$frame.Orientation -ne 1) { $reason='Non-horizontal text is unsupported' }
            $declaredFonts=New-Object 'System.Collections.Generic.List[string]'
            for ($k=1;$k -le $tr.Runs().Count;$k++) {
                $name=[string]$tr.Runs($k,1).Font.Name
                if (-not $declaredFonts.Contains($name)) { $declaredFonts.Add($name) }
            }
            $fontOK=$declaredFonts.Count -gt 0
            foreach ($name in $declaredFonts) {
                if (-not $name -or $name.StartsWith('+') -or $fonts -notcontains $name) { $fontOK=$false }
            }
            $items.Add([ordered]@{slide=$slideIndex;key=$key;text=[string]$tr.Text;supported=($reason -eq '');reason=$reason;
                inner_box=@(([double]$shape.Left+[double]$frame.MarginLeft),([double]$shape.Top+[double]$frame.MarginTop),
                    ([double]$shape.Width-[double]$frame.MarginLeft-[double]$frame.MarginRight),
                    ([double]$shape.Height-[double]$frame.MarginTop-[double]$frame.MarginBottom));
                text_bounds=@([double]$tr.BoundLeft,[double]$tr.BoundTop,[double]$tr.BoundWidth,[double]$tr.BoundHeight);
                auto_size=[int]$frame.AutoSize;declared_fonts=@($declaredFonts.ToArray());font_available=$fontOK})
        }
        for ($i=1;$i -le $deck.Slides.Count;$i++) {
            $slide=$deck.Slides.Item($i)
            for ($j=1;$j -le $slide.Shapes.Count;$j++) { Visit-Shape $slide.Shapes.Item($j) '' $i 0 }
            $image=Join-Path $out ('slide-'+$i+'.png')
            $slide.Export($image,'PNG',$Width,$Height)
            $report.slides+=@{slide=$i;image=$image;image_sha256=(Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash.ToLowerInvariant()}
        }
        $report.text_shapes=@($items.ToArray())
        $report.status='PASS'
    }
} catch {
    $report.errors+=@($_.Exception.Message)
    $report.status='FAIL'
} finally {
    if ($null -ne $deck) { try {$deck.Close()} catch {} }
    if ($null -ne $app) { try {$app.Quit()} catch {} }
    if ($null -ne $fontCollection) { $fontCollection.Dispose() }
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
    $json=$report | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($OutputDir)) 'snapshot.json'),$json,(New-Object Text.UTF8Encoding($false)))
}
if ($report.status -eq 'FAIL') { exit 1 }
exit 0
