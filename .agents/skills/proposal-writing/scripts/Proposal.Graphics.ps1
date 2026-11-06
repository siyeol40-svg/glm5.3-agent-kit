# Fixed native concept illustrations. Pure specifications; no Office, file, media or network access.
# Geometry describes a concept only. The composition layer supplies business facts and source captions.
function Get-ProposalIllustrationSpecs {
    param(
        [string]$Prefix,
        [string]$Parent,
        [string]$Type,
        [double]$X=0,
        [double]$Y=0,
        [double]$W=0,
        [double]$H=0,
        [string]$Color='#216498',
        [string]$Revision='proposal-reference-r4'
    )
    foreach($metadata in @(@{name='Prefix';value=$Prefix},@{name='Parent';value=$Parent},@{name='Revision';value=$Revision})){
        if([string]::IsNullOrWhiteSpace([string]$metadata.value)){throw ('ILLUSTRATION_METADATA: '+$metadata.name+' is required')}
    }
    $supported=@('heat_exchanger','oil','water','microbe','clean','training','rotation','shield','monitor','cost','factory','check','vacuum_chamber','part','erosion','material','energy','tank','filter','membrane_stack')
    if($Type -cnotin $supported){throw ('ILLUSTRATION_UNSUPPORTED: '+$Type)}
    foreach($coordinate in @(@{name='X';value=$X},@{name='Y';value=$Y},@{name='W';value=$W},@{name='H';value=$H})){
        if([double]::IsNaN([double]$coordinate.value) -or [double]::IsInfinity([double]$coordinate.value) -or [double]$coordinate.value -lt 0){throw ('ILLUSTRATION_GEOMETRY: invalid '+$coordinate.name)}
    }
    if($W -le 0 -or $H -le 0 -or [double]::IsInfinity($X+$W) -or [double]::IsInfinity($Y+$H)){throw 'ILLUSTRATION_GEOMETRY: a finite positive slot is required'}
    if($Color -cnotmatch '^#[A-Fa-f0-9]{6}$'){throw 'ILLUSTRATION_COLOR: use a #RRGGBB accent'}

    $items=New-Object 'Collections.Generic.List[object]'
    $state=@{index=0}
    $scale=[math]::Min($W/80.0,$H/64.0)
    $originX=$X+($W-80.0*$scale)/2.0
    $originY=$Y+($H-64.0*$scale)/2.0
    $stroke=[math]::Max(0.8,[math]::Min(1.6,1.1*$scale))
    function Get-G4Tint([double]$WhiteRatio){
        $channels=foreach($offset in @(1,3,5)){
            $channel=[Convert]::ToInt32($Color.Substring($offset,2),16)
            $mixed=[int][math]::Round($channel+(255-$channel)*$WhiteRatio)
            $mixed.ToString('X2')
        }
        return ('#'+($channels -join ''))
    }
    $pale=Get-G4Tint 0.93
    $soft=Get-G4Tint 0.80
    $mid=Get-G4Tint 0.56
    $neutral='#718296'
    $white='#FFFFFF'
    function Add-G4Spec([string]$Kind,[string]$Primitive,[double]$A,[double]$B,[double]$D,[double]$E,[string]$Fill='',[string]$Edge='', [double]$Weight=1.0){
        $state.index++
        $item=[pscustomobject][ordered]@{
            id=($Prefix+'-'+$state.index);role='detail';parent=$Parent;kind=$Kind
            x=($originX+$A*$scale);y=($originY+$B*$scale);w=($D*$scale);h=($E*$scale)
            text='';font_size=12.0;font_bold=$false;color=$Color;fill=$Fill;line_color=$Edge
            primitive=$Primitive;align='left';line_width=([math]::Max(0.8,[math]::Min(1.6,$stroke*$Weight)));layout_revision=$Revision
        }
        if($Primitive -ceq 'roundrect'){$item|Add-Member -NotePropertyName corner_radius -NotePropertyValue 0.06}
        $items.Add($item)
    }
    function Add-G4Shape([string]$Primitive,[double]$A,[double]$B,[double]$D,[double]$E,[string]$Fill='',[string]$Edge='', [double]$Weight=1.0){Add-G4Spec 'shape' $Primitive $A $B $D $E $Fill $Edge $Weight}
    function Add-G4Rect([double]$A,[double]$B,[double]$D,[double]$E,[string]$Fill='',[string]$Edge='', [double]$Weight=1.0){Add-G4Spec 'rect' '' $A $B $D $E $Fill $Edge $Weight}
    function Add-G4Line([double]$A,[double]$B,[double]$D,[double]$E,[string]$Edge='', [double]$Weight=1.0){if(-not $Edge){$Edge=$Color};Add-G4Spec 'line' '' $A $B $D $E '' $Edge $Weight}

    switch -CaseSensitive ($Type){
        'heat_exchanger' {
            Add-G4Shape roundrect 12 15 56 35 $pale $Color 1.15
            Add-G4Rect 12 15 9 35 $soft $Color
            Add-G4Rect 59 15 9 35 $soft $Color
            Add-G4Rect 1 19 11 6 $Color
            Add-G4Rect 68 40 11 6 $Color
            Add-G4Rect 20 4 6 11 $Color
            Add-G4Rect 54 50 6 11 $Color
            Add-G4Rect 9 17 4 11 $pale $Color
            Add-G4Rect 67 37 4 11 $pale $Color
            Add-G4Rect 22 50 5 9 $neutral
            Add-G4Rect 53 50 5 9 $neutral
            Add-G4Line 18 59 45 0 $neutral
            foreach($tubeY in @(23,29,35,41)){Add-G4Line 23 $tubeY 34 0}
            Add-G4Line 23 23 0 18
            Add-G4Line 57 23 0 18
            Add-G4Shape rightArrow 28 26 12 6 $Color
            Add-G4Shape rightArrow 43 36 12 6 $Color
        }
        'oil' {
            Add-G4Shape roundrect 49 18 15 16 $white $Color 1.15
            Add-G4Shape roundrect 22 16 34 39 $pale $Color 1.15
            Add-G4Rect 29 9 20 7 $soft $Color
            Add-G4Rect 30 14 18 3 $Color
            Add-G4Rect 26 35 26 16 '#E5C891'
            Add-G4Line 26 34 26 0
            Add-G4Shape ellipse 29 39 4 4 '#BD9146'
            Add-G4Shape ellipse 39 43 4 4 '#BD9146'
            Add-G4Shape ellipse 46 38 4 4 '#BD9146'
            Add-G4Line 28 23 10 0 $white 1.15
            Add-G4Line 25 58 31 0 $neutral
        }
        'water' {
            Add-G4Rect 7 5 6 22 $Color
            Add-G4Rect 13 20 7 6 $Color
            Add-G4Shape roundrect 16 12 51 43 $white $Color 1.15
            Add-G4Rect 20 32 43 19 '#DAEDF7'
            foreach($waveX in @(23,37,51)){Add-G4Line $waveX 31 9 0}
            Add-G4Line 25 40 34 0 '#73A8C7'
            Add-G4Shape ellipse 30 21 5 5 '#DAEDF7' $Color
            Add-G4Shape ellipse 47 17 7 7 '#DAEDF7' $Color
            Add-G4Shape ellipse 53 44 4 4 $white
            Add-G4Line 13 58 57 0 $neutral
        }
        'microbe' {
            Add-G4Line 40 4 0 12
            Add-G4Line 40 48 0 12
            Add-G4Line 10 32 14 0
            Add-G4Line 56 32 14 0
            foreach($dot in @(@(18,11),@(55,11),@(18,46),@(55,46))){Add-G4Shape ellipse $dot[0] $dot[1] 7 7 $soft $Color}
            Add-G4Shape ellipse 22 14 36 36 $pale $Color 1.15
            Add-G4Shape ellipse 29 21 10 8 $soft $Color
            Add-G4Shape ellipse 42 32 8 10 $mid
            Add-G4Shape ellipse 31 38 4 4 $Color
            Add-G4Shape ellipse 46 23 4 4 $Color
        }
        'clean' {
            Add-G4Rect 36 5 8 29 $pale $Color
            Add-G4Shape roundrect 18 31 45 13 $soft $Color 1.15
            foreach($bristleX in @(22,31,40,49,58)){Add-G4Line $bristleX 44 0 11}
            Add-G4Line 15 58 52 0 $neutral
            Add-G4Shape ellipse 7 14 9 9 $pale $Color
            Add-G4Shape ellipse 17 6 5 5 $soft
            Add-G4Line 63 12 10 0
            Add-G4Line 68 7 0 10
            Add-G4Line 6 39 7 0
            Add-G4Line 9.5 35.5 0 7
        }
        'training' {
            Add-G4Shape roundrect 8 5 64 35 $white $Color 1.15
            Add-G4Rect 8 5 64 5 $soft $Color
            Add-G4Rect 38 40 4 12 $Color
            Add-G4Line 23 54 34 0
            Add-G4Line 19 18 35 0
            Add-G4Line 19 26 23 0
            Add-G4Line 60 24 0 20 $neutral
            foreach($seatX in @(12,35,58)){Add-G4Shape ellipse $seatX 46 8 8 $soft $Color;Add-G4Shape roundrect ($seatX-3) 55 14 7 $pale $Color}
        }
        'rotation' {
            Add-G4Shape ellipse 14 6 52 52 $pale $Color 1.15
            Add-G4Shape ellipse 26 18 28 28 $white $Color
            Add-G4Shape ellipse 34 26 12 12 $soft $Color
            Add-G4Shape rightArrow 31 1 22 9 $Color
            Add-G4Shape downArrow 63 22 9 21 $Color
            foreach($bolt in @(@(22,17),@(54,17),@(22,47),@(54,47))){Add-G4Shape ellipse $bolt[0] $bolt[1] 4 4 $white $Color}
        }
        'shield' {
            Add-G4Shape downArrow 20 24 40 35 $pale $Color 1.15
            Add-G4Shape roundrect 20 6 40 33 $pale $Color 1.15
            Add-G4Rect 21 26 38 12 $pale
            Add-G4Shape ellipse 29 18 22 22 $white $Color
            Add-G4Rect 37 22 6 14 $Color
            Add-G4Rect 33 26 14 6 $Color
            Add-G4Shape ellipse 25 11 3 3 $mid
            Add-G4Shape ellipse 52 11 3 3 $mid
            Add-G4Line 34 44 12 0
        }
        'monitor' {
            Add-G4Shape roundrect 7 6 66 42 $white $Color 1.15
            Add-G4Rect 11 10 58 34 $pale
            Add-G4Rect 11 10 58 5 $soft
            Add-G4Line 18 21 0 17 $neutral
            Add-G4Line 18 38 41 0 $neutral
            Add-G4Rect 24 30 7 8 $mid
            Add-G4Rect 36 25 7 13 $soft
            Add-G4Rect 48 19 7 19 $Color
            Add-G4Rect 36 48 8 8 $Color
            Add-G4Line 23 58 35 0
            Add-G4Shape ellipse 60 18 4 4 $Color
            Add-G4Line 17 17 20 0 $neutral
        }
        'cost' {
            Add-G4Shape ellipse 18 43 44 12 $soft $Color
            Add-G4Rect 18 30 44 18 $soft $Color
            Add-G4Line 18 37 44 0
            Add-G4Shape ellipse 18 24 44 14 $pale $Color 1.15
            Add-G4Shape ellipse 24 27 32 8 $white $Color
            Add-G4Shape ellipse 35 28 10 6 $soft $Color
            Add-G4Line 25 51 30 0
            Add-G4Shape ellipse 4 9 20 20 $pale $Color 1.15
            Add-G4Shape ellipse 9 14 10 10 $soft $Color
        }
        'factory' {
            Add-G4Rect 23 6 8 21 $mid $Color
            Add-G4Rect 46 12 8 15 $mid $Color
            Add-G4Rect 19 5 16 4 $Color
            Add-G4Rect 42 11 16 4 $Color
            Add-G4Rect 10 27 60 29 $pale $Color 1.15
            Add-G4Rect 10 20 16 7 $soft $Color
            Add-G4Rect 29 23 17 4 $soft $Color
            foreach($windowX in @(18,35,52)){Add-G4Rect $windowX 35 9 8 $soft $Color}
            Add-G4Rect 35 47 10 9 $white $Color
            Add-G4Line 6 58 68 0
            Add-G4Line 10 46 60 0 $mid
        }
        'check' {
            Add-G4Shape roundrect 14 5 46 52 $white $Color 1.15
            Add-G4Rect 21 12 32 5 $soft
            Add-G4Line 21 23 32 0 $neutral
            Add-G4Line 21 30 25 0 $neutral
            Add-G4Line 21 37 18 0 $neutral
            Add-G4Line 21 44 14 0 $neutral
            Add-G4Rect 49 51 5 11 $Color
            Add-G4Rect 61 51 5 11 $mid
            Add-G4Shape ellipse 46 35 24 24 $soft $Color 1.15
            Add-G4Shape ellipse 51 40 14 14 $white $Color
            Add-G4Shape ellipse 56 45 4 4 $Color
        }
        'vacuum_chamber' {
            Add-G4Shape roundrect 15 15 50 36 $pale $Color 1.15
            Add-G4Rect 11 11 58 6 $soft $Color
            Add-G4Rect 11 50 58 6 $soft $Color
            Add-G4Shape ellipse 28 21 24 24 $white $Color
            Add-G4Shape ellipse 33 26 14 14 $soft $Color
            Add-G4Line 32 36 16 0
            Add-G4Rect 65 27 12 8 $soft $Color
            Add-G4Line 76 35 0 10
            Add-G4Rect 3 24 12 8 $soft $Color
            Add-G4Rect 21 56 6 6 $Color
            Add-G4Rect 53 56 6 6 $Color
            foreach($bolt in @(@(17,12),@(59,12),@(17,51),@(59,51))){Add-G4Shape ellipse $bolt[0] $bolt[1] 3 3 $white $Color}
            Add-G4Rect 37 3 6 8 $Color
            Add-G4Shape ellipse 63 2 10 10 $white $Color
            Add-G4Line 68 4 0 3
            Add-G4Line 43 7 20 0
        }
        'part' {
            Add-G4Shape ellipse 16 7 48 48 $pale $Color 1.15
            Add-G4Shape ellipse 26 17 28 28 $white $Color
            foreach($hole in @(@(38,11),@(38,47),@(20,29),@(56,29),@(25,16),@(51,16),@(25,42),@(51,42))){Add-G4Shape ellipse $hole[0] $hole[1] 4 4 $white $Color}
        }
        'erosion' {
            Add-G4Shape ellipse 16 7 48 48 $pale $Color 1.15
            Add-G4Shape ellipse 27 18 26 26 $white $Color
            foreach($surfaceMark in @(@(21,17,5),@(19,26,4),@(22,37,6),@(29,44,5),@(39,47,4),@(48,43,5),@(53,34,4))){Add-G4Shape ellipse $surfaceMark[0] $surfaceMark[1] $surfaceMark[2] $surfaceMark[2] $mid}
            Add-G4Line 31 12 7 0 $neutral
            Add-G4Line 48 14 7 0 $neutral
            Add-G4Line 18 31 7 0 $neutral
        }
        'material' {
            Add-G4Rect 12 23 48 32 $soft $Color
            Add-G4Rect 17 17 48 32 $pale $Color
            Add-G4Rect 22 11 48 32 $white $Color 1.15
            foreach($gridY in @(19,27,35)){Add-G4Line 28 $gridY 36 0 $soft}
            foreach($gridX in @(36,46,56)){Add-G4Line $gridX 16 0 22 $soft}
            Add-G4Shape ellipse 61 15 4 4 $Color
        }
        'tank' {
            Add-G4Rect 24 52 6 9 $mid $Color
            Add-G4Rect 50 52 6 9 $mid $Color
            Add-G4Shape ellipse 18 43 44 15 $pale $Color
            Add-G4Rect 18 14 44 36 $pale $Color 1.15
            Add-G4Shape ellipse 18 6 44 18 $soft $Color
            Add-G4Shape ellipse 32 10 16 8 $white $Color
            Add-G4Rect 36 1 8 6 $Color
            Add-G4Shape roundrect 33 27 14 17 $white $Color
            Add-G4Line 37 32 6 0
            Add-G4Line 37 38 6 0
            Add-G4Rect 1 27 17 7 $soft $Color
            Add-G4Shape rightArrow 1 27 13 7 $Color
            Add-G4Rect 62 42 17 7 $soft $Color
            Add-G4Shape rightArrow 66 42 13 7 $Color
        }
        'filter' {
            Add-G4Shape roundrect 22 10 36 46 $pale $Color 1.15
            Add-G4Rect 28 56 24 5 $mid $Color
            Add-G4Rect 17 7 46 7 $soft $Color
            Add-G4Shape roundrect 28 17 24 31 $white $Color
            foreach($filterX in @(33,38,43,48)){Add-G4Line $filterX 21 0 23 $mid}
            Add-G4Line 31 27 18 0 $mid
            Add-G4Line 31 37 18 0 $mid
            Add-G4Rect 1 22 21 7 $soft $Color
            Add-G4Shape rightArrow 1 22 14 7 $Color
            Add-G4Rect 58 39 21 7 $soft $Color
            Add-G4Shape rightArrow 65 39 14 7 $Color
            Add-G4Shape ellipse 34 2 12 5 $soft $Color
        }
        'membrane_stack' {
            Add-G4Shape roundrect 18 7 44 50 $pale $Color 1.15
            Add-G4Rect 18 11 6 42 $soft $Color
            Add-G4Rect 56 11 6 42 $soft $Color
            Add-G4Rect 28 13 3 38 $mid $Color
            Add-G4Rect 35 13 3 38 $soft $Color
            Add-G4Rect 42 13 3 38 $mid $Color
            Add-G4Rect 49 13 3 38 $soft $Color
            Add-G4Line 22 12 36 0
            Add-G4Line 22 52 36 0
            Add-G4Rect 1 20 17 6 $soft $Color
            Add-G4Shape rightArrow 1 20 13 6 $Color
            Add-G4Rect 62 36 17 6 $soft $Color
            Add-G4Shape rightArrow 66 36 13 6 $Color
            Add-G4Rect 37 1 6 6 $Color
            Add-G4Rect 37 57 6 6 $Color
        }
        'energy' {
            Add-G4Rect 31 8 5 13 $Color
            Add-G4Rect 44 8 5 13 $Color
            Add-G4Shape roundrect 27 20 26 24 $pale $Color 1.15
            Add-G4Rect 32 26 16 11 $white $Color
            Add-G4Line 40 44 0 11 '' 1.15
            Add-G4Line 40 55 24 0 '' 1.15
            Add-G4Line 13 25 8 0
            Add-G4Line 9 33 12 0
            Add-G4Line 13 41 8 0
            Add-G4Shape ellipse 60 11 10 10 $pale $Color
            Add-G4Line 65 6 0 10 '' 1.15
            Add-G4Line 28 59 12 0 $neutral
        }
    }
    return $items.ToArray()
}
