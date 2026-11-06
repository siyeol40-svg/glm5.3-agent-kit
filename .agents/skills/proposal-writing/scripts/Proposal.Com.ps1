# Existing PowerPoint instance only. No disk PPT read, Open, new application, capture, export or save.
function ConvertTo-ProposalOfficeColor([string]$Hex) {
    if($Hex -notmatch '^#[0-9a-fA-F]{6}$'){throw 'Invalid fixed palette color'}
    return [int]([Convert]::ToInt32($Hex.Substring(1,2),16)+256*[Convert]::ToInt32($Hex.Substring(3,2),16)+65536*[Convert]::ToInt32($Hex.Substring(5,2),16))
}

function ConvertTo-ProposalFiniteNumber($Value,[string]$Name) {
    if($null -eq $Value -or $Value -is [DBNull]){throw ('Required COM value is unavailable: '+$Name)}
    $number=[double]$Value
    if([double]::IsNaN($number) -or [double]::IsInfinity($number)){throw ('Required COM value is not finite: '+$Name)}
    return $number
}

function Get-ProposalStageLayoutRevision($Stage) {
    if([string]$Stage.layout_profile -ceq 'reference-v10-actions'){return 'proposal-reference-r10'}
    if([string]$Stage.layout_profile -ceq 'reference-v9'){return 'proposal-reference-r9'}
    if([string]$Stage.layout_profile -ceq 'reference-v8-actions'){return 'proposal-reference-r8'}
    if([string]$Stage.layout_profile -ceq 'reference-v7'){return 'proposal-reference-r7'}
    if([string]$Stage.layout_profile -ceq 'reference-v6'){return 'proposal-reference-r6'}
    if([string]$Stage.layout_profile -ceq 'reference-v5-problem'){return 'proposal-reference-r5'}
    if([string]$Stage.layout_profile -ceq 'reference-v4'){return 'proposal-reference-r4'}
    if([string]$Stage.layout_profile -ceq 'reference-v3'){return 'proposal-reference-r3'}
    if([string]$Stage.layout_profile -ceq 'reference-v2'){return 'proposal-reference-r2'}
    return 'proposal-layout-r1'
}

function Get-ProposalNativePrimitive($Spec) {
    if([string]$Spec.kind -ceq 'rect'){return 1}
    # Office MsoAutoShapeType: Oval=9, RoundedRectangle=5, RightArrow=33, LeftArrow=34, DownArrow=36.
    # https://learn.microsoft.com/en-us/office/vba/api/office.msoautoshapetype
    if([string]$Spec.kind -cne 'shape'){throw 'Native primitive requires rect or shape kind'}
    switch -CaseSensitive ([string]$Spec.primitive) {
        'ellipse' {return 9}
        'roundrect' {return 5}
        'rightArrow' {return 33}
        'leftArrow' {return 34}
        'downArrow' {return 36}
        default {throw 'Unsupported native shape primitive'}
    }
}

function Get-ProposalTextAlignment($Spec) {
    $value=$Spec.PSObject.Properties['align']
    if($null -eq $value -or $null -eq $value.Value){return 1}
    switch -CaseSensitive ([string]$value.Value) {
        'left' {return 1}
        'center' {return 2}
        'right' {return 3}
        default {throw 'Unsupported text alignment; use left, center or right'}
    }
}

function Get-ProposalLineWidth($Spec) {
    $value=$Spec.PSObject.Properties['line_width']
    if($null -eq $value -or $null -eq $value.Value){if([string]$Spec.kind -eq 'line'){return 1.5};return 0.75}
    $width=ConvertTo-ProposalFiniteNumber $value.Value 'Prepared line width'
    if($width -lt 0.5 -or $width -gt 3){throw 'Prepared line width must be between 0.5 and 3 points'}
    return $width
}

function Get-ProposalCornerRadius($Spec) {
    $value=$Spec.PSObject.Properties['corner_radius']
    if($null -eq $value -or $null -eq $value.Value){return $null}
    if([string]$Spec.kind -cne 'shape' -or [string]$Spec.primitive -cne 'roundrect'){throw 'Corner radius is supported only for the roundrect native primitive'}
    $radius=ConvertTo-ProposalFiniteNumber $value.Value 'Prepared corner radius'
    if($radius -lt 0 -or $radius -gt 0.2){throw 'Prepared corner radius must be between 0 and 0.2'}
    return $radius
}

function Assert-ProposalPreparedNativeShape($Spec,[string]$LayoutRevision) {
    if([string]$Spec.kind -cnotin @('rect','shape','text','line','asset')){throw 'Unsupported shape kind; no mutation is allowed'}
    $revision=$Spec.PSObject.Properties['layout_revision']
    if($null -ne $revision -and [string]$revision.Value -cne $LayoutRevision){throw 'Prepared shape layout revision differs from the stage profile'}
    foreach($coordinate in @('x','y','w','h')){$null=ConvertTo-ProposalFiniteNumber $Spec.$coordinate ('Prepared '+$coordinate)}
    if([double]$Spec.x -lt 0 -or [double]$Spec.y -lt 0 -or [double]$Spec.w -lt 0 -or [double]$Spec.h -lt 0 -or [double]$Spec.x+[double]$Spec.w -gt 960.01 -or [double]$Spec.y+[double]$Spec.h -gt 540.01){throw 'Prepared shape falls outside the supported canvas'}
    $null=Get-ProposalLineWidth $Spec
    $null=Get-ProposalCornerRadius $Spec
    if($Spec.line_color){$null=ConvertTo-ProposalOfficeColor ([string]$Spec.line_color)}
    if([string]$Spec.kind -eq 'text'){
        $size=ConvertTo-ProposalFiniteNumber $Spec.font_size 'Prepared font size'
        $minimum=12.0
        if($LayoutRevision -cin @('proposal-reference-r2','proposal-reference-r3','proposal-reference-r4','proposal-reference-r5','proposal-reference-r6','proposal-reference-r7','proposal-reference-r8','proposal-reference-r9','proposal-reference-r10')){
            $minima=@{title=23.0;section=13.0;metric=20.0;body=11.5;detail=11.0;label=11.5;source=10.0;conclusion=12.0}
            if(-not $minima.ContainsKey([string]$Spec.role)){throw 'Reference text requires an explicitly registered font role'}
            $minimum=$minima[[string]$Spec.role]
        }
        if($size -lt $minimum -or [double]$Spec.w -le 0 -or [double]$Spec.h -le 0){throw 'Invalid prepared text dimensions or role font minimum'}
        $null=Get-ProposalTextAlignment $Spec
        $null=ConvertTo-ProposalOfficeColor ([string]$Spec.color)
    } elseif([string]$Spec.kind -in @('rect','shape')){
        $null=Get-ProposalNativePrimitive $Spec
        if([double]$Spec.w -le 0 -or [double]$Spec.h -le 0){throw 'Native shapes require positive dimensions'}
        if($Spec.fill){$null=ConvertTo-ProposalOfficeColor ([string]$Spec.fill)}
    } elseif([string]$Spec.kind -eq 'line'){
        if(([double]$Spec.w -eq 0 -and [double]$Spec.h -eq 0) -or ([double]$Spec.w -ne 0 -and [double]$Spec.h -ne 0)){throw 'Only positive horizontal or vertical lines are supported'}
        $null=ConvertTo-ProposalOfficeColor ([string]$Spec.line_color)
    }
}

function Get-ProposalSoftWordBreaks($TextRange,[string]$RawText) {
    # Lines and Start are read-only COM metadata. Missing or inconsistent metadata is not a pass.
    $origin=ConvertTo-ProposalFiniteNumber $TextRange.Start 'TextRange.Start'
    $lineCount=ConvertTo-ProposalFiniteNumber ($TextRange.Lines().Count) 'TextRange.Lines.Count'
    if($origin -lt 1 -or $origin -ne [math]::Floor($origin) -or $lineCount -lt 1 -or $lineCount -gt $RawText.Length+1 -or $lineCount -ne [math]::Floor($lineCount)){throw 'Text line positions are unavailable or inconsistent'}
    $breaks=New-Object 'Collections.Generic.List[object]'
    $previous=-1
    for($i=1;$i -le [int]$lineCount;$i++){
        $line=$TextRange.Lines([int]$i,[int]1)
        $start=ConvertTo-ProposalFiniteNumber $line.Start 'Text line Start'
        $offset=$start-$origin
        if($offset -ne [math]::Floor($offset) -or $offset -lt 0 -or $offset -gt $RawText.Length -or $offset -le $previous -or ($i -eq 1 -and $offset -ne 0)){throw 'Text line start does not map to the bound source text'}
        $readLine=$line.Text
        if($null -eq $readLine){throw 'Text line readback is unavailable'}
        $lineText=([string]$readLine).TrimEnd([char[]]@("`r","`n"))
        if($offset+$lineText.Length -gt $RawText.Length -or $RawText.Substring([int]$offset,$lineText.Length) -cne $lineText){throw 'Text line content does not match its source position'}
        if($i -gt 1 -and $offset -gt 0 -and $offset -lt $RawText.Length){
            $before=[string]$RawText[[int]$offset-1];$after=[string]$RawText[[int]$offset]
            if($before -match '^[\p{L}\p{N}]$' -and $after -match '^[\p{L}\p{N}]$'){
                $breaks.Add([pscustomobject]@{line=$i;offset=[int]$offset;before=$before;after=$after;line_text=$lineText})
            }
        }
        $previous=$offset
    }
    return [pscustomobject]@{line_count=[int]$lineCount;breaks=$breaks.ToArray()}
}

function Get-ProposalRegisteredClsid([ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$ProgId) {
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw 'ACTIVE_COM_UNSUPPORTED: read-only class lookup requires Windows'}
    $views=if([Environment]::Is64BitOperatingSystem){@([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)}else{@([Microsoft.Win32.RegistryView]::Registry32)}
    $identities=@{}
    foreach($view in $views){
        $baseKey=$null;$classKey=$null
        try {
            $baseKey=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::ClassesRoot,$view)
            $classKey=$baseKey.OpenSubKey(($ProgId+'\CLSID'),$false)
            if($null -eq $classKey){continue}
            $value=$classKey.GetValue($null,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $identity=[guid]::Empty
            if($null -eq $value -or -not [guid]::TryParse([string]$value,[ref]$identity) -or $identity -eq [guid]::Empty){throw 'Registered CLSID is missing or invalid'}
            $identities[$identity.ToString('D')]=$identity
        } catch {throw ('ACTIVE_COM_UNSUPPORTED: read-only registered class lookup failed; no registration or installation is attempted. '+$_.Exception.Message)}
        finally {if($null -ne $classKey){$classKey.Dispose()};if($null -ne $baseKey){$baseKey.Dispose()}}
    }
    if($identities.Count -eq 0){throw 'ACTIVE_COM_UNAVAILABLE: ProgID is not already registered; no registration or installation is attempted'}
    if($identities.Count -ne 1){throw 'ACTIVE_COM_UNSUPPORTED: registered CLSIDs disagree between registry views; no class is selected'}
    return [guid](@($identities.Values)[0])
}

function Initialize-ProposalActiveComType {
    $existing='ProposalWriting.ActiveCom' -as [type]
    if($null -ne $existing){
        $policy=$existing.GetField('AttachPolicyVersion')
        if($null -eq $policy -or [int]$policy.GetRawConstantValue() -ne 2){throw 'ACTIVE_COM_UNSUPPORTED: an older adapter type is loaded; use a fresh tool process, not a different attachment fallback'}
        return
    }
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw 'ACTIVE_COM_UNSUPPORTED: active-object attachment requires Windows; no replacement connection is attempted'}
    $source=@'
using System;
using System.Runtime.InteropServices;

namespace ProposalWriting
{
    public static class ActiveCom
    {
        public const int AttachPolicyVersion = 2;

        [DllImport("oleaut32.dll", ExactSpelling = true)]
        private static extern int GetActiveObject(
            ref Guid clsid, IntPtr reserved,
            [MarshalAs(UnmanagedType.IUnknown)] out object instance);

        public static object GetByClsid(Guid clsid)
        {
            object instance;
            int result = GetActiveObject(ref clsid, IntPtr.Zero, out instance);
            if (result < 0) Marshal.ThrowExceptionForHR(result);
            if (instance == null) throw new COMException("No active object was returned.");
            return instance;
        }
    }
}
'@
    try {Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop}
    catch {throw ('ACTIVE_COM_UNSUPPORTED: native active-object adapter could not be loaded; no creation fallback is permitted. '+$_.Exception.Message)}
}

function Get-ProposalActiveApplication {
    try {
        $identity=Get-ProposalRegisteredClsid 'PowerPoint.Application'
        Initialize-ProposalActiveComType
        $app=[ProposalWriting.ActiveCom]::GetByClsid($identity)
    } catch {
        if($_.Exception.Message -match '^ACTIVE_COM_(UNSUPPORTED|UNAVAILABLE):'){throw}
        throw ('ACTIVE_COM_UNAVAILABLE: attach to an already-running PowerPoint instance failed; no application was created. '+$_.Exception.Message)
    }
    if($null -eq $app){throw 'No active PowerPoint instance; no application is created'}
    return ,$app
}

function Get-ProposalPowerPoint([string]$TargetName) {
    if([string]::IsNullOrWhiteSpace($TargetName)){throw 'An exact already-open presentation name is required'}
    $app=Get-ProposalActiveApplication
    $found=New-Object 'Collections.Generic.List[object]'
    $requested=$TargetName.Replace('\','/')
    for($i=1;$i -le [int]$app.Presentations.Count;$i++){
        $presentation=$app.Presentations.Item([int]$i)
        $name=[string]$presentation.Name;$full=[string]$presentation.FullName
        if($name -ieq $TargetName -or $full.Replace('\','/') -ieq $requested){$found.Add($presentation)}
    }
    if($found.Count -ne 1){throw ('Expected one exact already-open presentation; found '+$found.Count)}
    return ,($found[0])
}

function Get-ProposalCaptionHash([string]$Text) {
    # A supplied caption/reference-name string hash, never an Office file hash.
    $sha=[Security.Cryptography.SHA256]::Create()
    try {return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant()}
    finally {$sha.Dispose()}
}

function Get-ProposalCropSnapshot($Shape) {
    try {
        $values=@(
            (ConvertTo-ProposalFiniteNumber $Shape.PictureFormat.CropLeft 'CropLeft'),
            (ConvertTo-ProposalFiniteNumber $Shape.PictureFormat.CropTop 'CropTop'),
            (ConvertTo-ProposalFiniteNumber $Shape.PictureFormat.CropRight 'CropRight'),
            (ConvertTo-ProposalFiniteNumber $Shape.PictureFormat.CropBottom 'CropBottom')
        )
        return [pscustomobject]@{available=$true;values=$values;reason='COM crop settings only'}
    } catch {return [pscustomobject]@{available=$false;values=@();reason='Crop properties are unavailable for this existing object'}}
}

function Test-ProposalCropPreserved($Original,$Copy,[double]$ScaleX,[double]$ScaleY) {
    if(-not $Original.available -or -not $Copy.available){return 'unavailable'}
    $rawSame=$true;$scaledSame=$true
    for($i=0;$i -lt 4;$i++){
        $before=[double]$Original.values[$i];$after=[double]$Copy.values[$i]
        $axisScale=if($i -eq 0 -or $i -eq 2){$ScaleX}else{$ScaleY}
        if([math]::Abs($after-$before) -gt 0.01){$rawSame=$false}
        if([math]::Abs($after-$before*$axisScale) -gt 0.01){$scaledSame=$false}
    }
    if($rawSame){return 'same'}
    if($scaledSame){return 'uniform_scaled'}
    return 'different'
}

function Get-ProposalAssetDeclaredOrigin($Asset) {
    $property=$Asset.PSObject.Properties['origin']
    if($null -eq $property){return 'provided'}
    if([string]$property.Value -cnotin @('provided','synthetic_test')){throw 'ASSET_ORIGIN_INVALID: use provided or synthetic_test'}
    return [string]$property.Value
}

function Get-ProposalAssetObservedOrigin($Source) {
    # A fixture tag is provenance metadata, never a judgment about image pixels.
    try {$tag=[string]$Source.Tags.Item('PW_INPUT_ORIGIN')}
    catch {throw 'ASSET_ORIGIN_UNAVAILABLE: source provenance tag cannot be read'}
    switch -CaseSensitive ($tag.ToUpperInvariant()) {
        '' {return 'provided'}
        'PROVIDED' {return 'provided'}
        'SYNTHETIC_TEST' {return 'synthetic_test'}
        default {throw 'ASSET_ORIGIN_TAG_UNSUPPORTED: source provenance tag is not registered'}
    }
}

function Get-ProposalAssetDeclaredRatio($Asset,[bool]$Required=$false) {
    $property=$Asset.PSObject.Properties['known_visible_aspect_ratio']
    if($null -eq $property -or $null -eq $property.Value){
        if($Required){throw 'ASSET_VISIBLE_RATIO_REQUIRED: reference-v3 requires the COM visible-frame ratio'}
        return $null
    }
    $numberTypes=@([TypeCode]::Byte,[TypeCode]::SByte,[TypeCode]::Int16,[TypeCode]::UInt16,[TypeCode]::Int32,[TypeCode]::UInt32,[TypeCode]::Int64,[TypeCode]::UInt64,[TypeCode]::Single,[TypeCode]::Double,[TypeCode]::Decimal)
    if([Type]::GetTypeCode($property.Value.GetType()) -notin $numberTypes){throw 'ASSET_VISIBLE_RATIO_INVALID: declared ratio must be numeric data'}
    try {$ratio=ConvertTo-ProposalFiniteNumber $property.Value 'Declared asset visible-frame ratio'}
    catch {throw 'ASSET_VISIBLE_RATIO_INVALID: declared ratio must be a positive finite number'}
    if($ratio -le 0){throw 'ASSET_VISIBLE_RATIO_INVALID: declared ratio must be a positive finite number'}
    return $ratio
}

function Test-ProposalAssetVisibleRatio([double]$Declared,[double]$Actual) {
    return $Declared -gt 0 -and $Actual -gt 0 -and -not [double]::IsNaN($Declared) -and -not [double]::IsInfinity($Declared) -and -not [double]::IsNaN($Actual) -and -not [double]::IsInfinity($Actual) -and [math]::Abs($Declared-$Actual) -le [math]::Max(0.001,$Actual*0.005)
}

function Assert-ProposalAssetSourceMetadata($Asset,$Snapshot,[bool]$RequireDeclaredRatio=$false) {
    if($RequireDeclaredRatio -and [string]$Asset.reference_kind -cne 'picture'){throw 'ASSET_R3_PICTURE_REQUIRED: reference-v3 supports an existing picture only'}
    $origin=Get-ProposalAssetDeclaredOrigin $Asset
    if($origin -cne [string]$Snapshot.origin){throw 'ASSET_ORIGIN_MISMATCH: declared origin differs from the existing source object tag'}
    $declared=Get-ProposalAssetDeclaredRatio $Asset $RequireDeclaredRatio
    if($null -ne $declared -and -not (Test-ProposalAssetVisibleRatio $declared ([double]$Snapshot.ratio))){throw 'ASSET_VISIBLE_RATIO_MISMATCH: declared ratio differs from the existing visible frame'}
}

function Assert-ProposalAssetOriginCaptionSpec($AssetSpec,[object[]]$Shapes) {
    if((Get-ProposalAssetDeclaredOrigin $AssetSpec.asset) -cne 'synthetic_test'){return}
    $expectedId=([string]$AssetSpec.id)+'-origin'
    $captions=@($Shapes|Where-Object {[string]$_.id -ceq $expectedId})
    if($captions.Count -ne 1){throw 'ASSET_SYNTHETIC_LABEL_REQUIRED: synthetic assets require their fixed origin caption'}
    $caption=$captions[0]
    if([string]$caption.kind -cne 'text' -or [string]$caption.role -cne 'source' -or [string]$caption.parent -cne [string]$AssetSpec.parent -or [string]$caption.text -cne '가상 이미지 · 실제 사례 사진 아님'){throw 'ASSET_SYNTHETIC_LABEL_REQUIRED: origin caption must retain exact text, source role and parent'}
}

function Test-ProposalAssetOriginCaptionBinding($Slide,$AssetSpec) {
    try {
        if([string]::IsNullOrWhiteSpace([string]$Slide.Tags.Item('PW_RUN')) -or [string]::IsNullOrWhiteSpace([string]$Slide.Tags.Item('PW_STAGE'))){return $false}
        $caption=$Slide.Shapes.Item((([string]$AssetSpec.id)+'-origin'))
        return [int]$caption.Type -eq 17 -and [string]$caption.Tags.Item('PW_ROLE') -ieq 'source' -and [string]$caption.Tags.Item('PW_PARENT') -ieq [string]$AssetSpec.parent -and [string]$caption.Tags.Item('PW_STAGE') -ieq [string]$Slide.Tags.Item('PW_STAGE') -and [string]$caption.TextFrame.TextRange.Text -ceq '가상 이미지 · 실제 사례 사진 아님'
    } catch {return $false}
}

function Get-ProposalAssetSnapshot($Presentation,$SourceSlide,$Source,[int]$SlideIndex,[string]$Kind,[string]$Description) {
    $type=[int](ConvertTo-ProposalFiniteNumber $Source.Type 'Asset source type')
    if($Kind -eq 'picture' -and $type -notin @(11,13)){throw 'A picture reference must identify an existing picture object'}
    $rotation=ConvertTo-ProposalFiniteNumber $Source.Rotation 'Asset source rotation'
    if([math]::Abs($rotation) -gt 0.01){throw 'Rotated source media is unsupported; do not silently rotate it'}
    $width=ConvertTo-ProposalFiniteNumber $Source.Width 'Asset visible frame width'
    $height=ConvertTo-ProposalFiniteNumber $Source.Height 'Asset visible frame height'
    if($width -le 0 -or $height -le 0){throw 'Asset source visible frame must have positive dimensions'}
    $slideId=[int](ConvertTo-ProposalFiniteNumber $SourceSlide.SlideID 'Asset source SlideID')
    $shapeId=[int](ConvertTo-ProposalFiniteNumber $Source.Id 'Asset source Shape.Id')
    if($slideId -lt 1 -or $shapeId -lt 1){throw 'Asset stable source IDs must be positive'}
    return [pscustomobject]@{shape=$Source;document_name=[string]$Presentation.Name;slide_index=$SlideIndex;slide_id=$slideId;shape_id=$shapeId;shape_name=[string]$Source.Name;reference_kind=$Kind;source_type=$type;width=$width;height=$height;ratio=($width/$height);crop=(Get-ProposalCropSnapshot $Source);origin=(Get-ProposalAssetObservedOrigin $Source);description=$Description}
}

function Get-ProposalAssetSource($Presentation,$Asset,[string]$RunId) {
    if($null -eq $Asset -or [string]::IsNullOrWhiteSpace([string]$Asset.document_name) -or [string]::IsNullOrWhiteSpace([string]$Asset.shape_name) -or [string]::IsNullOrWhiteSpace([string]$Asset.description)){throw 'Existing media reference and supplied description are required'}
    $docName=[string]$Presentation.Name;$docFullName=[string]$Presentation.FullName
    $requested=([string]$Asset.document_name).Replace('\','/')
    if($requested -ine $docName -and $requested -ine $docFullName.Replace('\','/')){throw 'ASSET_OTHER_DOCUMENT_FORBIDDEN: reference must be in the same already-open working document'}
    $kind=([string]$Asset.reference_kind).ToLowerInvariant()
    if($kind -notin @('picture','diagram')){throw 'Unsupported existing media reference kind'}
    $position=ConvertTo-ProposalFiniteNumber $Asset.slide_index 'Asset slide_index'
    if($position -ne [math]::Floor($position) -or $position -lt 1 -or $position -gt [int]$Presentation.Slides.Count){throw 'Asset source slide index is not an existing integer position'}
    $sourceSlide=$Presentation.Slides.Item([int]$position)
    if($RunId -and ([string]$sourceSlide.Tags.Item('PW_RUN')) -ieq $RunId){throw 'ASSET_GENERATED_SOURCE_FORBIDDEN: do not reuse this run output as original material'}
    $found=New-Object 'Collections.Generic.List[object]'
    for($i=1;$i -le [int]$sourceSlide.Shapes.Count;$i++){
        $shape=$sourceSlide.Shapes.Item([int]$i)
        if(([string]$shape.Name) -ceq [string]$Asset.shape_name){$found.Add($shape)}
    }
    if($found.Count -ne 1){throw 'Asset shape_name must match exactly one existing top-level object'}
    $source=$found[0]
    $snapshot=Get-ProposalAssetSnapshot $Presentation $sourceSlide $source ([int]$position) $kind ([string]$Asset.description)
    Assert-ProposalAssetSourceMetadata $Asset $snapshot
    return $snapshot
}

function Get-ProposalBoundAssetSource($Presentation,$CopiedShape,$Asset,[string]$RunId) {
    # Post-save QA follows stable IDs in this same live Presentation graph.
    # It never authenticates a renamed document using the original input name.
    $slideId=ConvertTo-ProposalFiniteNumber ([string]$CopiedShape.Tags.Item('PW_ASSET_SOURCE_SLIDE_ID')) 'Bound asset SlideID'
    $shapeId=ConvertTo-ProposalFiniteNumber ([string]$CopiedShape.Tags.Item('PW_ASSET_SOURCE_SHAPE_ID')) 'Bound asset Shape.Id'
    if($slideId -lt 1 -or $shapeId -lt 1 -or $slideId -ne [math]::Floor($slideId) -or $shapeId -ne [math]::Floor($shapeId)){throw 'Missing or invalid stable asset source IDs; do not silently rebind by name'}
    $slides=New-Object 'Collections.Generic.List[object]'
    $position=0
    for($i=1;$i -le [int]$Presentation.Slides.Count;$i++){
        $current=$Presentation.Slides.Item([int]$i)
        $currentId=ConvertTo-ProposalFiniteNumber $current.SlideID 'Existing source SlideID'
        if($currentId -eq $slideId){$slides.Add($current);$position=$i}
    }
    if($slides.Count -ne 1){throw 'The bound source SlideID is missing or ambiguous in the current presentation'}
    $sourceSlide=$slides[0]
    if($RunId -and ([string]$sourceSlide.Tags.Item('PW_RUN')) -ieq $RunId){throw 'A generated run slide cannot become its own original media source'}
    $found=New-Object 'Collections.Generic.List[object]'
    for($i=1;$i -le [int]$sourceSlide.Shapes.Count;$i++){
        $current=$sourceSlide.Shapes.Item([int]$i)
        $currentId=ConvertTo-ProposalFiniteNumber $current.Id 'Existing source Shape.Id'
        if($currentId -eq $shapeId){$found.Add($current)}
    }
    if($found.Count -ne 1){throw 'The bound source Shape.Id is missing or ambiguous in its source slide'}
    $source=$found[0]
    $recordedName=[string]$CopiedShape.Tags.Item('PW_ASSET_SHAPE')
    if(-not $recordedName -or ([string]$source.Name) -ine $recordedName){throw 'Bound source shape identity no longer matches the recorded source name'}
    $kind=([string]$CopiedShape.Tags.Item('PW_ASSET_KIND')).ToLowerInvariant()
    if($kind -notin @('picture','diagram')){throw 'The bound asset reference kind is unavailable'}
    return Get-ProposalAssetSnapshot $Presentation $sourceSlide $source ([int]$position) $kind ([string]$Asset.description)
}

function Add-ProposalStageSlide($Presentation,[object]$Stage,[object[]]$Shapes,[string]$RunId,[string]$ContentHash) {
    $layoutRevision=Get-ProposalStageLayoutRevision $Stage
    if([string]::IsNullOrWhiteSpace($RunId) -or [string]::IsNullOrWhiteSpace($ContentHash)){throw 'Run ID and content revision are required'}
    if(@($Shapes).Count -eq 0){throw 'No prepared shapes supplied'}
    $ids=@{}
    foreach($spec in $Shapes){
        if(-not $spec.id -or $ids.ContainsKey([string]$spec.id)){throw 'Shape IDs must be nonempty and unique'}
        $ids[[string]$spec.id]=$spec
        $null=Assert-ProposalPreparedNativeShape $spec $layoutRevision
    }
    foreach($spec in $Shapes){if($spec.parent -and -not $ids.ContainsKey([string]$spec.parent)){throw ('Unknown prepared shape parent: '+$spec.parent)}}
    # Resolve every media object before adding or resizing any output slide.
    $assetSources=@{}
    foreach($spec in $Shapes){
        if($spec.kind -eq 'asset'){
            if([double]$spec.w -le 0 -or [double]$spec.h -le 0){throw 'Asset destination frame must have positive dimensions'}
            $source=Get-ProposalAssetSource $Presentation $spec.asset $RunId
            Assert-ProposalAssetSourceMetadata $spec.asset $source ($layoutRevision -cin @('proposal-reference-r3','proposal-reference-r4','proposal-reference-r5','proposal-reference-r6','proposal-reference-r7','proposal-reference-r8','proposal-reference-r9','proposal-reference-r10'))
            Assert-ProposalAssetOriginCaptionSpec $spec $Shapes
            $assetSources[[string]$spec.id]=$source
        }
    }
    $stageId=[string]$Stage.id
    for($i=1;$i -le [int]$Presentation.Slides.Count;$i++){
        $existing=$Presentation.Slides.Item([int]$i)
        if(([string]$existing.Tags.Item('PW_RUN')) -ieq $RunId -and ([string]$existing.Tags.Item('PW_STAGE')) -ieq $stageId){
            if(([string]$existing.Tags.Item('PW_HASH')) -ine $ContentHash -or ([string]$existing.Tags.Item('PW_LAYOUT')) -ine $layoutRevision){throw 'Managed stage revision differs; use a new run, do not overwrite or duplicate it'}
            if(([string]$existing.Tags.Item('PW_STATUS')) -ine 'COMPLETE'){throw 'Prior managed stage is incomplete; inspect it and start a new run instead of retrying blindly'}
            return ,$existing
        }
    }
    $width=ConvertTo-ProposalFiniteNumber $Presentation.PageSetup.SlideWidth 'SlideWidth'
    $height=ConvertTo-ProposalFiniteNumber $Presentation.PageSetup.SlideHeight 'SlideHeight'
    if([math]::Abs($width-960) -gt 0.1 -or [math]::Abs($height-540) -gt 0.1){
        if([int]$Presentation.Slides.Count -ne 0){throw 'Existing document canvas differs; do not resize existing slides'}
        $Presentation.PageSetup.SlideWidth=[single]960
        $Presentation.PageSetup.SlideHeight=[single]540
    }
    $slide=$null
    try {
        $slide=$Presentation.Slides.Add([int]($Presentation.Slides.Count+1),[int]12)
        $slide.Tags.Add('PW_RUN',$RunId);$slide.Tags.Add('PW_STAGE',$stageId)
        $slide.Tags.Add('PW_HASH',$ContentHash);$slide.Tags.Add('PW_LAYOUT',$layoutRevision)
        $slide.Tags.Add('PW_STATUS','INCOMPLETE')
        foreach($spec in $Shapes){
            $shape=$null
            switch([string]$spec.kind){
                {$_ -in @('rect','shape')} {
                    $shape=$slide.Shapes.AddShape([int](Get-ProposalNativePrimitive $spec),[single]$spec.x,[single]$spec.y,[single]$spec.w,[single]$spec.h)
                    $cornerRadius=Get-ProposalCornerRadius $spec
                    if($null -ne $cornerRadius){$shape.Adjustments.Item([int]1)=[single]$cornerRadius}
                    if($spec.fill){$shape.Fill.Visible=[int]-1;$shape.Fill.Solid();$shape.Fill.ForeColor.RGB=ConvertTo-ProposalOfficeColor ([string]$spec.fill)}else{$shape.Fill.Visible=[int]0}
                    if($spec.line_color){$shape.Line.Visible=[int]-1;$shape.Line.ForeColor.RGB=ConvertTo-ProposalOfficeColor ([string]$spec.line_color);$shape.Line.Weight=[single](Get-ProposalLineWidth $spec)}else{$shape.Line.Visible=[int]0}
                    $shape.Rotation=[single]0
                }
                'text' {
                    $shape=$slide.Shapes.AddTextbox([int]1,[single]$spec.x,[single]$spec.y,[single]$spec.w,[single]$spec.h)
                    # Disable both interfaces before writing text: defaults can expand the box.
                    $shape.TextFrame.AutoSize=[int]0
                    $shape.TextFrame2.AutoSize=[int]0
                    $shape.TextFrame.WordWrap=[int]-1
                    $shape.TextFrame2.WordWrap=[int]-1
                    $shape.TextFrame.MarginLeft=[single]0;$shape.TextFrame.MarginRight=[single]0
                    $shape.TextFrame.MarginTop=[single]0;$shape.TextFrame.MarginBottom=[single]0
                    $shape.TextFrame2.MarginLeft=[single]0;$shape.TextFrame2.MarginRight=[single]0
                    $shape.TextFrame2.MarginTop=[single]0;$shape.TextFrame2.MarginBottom=[single]0
                    $shape.TextFrame.TextRange.Text=[string]$spec.text
                    $range=$shape.TextFrame.TextRange
                    $range.Font.Name='맑은 고딕'
                    $range.Font.Size=[single]$spec.font_size
                    $range.Font.Bold=if($spec.font_bold){[int]-1}else{[int]0}
                    $range.Font.Color.RGB=ConvertTo-ProposalOfficeColor ([string]$spec.color)
                    $range.ParagraphFormat.Alignment=[int](Get-ProposalTextAlignment $spec)
                    $range.ParagraphFormat.SpaceBefore=[single]0;$range.ParagraphFormat.SpaceAfter=[single]0
                    $shape.TextFrame.VerticalAnchor=[int]1
                    $shape.Fill.Visible=[int]0;$shape.Line.Visible=[int]0
                    $shape.Rotation=[single]0
                    # Reassert fixed bounds after all text and font assignments.
                    $shape.Left=[single]$spec.x;$shape.Top=[single]$spec.y
                    $shape.Width=[single]$spec.w;$shape.Height=[single]$spec.h
                }
                'line' {
                    $shape=$slide.Shapes.AddLine([single]$spec.x,[single]$spec.y,[single]($spec.x+$spec.w),[single]($spec.y+$spec.h))
                    $shape.Line.Visible=[int]-1
                    $shape.Line.ForeColor.RGB=ConvertTo-ProposalOfficeColor ([string]$spec.line_color)
                    $shape.Line.Weight=[single](Get-ProposalLineWidth $spec)
                    if($spec.role -eq 'connector'){$shape.Line.EndArrowheadStyle=[int]2}
                }
                'asset' {
                    $reference=$assetSources[[string]$spec.id]
                    $null=$reference.shape.Copy()
                    $pasted=$slide.Shapes.Paste()
                    if([int]$pasted.Count -ne 1){throw 'ASSET_PASTE_FAILED: exactly one pasted object is required'}
                    $shape=$pasted.Item([int]1)
                    $copyRotation=ConvertTo-ProposalFiniteNumber $shape.Rotation 'Copied asset rotation'
                    if([math]::Abs($copyRotation) -gt 0.01){throw 'Copied asset rotation changed; no corrective transform is permitted'}
                    $scale=[math]::Min(([double]$spec.w/$reference.width),([double]$spec.h/$reference.height))
                    $shape.LockAspectRatio=[int]-1
                    $shape.Width=[single]($reference.width*$scale)
                    $copyW=ConvertTo-ProposalFiniteNumber $shape.Width 'Copied asset width'
                    $copyH=ConvertTo-ProposalFiniteNumber $shape.Height 'Copied asset height'
                    if($copyW -le 0 -or $copyH -le 0 -or [math]::Abs($copyW/$copyH-$reference.ratio) -gt [math]::Max(0.001,$reference.ratio*0.005)){throw 'Copied visible-frame aspect ratio was not preserved'}
                    $shape.Left=[single]([double]$spec.x+([double]$spec.w-$copyW)/2)
                    $shape.Top=[single]([double]$spec.y+([double]$spec.h-$copyH)/2)
                    $copyCrop=Get-ProposalCropSnapshot $shape
                    $cropMode=Test-ProposalCropPreserved $reference.crop $copyCrop ($copyW/$reference.width) ($copyH/$reference.height)
                    if($cropMode -eq 'different'){throw 'Copied crop settings changed outside uniform frame scaling'}
                    $shape.Tags.Add('PW_ASSET_DOC',[string]$reference.document_name)
                    $shape.Tags.Add('PW_ASSET_SLIDE',[string]$reference.slide_index)
                    $shape.Tags.Add('PW_ASSET_SHAPE',[string]$reference.shape_name)
                    $shape.Tags.Add('PW_ASSET_SOURCE_SLIDE_ID',[string]$reference.slide_id)
                    $shape.Tags.Add('PW_ASSET_SOURCE_SHAPE_ID',[string]$reference.shape_id)
                    $shape.Tags.Add('PW_ASSET_INPUT_DOC_HASH',(Get-ProposalCaptionHash ([string]$spec.asset.document_name)))
                    $shape.Tags.Add('PW_ASSET_KIND',[string]$reference.reference_kind)
                    $shape.Tags.Add('PW_ASSET_RATIO',$reference.ratio.ToString('R',[Globalization.CultureInfo]::InvariantCulture))
                    $shape.Tags.Add('PW_ASSET_DESC_HASH',(Get-ProposalCaptionHash $reference.description))
                    $shape.Tags.Add('PW_ASSET_CROP_MODE',$cropMode)
                    $shape.Tags.Add('PW_ASSET_ORIGIN',[string]$reference.origin)
                    $shape.Tags.Add('PW_INPUT_ORIGIN',([string]$reference.origin).ToUpperInvariant())
                }
            }
            $shape.Name=[string]$spec.id
            $shape.Tags.Add('PW_ROLE',[string]$spec.role)
            $shape.Tags.Add('PW_PARENT',[string]$spec.parent)
            $shape.Tags.Add('PW_STAGE',$stageId)
        }
        $slide.Tags.Add('PW_STATUS','COMPLETE')
        return ,$slide
    } catch {
        if($null -ne $slide){try {$slide.Tags.Add('PW_STATUS','INCOMPLETE')} catch {}}
        throw
    }
}

function Set-ProposalRepairNativeShape($Shape,$Spec) {
    # Only preflighted existing native objects; no object creation, deletion or media operations.
    if($Spec.kind -ne 'line'){$Shape.LockAspectRatio=[int]0}
    if($Spec.kind -eq 'text'){
        $Shape.TextFrame.AutoSize=[int]0;$Shape.TextFrame2.AutoSize=[int]0
        $Shape.TextFrame.WordWrap=[int]-1;$Shape.TextFrame2.WordWrap=[int]-1
        $Shape.TextFrame.MarginLeft=[single]0;$Shape.TextFrame.MarginRight=[single]0
        $Shape.TextFrame.MarginTop=[single]0;$Shape.TextFrame.MarginBottom=[single]0
        $Shape.TextFrame2.MarginLeft=[single]0;$Shape.TextFrame2.MarginRight=[single]0
        $Shape.TextFrame2.MarginTop=[single]0;$Shape.TextFrame2.MarginBottom=[single]0
        $Shape.TextFrame.TextRange.Text=[string]$Spec.text
        $range=$Shape.TextFrame.TextRange
        $range.Font.Name='맑은 고딕';$range.Font.Size=[single]$Spec.font_size
        $range.Font.Bold=if($Spec.font_bold){[int]-1}else{[int]0}
        $range.Font.Color.RGB=ConvertTo-ProposalOfficeColor ([string]$Spec.color)
        $range.ParagraphFormat.Alignment=[int](Get-ProposalTextAlignment $Spec)
        $range.ParagraphFormat.SpaceBefore=[single]0;$range.ParagraphFormat.SpaceAfter=[single]0
        $Shape.TextFrame.VerticalAnchor=[int]1
        $Shape.Fill.Visible=[int]0;$Shape.Line.Visible=[int]0
    } elseif($Spec.kind -in @('rect','shape')){
        $cornerRadius=Get-ProposalCornerRadius $Spec
        if($null -ne $cornerRadius){$Shape.Adjustments.Item([int]1)=[single]$cornerRadius}
        if($Spec.fill){$Shape.Fill.Visible=[int]-1;$Shape.Fill.Solid();$Shape.Fill.ForeColor.RGB=ConvertTo-ProposalOfficeColor ([string]$Spec.fill)}else{$Shape.Fill.Visible=[int]0}
        if($Spec.line_color){$Shape.Line.Visible=[int]-1;$Shape.Line.ForeColor.RGB=ConvertTo-ProposalOfficeColor ([string]$Spec.line_color);$Shape.Line.Weight=[single](Get-ProposalLineWidth $Spec)}else{$Shape.Line.Visible=[int]0}
    } else {
        $Shape.Line.Visible=[int]-1
        $Shape.Line.ForeColor.RGB=ConvertTo-ProposalOfficeColor ([string]$Spec.line_color)
        $Shape.Line.Weight=[single](Get-ProposalLineWidth $Spec)
        $Shape.Line.EndArrowheadStyle=if($Spec.role -eq 'connector'){[int]2}else{[int]1}
    }
    if($Spec.kind -ne 'line'){$Shape.Rotation=[single]0}
    $Shape.Left=[single]$Spec.x;$Shape.Top=[single]$Spec.y
    $Shape.Width=[single]$Spec.w;$Shape.Height=[single]$Spec.h
}

function Repair-ProposalStageSlide($Presentation,[object]$Stage,[object[]]$Shapes,[string]$RunId,[string]$ContentHash) {
    $layoutRevision=Get-ProposalStageLayoutRevision $Stage
    if([string]::IsNullOrWhiteSpace($RunId) -or [string]::IsNullOrWhiteSpace($ContentHash) -or [string]::IsNullOrWhiteSpace([string]$Stage.id)){throw 'Repair requires an exact run, stage and existing content hash'}
    if([string]$Stage.id -notin @('problem','cause','actions','effects','rollout')){throw 'Repair supports the registered proposal stages only'}
    if(@($Shapes).Count -eq 0){throw 'Repair requires a complete prepared shape specification'}
    if(@($Shapes | Where-Object {$_.kind -eq 'asset'}).Count){throw 'REPAIR_ASSET_UNSUPPORTED: media requires a new explicitly scoped run'}
    $kindTypes=@{rect=1;shape=1;text=17;line=9}
    $specs=@{}
    foreach($spec in $Shapes){
        if(-not $spec.id -or $specs.ContainsKey([string]$spec.id)){throw 'Repair requires unique nonempty expected shape names'}
        if(-not $kindTypes.ContainsKey([string]$spec.kind)){throw 'Repair supports registered native shapes, text and axis-aligned lines only'}
        $specs[[string]$spec.id]=$spec
        $null=Assert-ProposalPreparedNativeShape $spec $layoutRevision
    }
    foreach($spec in $Shapes){if($spec.parent -and -not $specs.ContainsKey([string]$spec.parent)){throw 'Repair contains an unregistered parent binding'}}
    $owned=New-Object 'Collections.Generic.List[object]'
    for($i=1;$i -le [int]$Presentation.Slides.Count;$i++){
        $candidate=$Presentation.Slides.Item([int]$i)
        if(([string]$candidate.Tags.Item('PW_RUN')) -ieq $RunId -and ([string]$candidate.Tags.Item('PW_STAGE')) -ieq [string]$Stage.id){$owned.Add($candidate)}
    }
    if($owned.Count -ne 1){throw 'Repair requires exactly one already-owned stage slide'}
    $slide=$owned[0]
    if(([string]$slide.Tags.Item('PW_HASH')) -ine $ContentHash){throw 'REPAIR_CONTENT_REVISION_MISMATCH: use a new run for different source content'}
    if(([string]$slide.Tags.Item('PW_LAYOUT')) -ine $layoutRevision){throw 'Repair does not guess or migrate another layout revision'}
    if(([string]$slide.Tags.Item('PW_STATUS')) -ine 'COMPLETE'){throw 'REPAIR_INCOMPLETE_BLOCKED: inspect prior mutation failure; do not blindly retry'}
    $slideId=[int](ConvertTo-ProposalFiniteNumber $slide.SlideID 'Repair SlideID')
    $width=ConvertTo-ProposalFiniteNumber $Presentation.PageSetup.SlideWidth 'Repair SlideWidth'
    $height=ConvertTo-ProposalFiniteNumber $Presentation.PageSetup.SlideHeight 'Repair SlideHeight'
    if([math]::Abs($width-960) -gt 0.1 -or [math]::Abs($height-540) -gt 0.1){throw 'Repair must not resize the presentation canvas'}
    if([int]$slide.Shapes.Count -ne @($Shapes).Count){throw 'REPAIR_SHAPE_SCOPE_MISMATCH: expected exact object count; no additions or deletions are allowed'}
    $byName=@{};$nameCounts=@{}
    for($i=1;$i -le [int]$slide.Shapes.Count;$i++){
        $shape=$slide.Shapes.Item([int]$i);$name=[string]$shape.Name
        $nameCounts[$name]=1+[int]$nameCounts[$name];$byName[$name]=$shape
    }
    $prepared=New-Object 'Collections.Generic.List[object]'
    foreach($spec in $Shapes){
        $name=[string]$spec.id
        if(-not $byName.ContainsKey($name) -or $nameCounts[$name] -ne 1){throw ('Repair shape name is missing or ambiguous: '+$name)}
        $shape=$byName[$name]
        if(([string]$shape.Name) -cne $name){throw ('Repair does not infer renamed object identity: '+$name)}
        $type=[int](ConvertTo-ProposalFiniteNumber $shape.Type 'Repair object type')
        if($type -ne $kindTypes[[string]$spec.kind]){throw ('Repair native object kind changed: '+$name)}
        if(([string]$shape.Tags.Item('PW_ROLE')) -ine [string]$spec.role -or ([string]$shape.Tags.Item('PW_PARENT')) -ine [string]$spec.parent -or ([string]$shape.Tags.Item('PW_STAGE')) -ine [string]$Stage.id){throw ('Repair role, parent or stage binding changed: '+$name)}
        if($spec.kind -in @('rect','shape')){
            if([int](ConvertTo-ProposalFiniteNumber $shape.AutoShapeType 'Repair AutoShapeType') -ne (Get-ProposalNativePrimitive $spec)){throw 'Repair does not change the original native primitive'}
            $cornerRadius=Get-ProposalCornerRadius $spec
            if($null -ne $cornerRadius){
                if((ConvertTo-ProposalFiniteNumber $shape.Adjustments.Count 'Repair Adjustments.Count') -lt 1){throw 'Repair roundrect adjustment is unavailable'}
                $null=ConvertTo-ProposalFiniteNumber ($shape.Adjustments.Item([int]1)) 'Repair corner adjustment'
            }
            if([int](ConvertTo-ProposalFiniteNumber $shape.HasTextFrame 'Repair HasTextFrame') -eq -1 -and [int](ConvertTo-ProposalFiniteNumber $shape.TextFrame.HasText 'Repair HasText') -ne 0){throw 'Repair refuses unplanned text inside a non-text native shape'}
            if($spec.kind -eq 'shape' -and ([int](ConvertTo-ProposalFiniteNumber $shape.HorizontalFlip 'Repair native HorizontalFlip') -ne 0 -or [int](ConvertTo-ProposalFiniteNumber $shape.VerticalFlip 'Repair native VerticalFlip') -ne 0)){throw 'Repair does not infer a flipped native primitive direction'}
        } elseif($spec.kind -eq 'text'){
            if([int](ConvertTo-ProposalFiniteNumber $shape.HasTextFrame 'Repair text frame') -ne -1){throw 'Repair expected a text frame'}
            if([int](ConvertTo-ProposalFiniteNumber $shape.TextFrame.Orientation 'Repair text orientation') -ne 1){throw 'Repair does not infer a changed text orientation'}
        } else {
            $rotation=ConvertTo-ProposalFiniteNumber $shape.Rotation 'Repair line rotation'
            $flipH=[int](ConvertTo-ProposalFiniteNumber $shape.HorizontalFlip 'Repair HorizontalFlip')
            $flipV=[int](ConvertTo-ProposalFiniteNumber $shape.VerticalFlip 'Repair VerticalFlip')
            if([math]::Abs($rotation) -gt 0.01 -or $flipH -ne 0 -or $flipV -ne 0){throw 'Repair does not infer a rotated or flipped line direction'}
        }
        $prepared.Add([pscustomobject]@{shape=$shape;spec=$spec;shape_id=[int](ConvertTo-ProposalFiniteNumber $shape.Id 'Repair Shape.Id');role=[string]$shape.Tags.Item('PW_ROLE');parent=[string]$shape.Tags.Item('PW_PARENT');stage=[string]$shape.Tags.Item('PW_STAGE')})
    }
    # All scope and identity checks above are read-only. Mutation begins here.
    try {
        $slide.Tags.Add('PW_STATUS','INCOMPLETE')
        foreach($item in $prepared){Set-ProposalRepairNativeShape $item.shape $item.spec}
        if([int]$slide.SlideID -ne $slideId){throw 'Repair slide identity changed unexpectedly'}
        if([int]$slide.Shapes.Count -ne $prepared.Count){throw 'Repair object count changed unexpectedly'}
        foreach($item in $prepared){
            if([int]$item.shape.Id -ne $item.shape_id -or [string]$item.shape.Name -cne [string]$item.spec.id){throw 'Repair object identity changed unexpectedly'}
            if([int]$item.shape.Type -ne $kindTypes[[string]$item.spec.kind]){throw 'Repair object kind changed unexpectedly'}
            if($item.spec.kind -in @('rect','shape') -and [int]$item.shape.AutoShapeType -ne (Get-ProposalNativePrimitive $item.spec)){throw 'Repair native primitive changed unexpectedly'}
            if([string]$item.shape.Tags.Item('PW_ROLE') -cne $item.role -or [string]$item.shape.Tags.Item('PW_PARENT') -cne $item.parent -or [string]$item.shape.Tags.Item('PW_STAGE') -cne $item.stage){throw 'Repair object bindings changed unexpectedly'}
        }
        if(([string]$slide.Tags.Item('PW_HASH')) -ine $ContentHash){throw 'Repair content hash changed unexpectedly'}
        $slide.Tags.Add('PW_HASH',$ContentHash);$slide.Tags.Add('PW_LAYOUT',$layoutRevision)
        $slide.Tags.Add('PW_STATUS','COMPLETE')
        return ,$slide
    } catch {
        try {$slide.Tags.Add('PW_STATUS','INCOMPLETE')} catch {}
        throw
    }
}

function Get-ProposalSlideQa($Slide,[object[]]$Shapes) {
    $checks=New-Object 'Collections.Generic.List[object]'
    $errors=New-Object 'Collections.Generic.List[string]'
    $unknowns=New-Object 'Collections.Generic.List[string]'
    $counts=@{pass=0;fail=0;partial=0;unknown=0}
    function Add-PQCheck([string]$Object,[string]$Rule,[string]$Status,[string]$Reason,$Actual,$Expected) {
        $checks.Add([pscustomobject][ordered]@{object=$Object;rule=$Rule;status=$Status;reason=$Reason;actual=$Actual;expected=$Expected})
        $counts[$Status]=1+[int]$counts[$Status]
        if($Status -eq 'fail'){$errors.Add($Object+': '+$Reason)}
        if($Status -eq 'unknown'){$unknowns.Add($Object+': '+$Reason)}
    }
    function Normalize-PQText([string]$Text) {return $Text.Replace("`r`n","`n").Replace("`r","`n").TrimEnd([char[]]@("`n"))}
    $tolerance=0.75
    $layoutRevision=if(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r10'}).Count){'proposal-reference-r10'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r9'}).Count){'proposal-reference-r9'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r8'}).Count){'proposal-reference-r8'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r7'}).Count){'proposal-reference-r7'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r6'}).Count){'proposal-reference-r6'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r5'}).Count){'proposal-reference-r5'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r4'}).Count){'proposal-reference-r4'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r3'}).Count){'proposal-reference-r3'}elseif(@($Shapes | Where-Object {$_.layout_revision -ceq 'proposal-reference-r2'}).Count){'proposal-reference-r2'}else{'proposal-layout-r1'}
    try {
        $actualRevision=[string]$Slide.Tags.Item('PW_LAYOUT')
        $matchingRevision=$actualRevision -ieq $layoutRevision
        foreach($spec in $Shapes){if($spec.PSObject.Properties['layout_revision'] -and [string]$spec.layout_revision -cne $layoutRevision){$matchingRevision=$false}}
        Add-PQCheck 'slide' 'layout_revision' $(if($matchingRevision){'pass'}else{'fail'}) 'Managed slide and prepared specification use the same layout revision' $actualRevision $layoutRevision
    } catch {Add-PQCheck 'slide' 'layout_revision' 'unknown' 'Cannot read managed layout revision' $null $layoutRevision}
    try {
        $managedStatus=[string]$Slide.Tags.Item('PW_STATUS')
        Add-PQCheck 'slide' 'managed_status' $(if($managedStatus -ieq 'COMPLETE'){'pass'}else{'fail'}) 'Managed mutation must have completed before QA can accept the stage' $managedStatus 'COMPLETE'
    } catch {Add-PQCheck 'slide' 'managed_status' 'unknown' 'Cannot read managed mutation status' $null 'COMPLETE'}
    try {
        $actualCount=[int](ConvertTo-ProposalFiniteNumber $Slide.Shapes.Count 'Shapes.Count')
        $countStatus=if($actualCount -eq @($Shapes).Count){'pass'}else{'fail'}
        Add-PQCheck 'slide' 'shape_count' $countStatus 'Managed shape count' $actualCount @($Shapes).Count
    } catch {Add-PQCheck 'slide' 'shape_count' 'unknown' 'Cannot read managed shape count' $null @($Shapes).Count}
    $actuals=@{};$specs=@{}
    foreach($spec in $Shapes){
        $id=[string]$spec.id;$specs[$id]=$spec
        try {$shape=$Slide.Shapes.Item($id)} catch {Add-PQCheck $id 'exists' 'fail' 'Expected named shape missing' $null $id;continue}
        Add-PQCheck $id 'exists' 'pass' 'Named editable object exists' ([string]$shape.Name) $id
        if($spec.kind -in @('rect','shape','text','line')){
            try {
                $expectedType=@{rect=1;shape=1;text=17;line=9}[[string]$spec.kind]
                $nativeType=[int](ConvertTo-ProposalFiniteNumber $shape.Type 'Native Type')
                Add-PQCheck $id 'native_type' $(if($nativeType -eq $expectedType){'pass'}else{'fail'}) 'Native editable object kind matches the prepared specification' $nativeType $expectedType
                if($spec.kind -in @('rect','shape')){
                    $primitive=[int](ConvertTo-ProposalFiniteNumber $shape.AutoShapeType 'AutoShapeType')
                    $expectedPrimitive=Get-ProposalNativePrimitive $spec
                    Add-PQCheck $id 'native_primitive' $(if($primitive -eq $expectedPrimitive){'pass'}else{'fail'}) 'Fixed native primitive is retained' $primitive $expectedPrimitive
                    if($spec.kind -eq 'shape'){
                        $flipH=[int](ConvertTo-ProposalFiniteNumber $shape.HorizontalFlip 'Native HorizontalFlip');$flipV=[int](ConvertTo-ProposalFiniteNumber $shape.VerticalFlip 'Native VerticalFlip')
                        Add-PQCheck $id 'native_direction' $(if($flipH -eq 0 -and $flipV -eq 0){'pass'}else{'fail'}) 'Native primitive retains its unflipped direction' @($flipH,$flipV) @(0,0)
                    }
                }
            } catch {Add-PQCheck $id 'native_type' 'unknown' 'Cannot read required native object type or primitive' $null $null}
        }
        if($null -ne $spec.PSObject.Properties['corner_radius'] -and $null -ne $spec.corner_radius){
            try {
                $expectedRadius=Get-ProposalCornerRadius $spec
                $actualRadius=ConvertTo-ProposalFiniteNumber ($shape.Adjustments.Item([int]1)) 'Corner Adjustments.Item(1)'
                Add-PQCheck $id 'corner_radius' $(if([math]::Abs($actualRadius-$expectedRadius) -le 0.002){'pass'}else{'fail'}) 'Configured roundrect corner adjustment' $actualRadius $expectedRadius
            } catch {Add-PQCheck $id 'corner_radius' 'unknown' ('Cannot read configured roundrect adjustment: '+$_.Exception.Message) $null $spec.corner_radius}
        }
        try {
            $left=ConvertTo-ProposalFiniteNumber $shape.Left 'Left';$top=ConvertTo-ProposalFiniteNumber $shape.Top 'Top'
            $width=ConvertTo-ProposalFiniteNumber $shape.Width 'Width';$height=ConvertTo-ProposalFiniteNumber $shape.Height 'Height'
            $actuals[$id]=@{x=$left;y=$top;w=$width;h=$height;parent=[string]$spec.parent;kind=[string]$spec.kind;role=[string]$spec.role}
            if($spec.kind -eq 'asset'){
                $contained=$width -gt 0 -and $height -gt 0 -and $left -ge [double]$spec.x-$tolerance -and $top -ge [double]$spec.y-$tolerance -and $left+$width -le [double]$spec.x+[double]$spec.w+$tolerance -and $top+$height -le [double]$spec.y+[double]$spec.h+$tolerance
                Add-PQCheck $id 'asset_frame' $(if($contained){'pass'}else{'fail'}) 'Copied visible object is contained in the fixed destination frame' @($left,$top,$width,$height) @($spec.x,$spec.y,$spec.w,$spec.h)
            } else {
                $bad=[math]::Abs($left-[double]$spec.x) -gt $tolerance -or [math]::Abs($top-[double]$spec.y) -gt $tolerance -or [math]::Abs($width-[double]$spec.w) -gt $tolerance -or [math]::Abs($height-[double]$spec.h) -gt $tolerance
                Add-PQCheck $id 'fixed_geometry' $(if($bad){'fail'}else{'pass'}) 'Fixed layout coordinates' @($left,$top,$width,$height) @($spec.x,$spec.y,$spec.w,$spec.h)
            }
            $outside=$left -lt -$tolerance -or $top -lt -$tolerance -or $left+$width -gt 960+$tolerance -or $top+$height -gt 540+$tolerance
            Add-PQCheck $id 'canvas' $(if($outside){'fail'}else{'pass'}) 'Object remains inside the supported canvas' @($left,$top,$width,$height) @(0,0,960,540)
            if($spec.kind -ne 'line'){
                $rotation=ConvertTo-ProposalFiniteNumber $shape.Rotation 'Rotation'
                Add-PQCheck $id 'rotation' $(if([math]::Abs($rotation) -gt 0.01){'fail'}else{'pass'}) 'No rotated cards or text in supported layouts' $rotation 0
            }
        } catch {Add-PQCheck $id 'geometry' 'unknown' 'Cannot read required geometry' $null $null}
        try {
            $actualRole=[string]$shape.Tags.Item('PW_ROLE');$actualParent=[string]$shape.Tags.Item('PW_PARENT')
            $match=$actualRole -ieq [string]$spec.role -and $actualParent -ieq [string]$spec.parent
            Add-PQCheck $id 'role_binding' $(if($match){'pass'}else{'fail'}) 'Role and parent binding' @($actualRole,$actualParent) @($spec.role,$spec.parent)
        } catch {Add-PQCheck $id 'role_binding' 'unknown' 'Cannot read required role binding' $null $null}
        try {
            if($spec.kind -in @('rect','shape')){
                $fillVisible=[int](ConvertTo-ProposalFiniteNumber $shape.Fill.Visible 'Fill.Visible')
                if($spec.fill){
                    $fillColor=[int](ConvertTo-ProposalFiniteNumber $shape.Fill.ForeColor.RGB 'Fill.RGB');$expectedFill=ConvertTo-ProposalOfficeColor ([string]$spec.fill)
                    $fillType=[int](ConvertTo-ProposalFiniteNumber $shape.Fill.Type 'Fill.Type')
                    Add-PQCheck $id 'fill_color' $(if($fillColor -eq $expectedFill -and $fillVisible -eq -1 -and $fillType -eq 1){'pass'}else{'fail'}) 'Configured visible solid fill color' @($fillColor,$fillVisible,$fillType) @($expectedFill,-1,1)
                } else {Add-PQCheck $id 'fill_visible' $(if($fillVisible -eq 0){'pass'}else{'fail'}) 'Unfilled native object has no visible fill' $fillVisible 0}
            }
            if($spec.line_color){
                $lineColor=[int](ConvertTo-ProposalFiniteNumber $shape.Line.ForeColor.RGB 'Line.RGB');$expectedLine=ConvertTo-ProposalOfficeColor ([string]$spec.line_color)
                $lineVisible=[int](ConvertTo-ProposalFiniteNumber $shape.Line.Visible 'Line.Visible')
                Add-PQCheck $id 'line_color' $(if($lineColor -eq $expectedLine -and $lineVisible -eq -1){'pass'}else{'fail'}) 'Configured visible line color' @($lineColor,$lineVisible) @($expectedLine,-1)
                $lineWidth=ConvertTo-ProposalFiniteNumber $shape.Line.Weight 'Line.Weight';$expectedWidth=Get-ProposalLineWidth $spec
                Add-PQCheck $id 'line_width' $(if([math]::Abs($lineWidth-$expectedWidth) -le 0.05){'pass'}else{'fail'}) 'Configured bounded line width' $lineWidth $expectedWidth
            } elseif($spec.kind -in @('rect','shape')){
                $lineVisible=[int](ConvertTo-ProposalFiniteNumber $shape.Line.Visible 'Line.Visible')
                Add-PQCheck $id 'line_visible' $(if($lineVisible -eq 0){'pass'}else{'fail'}) 'Native object without a configured border has no visible line' $lineVisible 0
            }
            if($spec.kind -eq 'line' -and $spec.role -eq 'connector'){
                $arrow=[int](ConvertTo-ProposalFiniteNumber $shape.Line.EndArrowheadStyle 'Line.EndArrowheadStyle')
                Add-PQCheck $id 'connector_arrow' $(if($arrow -eq 2){'pass'}else{'fail'}) 'Connector points toward the supplied target end' $arrow 2
            }
        } catch {Add-PQCheck $id 'color_style' 'unknown' 'Cannot read configured color or connector style' $null $null}
        if($spec.kind -eq 'asset'){
            try {
                $runId=[string]$Slide.Tags.Item('PW_RUN')
                $reference=Get-ProposalBoundAssetSource $Slide.Parent $shape $spec.asset $runId
                $docTag=[string]$shape.Tags.Item('PW_ASSET_DOC');$slideTag=[string]$shape.Tags.Item('PW_ASSET_SLIDE')
                $shapeTag=[string]$shape.Tags.Item('PW_ASSET_SHAPE');$kindTag=[string]$shape.Tags.Item('PW_ASSET_KIND')
                $slideIdTag=[string]$shape.Tags.Item('PW_ASSET_SOURCE_SLIDE_ID');$shapeIdTag=[string]$shape.Tags.Item('PW_ASSET_SOURCE_SHAPE_ID')
                $docInputTag=[string]$shape.Tags.Item('PW_ASSET_INPUT_DOC_HASH');$expectedDocInput=Get-ProposalCaptionHash ([string]$spec.asset.document_name)
                $sameBinding=-not [string]::IsNullOrWhiteSpace($docTag) -and $docInputTag -ieq $expectedDocInput -and $slideTag -eq [string]$spec.asset.slide_index -and $shapeTag -ieq [string]$spec.asset.shape_name -and $kindTag -ieq [string]$spec.asset.reference_kind -and $slideIdTag -eq [string]$reference.slide_id -and $shapeIdTag -eq [string]$reference.shape_id
                Add-PQCheck $id 'asset_source_binding' $(if($sameBinding){'pass'}else{'fail'}) 'Original input metadata and stable IDs bind an object in the current presentation, including after SaveAs' @($docInputTag,$slideTag,$shapeTag,$kindTag,$slideIdTag,$shapeIdTag) @($expectedDocInput,$spec.asset.slide_index,$spec.asset.shape_name,$spec.asset.reference_kind,$reference.slide_id,$reference.shape_id)
                $descTag=[string]$shape.Tags.Item('PW_ASSET_DESC_HASH');$expectedDesc=Get-ProposalCaptionHash ([string]$spec.asset.description)
                Add-PQCheck $id 'asset_description_binding' $(if($descTag -ieq $expectedDesc){'pass'}else{'fail'}) 'Supplied description binding only; its truth is not established by this comparison' $descTag $expectedDesc
                $declaredOrigin=Get-ProposalAssetDeclaredOrigin $spec.asset
                $copyOrigin=[string]$shape.Tags.Item('PW_ASSET_ORIGIN');$copyInputOrigin=[string]$shape.Tags.Item('PW_INPUT_ORIGIN')
                $sameOrigin=$declaredOrigin -ceq [string]$reference.origin -and $copyOrigin -ieq [string]$reference.origin -and $copyInputOrigin -ieq ([string]$reference.origin).ToUpperInvariant()
                # Existing R1/R2 provided copies did not carry origin tags. R3/R4 always require them.
                $originRequired=$layoutRevision -cin @('proposal-reference-r3','proposal-reference-r4','proposal-reference-r5','proposal-reference-r6','proposal-reference-r7','proposal-reference-r8','proposal-reference-r9','proposal-reference-r10') -or $null -ne $spec.asset.PSObject.Properties['origin'] -or [string]$reference.origin -ceq 'synthetic_test' -or -not [string]::IsNullOrWhiteSpace($copyOrigin) -or -not [string]::IsNullOrWhiteSpace($copyInputOrigin)
                if($originRequired){Add-PQCheck $id 'asset_origin_binding' $(if($sameOrigin){'pass'}else{'fail'}) 'Declared provenance matches the source object and copied provenance tags; no image interpretation' @($declaredOrigin,$reference.origin,$copyOrigin,$copyInputOrigin) $declaredOrigin}
                if($declaredOrigin -ceq 'synthetic_test' -or [string]$reference.origin -ceq 'synthetic_test' -or $copyOrigin -ieq 'synthetic_test'){
                    $captionBound=Test-ProposalAssetOriginCaptionBinding $Slide $spec
                    Add-PQCheck $id 'asset_synthetic_label' $(if($captionBound){'pass'}else{'fail'}) 'Synthetic source has its exact origin caption on this managed stage' $captionBound '가상 이미지 · 실제 사례 사진 아님'
                    try {
                        $originCaption=$Slide.Shapes.Item((([string]$spec.id)+'-origin'))
                        $captionVisible=ConvertTo-ProposalFiniteNumber $originCaption.Visible 'Synthetic origin caption Shape.Visible'
                        Add-PQCheck $id 'asset_synthetic_caption_visible' $(if($captionVisible -eq -1){'pass'}else{'fail'}) 'Synthetic origin caption shape is currently visible; source-slide visibility is not inspected' $captionVisible -1
                    } catch {Add-PQCheck $id 'asset_synthetic_caption_visible' 'unknown' ('Cannot read synthetic origin caption Shape.Visible: '+$_.Exception.Message) $null -1}
                }
                $declaredRatio=Get-ProposalAssetDeclaredRatio $spec.asset ($layoutRevision -cin @('proposal-reference-r3','proposal-reference-r4','proposal-reference-r5','proposal-reference-r6','proposal-reference-r7','proposal-reference-r8','proposal-reference-r9','proposal-reference-r10'))
                if($null -ne $declaredRatio){
                    $sameDeclaredRatio=Test-ProposalAssetVisibleRatio $declaredRatio ([double]$reference.ratio)
                    Add-PQCheck $id 'asset_declared_visible_frame_ratio' $(if($sameDeclaredRatio){'pass'}else{'fail'}) 'Declared input ratio matches the current source visible frame; no intrinsic pixel-size claim' $declaredRatio $reference.ratio
                }
                $copyW=ConvertTo-ProposalFiniteNumber $shape.Width 'Copied visible width'
                $copyH=ConvertTo-ProposalFiniteNumber $shape.Height 'Copied visible height'
                if($copyH -le 0 -or $copyW -le 0){throw 'Copied visible frame is not positive'}
                $copyRatio=$copyW/$copyH
                $ratioTag=[double]::Parse(([string]$shape.Tags.Item('PW_ASSET_RATIO')),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture)
                $sameRatio=[math]::Abs($copyRatio-$reference.ratio) -le [math]::Max(0.001,$reference.ratio*0.005) -and [math]::Abs($ratioTag-$reference.ratio) -le [math]::Max(0.001,$reference.ratio*0.005)
                Add-PQCheck $id 'asset_visible_frame_ratio' $(if($sameRatio){'pass'}else{'fail'}) 'Preserves the existing visible frame ratio; not an intrinsic image ratio measurement' $copyRatio $reference.ratio
                $locked=[int](ConvertTo-ProposalFiniteNumber $shape.LockAspectRatio 'Copied LockAspectRatio')
                Add-PQCheck $id 'asset_aspect_lock' $(if($locked -eq -1){'pass'}else{'fail'}) 'Copied media aspect lock remains enabled' $locked -1
                $copyType=[int](ConvertTo-ProposalFiniteNumber $shape.Type 'Copied object type')
                $sameType=$copyType -eq $reference.source_type -or ($reference.source_type -eq 11 -and $copyType -eq 13)
                Add-PQCheck $id 'asset_object_type' $(if($sameType){'pass'}else{'fail'}) 'Native copied object type is retained' $copyType $reference.source_type
                $copyCrop=Get-ProposalCropSnapshot $shape
                $cropMode=Test-ProposalCropPreserved $reference.crop $copyCrop ($copyW/$reference.width) ($copyH/$reference.height)
                $cropStatus=if($cropMode -eq 'different'){'fail'}elseif($cropMode -eq 'unavailable'){'partial'}else{'pass'}
                Add-PQCheck $id 'asset_crop_settings' $cropStatus 'Compare readable crop settings without setting or resetting crop' @{mode=$cropMode;values=$copyCrop.values} $reference.crop.values
            } catch {Add-PQCheck $id 'asset_properties' 'unknown' ('Cannot verify required existing-media binding: '+$_.Exception.Message) $null $null}
            Add-PQCheck $id 'asset_content' 'partial' 'Pixels, image meaning and group-internal text readability are not inspected' ([string]$spec.asset.description) 'Supplied business description only'
        }
        if($spec.kind -eq 'text'){
            try {
                $rawTextVisible=$shape.Visible
                if($rawTextVisible -is [string] -and [string]::IsNullOrWhiteSpace($rawTextVisible)){throw 'Text Shape.Visible is unavailable'}
                $textVisible=ConvertTo-ProposalFiniteNumber $rawTextVisible 'Text Shape.Visible'
                $visibilityStatus=if($textVisible -eq -1){'pass'}elseif($textVisible -eq 0){'fail'}else{'unknown'}
                Add-PQCheck $id 'text_visible' $visibilityStatus 'Text shape must be currently visible; mixed or unexpected visibility is unknown and COM does not verify pixels or occlusion' $textVisible -1
            } catch {Add-PQCheck $id 'text_visible' 'unknown' ('Cannot read text Shape.Visible: '+$_.Exception.Message) $null -1}
            try {
                $readText=$shape.TextFrame.TextRange.Text
                if($null -eq $readText){throw 'Text readback unavailable'}
                $text=[string]$readText
                $textMatches=(Normalize-PQText $text) -ceq (Normalize-PQText ([string]$spec.text))
                Add-PQCheck $id 'text' $(if($textMatches){'pass'}else{'fail'}) 'Text readback matches the bound content' $text ([string]$spec.text)
                $font=ConvertTo-ProposalFiniteNumber $shape.TextFrame.TextRange.Font.Size 'Font.Size'
                Add-PQCheck $id 'font_size' $(if([math]::Abs($font-[double]$spec.font_size) -gt 0.1){'fail'}else{'pass'}) 'Configured font size only; not glyph fallback verification' $font ([double]$spec.font_size)
                $fontColor=[int](ConvertTo-ProposalFiniteNumber $shape.TextFrame.TextRange.Font.Color.RGB 'Font.RGB');$expectedColor=ConvertTo-ProposalOfficeColor ([string]$spec.color)
                Add-PQCheck $id 'font_color' $(if($fontColor -eq $expectedColor){'pass'}else{'fail'}) 'Configured text color' $fontColor $expectedColor
                $fontBold=[int](ConvertTo-ProposalFiniteNumber $shape.TextFrame.TextRange.Font.Bold 'Font.Bold');$expectedBold=if($spec.font_bold){-1}else{0}
                Add-PQCheck $id 'font_bold' $(if($fontBold -eq $expectedBold){'pass'}else{'fail'}) 'Configured text weight' $fontBold $expectedBold
                $alignment=[int](ConvertTo-ProposalFiniteNumber $shape.TextFrame.TextRange.ParagraphFormat.Alignment 'ParagraphFormat.Alignment');$expectedAlignment=Get-ProposalTextAlignment $spec
                Add-PQCheck $id 'text_alignment' $(if($alignment -eq $expectedAlignment){'pass'}else{'fail'}) 'Configured paragraph alignment' $alignment $expectedAlignment
                $auto1=[int](ConvertTo-ProposalFiniteNumber $shape.TextFrame.AutoSize 'TextFrame.AutoSize')
                $auto2=[int](ConvertTo-ProposalFiniteNumber $shape.TextFrame2.AutoSize 'TextFrame2.AutoSize')
                Add-PQCheck $id 'auto_size' $(if($auto1 -ne 0 -or $auto2 -ne 0){'fail'}else{'pass'}) 'Automatic text resizing must be disabled' @($auto1,$auto2) @(0,0)
                if($layoutRevision -cin @('proposal-reference-r2','proposal-reference-r3','proposal-reference-r4','proposal-reference-r5','proposal-reference-r6','proposal-reference-r7','proposal-reference-r8','proposal-reference-r9','proposal-reference-r10') -and -not [string]::IsNullOrWhiteSpace($text)){
                    try {
                        $wrapRotation=ConvertTo-ProposalFiniteNumber $shape.Rotation 'Soft wrap Rotation'
                        if($auto1 -ne 0 -or $auto2 -ne 0 -or [math]::Abs($wrapRotation) -gt 0.01){throw 'Rotation or automatic sizing prevents supported line-position inference'}
                        $wrap=Get-ProposalSoftWordBreaks $shape.TextFrame.TextRange $text
                        Add-PQCheck $id 'soft_word_break' $(if($wrap.breaks.Count){'fail'}else{'pass'}) 'Read-only line starts must not split a Korean, Latin or numeric word without source whitespace' $wrap.breaks @()
                    } catch {Add-PQCheck $id 'soft_word_break' 'unknown' ('Cannot verify source-relative line starts: '+$_.Exception.Message) $null 'Readable Lines and Start metadata'}
                }
                if(-not [string]::IsNullOrWhiteSpace($text)){
                    $boundW=ConvertTo-ProposalFiniteNumber $shape.TextFrame2.TextRange.BoundWidth 'BoundWidth'
                    $boundH=ConvertTo-ProposalFiniteNumber $shape.TextFrame2.TextRange.BoundHeight 'BoundHeight'
                    $innerW=(ConvertTo-ProposalFiniteNumber $shape.Width 'Width')-(ConvertTo-ProposalFiniteNumber $shape.TextFrame2.MarginLeft 'MarginLeft')-(ConvertTo-ProposalFiniteNumber $shape.TextFrame2.MarginRight 'MarginRight')
                    $innerH=(ConvertTo-ProposalFiniteNumber $shape.Height 'Height')-(ConvertTo-ProposalFiniteNumber $shape.TextFrame2.MarginTop 'MarginTop')-(ConvertTo-ProposalFiniteNumber $shape.TextFrame2.MarginBottom 'MarginBottom')
                    $textRotation=ConvertTo-ProposalFiniteNumber $shape.Rotation 'Rotation'
                    if($auto1 -ne 0 -or $auto2 -ne 0 -or [math]::Abs($textRotation) -gt 0.01){
                        Add-PQCheck $id 'text_bounds' 'unknown' 'Rotation or automatic sizing prevents supported bounds inference' @($boundW,$boundH) @($innerW,$innerH)
                    } else {
                        $overflow=$boundW -gt $innerW+1 -or $boundH -gt $innerH+1
                        Add-PQCheck $id 'text_bounds' $(if($overflow){'fail'}else{'partial'}) 'Nominal COM text bounds only; no pixel or visual-quality claim' @($boundW,$boundH) @($innerW,$innerH)
                    }
                }
            } catch {Add-PQCheck $id 'text_properties' 'unknown' 'Cannot read required text/font/bounds properties' $null $null}
        }
    }
    foreach($id in @($actuals.Keys)){
        $a=$actuals[$id]
        if($a.parent -and $actuals.ContainsKey($a.parent)){
            $parent=$actuals[$a.parent]
            $contained=$a.x -ge $parent.x-$tolerance -and $a.y -ge $parent.y-$tolerance -and $a.x+$a.w -le $parent.x+$parent.w+$tolerance -and $a.y+$a.h -le $parent.y+$parent.h+$tolerance
            Add-PQCheck $id 'parent_containment' $(if($contained){'pass'}else{'fail'}) 'Declared parent contains its child' @($a.x,$a.y,$a.w,$a.h) @($parent.x,$parent.y,$parent.w,$parent.h)
        }
    }
    # Text is a leaf in r1: no text/text intersection is intentional, regardless of parent.
    $leafText=@($actuals.Keys | Where-Object {$actuals[$_].kind -eq 'text'})
    for($i=0;$i -lt $leafText.Count;$i++){
        for($j=$i+1;$j -lt $leafText.Count;$j++){
            $a=$actuals[$leafText[$i]];$b=$actuals[$leafText[$j]]
            $ow=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x)
            $oh=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
            if($ow -gt $tolerance -and $oh -gt $tolerance){Add-PQCheck ($leafText[$i]+' / '+$leafText[$j]) 'leaf_text_overlap' 'fail' 'Independent leaf text frames overlap, even across different parents' @($ow,$oh) @(0,0)}
        }
    }
    $siblings=@($actuals.Keys | Where-Object {$actuals[$_].role -in @('panel','card','cell')})
    for($i=0;$i -lt $siblings.Count;$i++){
        for($j=$i+1;$j -lt $siblings.Count;$j++){
            $a=$actuals[$siblings[$i]];$b=$actuals[$siblings[$j]]
            if($a.parent -ne $b.parent -or $a.kind -ne $b.kind){continue}
            $ow=[math]::Min($a.x+$a.w,$b.x+$b.w)-[math]::Max($a.x,$b.x)
            $oh=[math]::Min($a.y+$a.h,$b.y+$b.h)-[math]::Max($a.y,$b.y)
            if($ow -gt $tolerance -and $oh -gt $tolerance){Add-PQCheck ($siblings[$i]+' / '+$siblings[$j]) 'sibling_overlap' 'fail' 'Independent sibling objects overlap' @($ow,$oh) @(0,0)}
        }
    }
    $status=if($errors.Count){'fail'}elseif($unknowns.Count){'unknown'}else{'pass_with_limitations'}
    return [pscustomobject][ordered]@{
        status=$status;checks=$checks.ToArray();counts=$counts;errors=$errors.ToArray();unknowns=$unknowns.ToArray()
        visual_qa='not_performed_policy'
        limitations=@('COM settings and geometry are not pixel/render/aesthetic verification','Actual font substitution and image meaning are not verified','Existing media preserves its visible frame only; intrinsic dimensions and group-internal readability are not verified','Company DLP/runtime compatibility is not established by a personal PC run')
    }
}
