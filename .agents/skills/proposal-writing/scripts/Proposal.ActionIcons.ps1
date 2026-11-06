# Closed title-marker checks only; not general semantic or visual-quality proof.
# Reads the developer-owned JSON registry only. No Office/media/model/network IO.
function Assert-ProposalActionIconPolicyKeys($Value,[string[]]$Fields){
    if($null -eq $Value -or ($Value -isnot [pscustomobject] -and $Value -isnot [Collections.IDictionary])){throw 'needs_input: ACTION_ICON_V8_POLICY: registry entries must be objects'}
    $keys=if($Value -is [Collections.IDictionary]){@($Value.Keys)}else{@($Value.PSObject.Properties.Name)}
    foreach($key in $keys){if([string]$key -cnotin $Fields){throw ('needs_input: ACTION_ICON_V8_POLICY: unsupported registry field '+$key)}}
    foreach($key in $Fields){if($key -cnotin $keys){throw ('needs_input: ACTION_ICON_V8_POLICY: missing registry field '+$key)}}
}
function Get-ProposalActionIllustrationPolicy {
    $path=Join-Path $PSScriptRoot '../assets/action-illustration-policy.json'
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw 'needs_input: ACTION_ICON_V8_POLICY: developer registry is missing'}
    try{$policy=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json}catch{throw 'needs_input: ACTION_ICON_V8_POLICY: registry must be valid UTF-8 JSON'}
    Assert-ProposalActionIconPolicyKeys $policy @('schema_version','scope','match_field','coverage','icons')
    if($policy.schema_version -isnot [string] -or $policy.schema_version -cne '1.0' -or $policy.scope -isnot [string] -or $policy.scope -cne 'reference-v8-actions' -or $policy.match_field -isnot [string] -or $policy.match_field -cne 'title' -or $policy.coverage -isnot [string] -or [string]::IsNullOrWhiteSpace($policy.coverage)){throw 'needs_input: ACTION_ICON_V8_POLICY: unsupported schema, scope, match field or coverage'}
    # The same closed native illustration kinds are available through Graphics.
    $kinds=@('heat_exchanger','oil','water','microbe','clean','training','rotation','shield','monitor','cost','factory','check','vacuum_chamber','part','erosion','material','energy','tank','filter','membrane_stack')
    if($policy.icons -isnot [array] -or @($policy.icons).Count -ne $kinds.Count){throw 'needs_input: ACTION_ICON_V8_POLICY: exactly twenty native icon entries are required'}
    $map=@{}
    foreach($entry in $policy.icons){
        Assert-ProposalActionIconPolicyKeys $entry @('icon','intent','title_pattern')
        if($entry.icon -isnot [string] -or $entry.icon -cnotin $kinds -or $map.ContainsKey([string]$entry.icon)){throw 'needs_input: ACTION_ICON_V8_POLICY: unknown or duplicate native icon entry'}
        if($entry.intent -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.intent) -or $entry.title_pattern -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.title_pattern)){throw 'needs_input: ACTION_ICON_V8_POLICY: icon intent and title pattern are required'}
        try{
            $regex=[regex]::new($entry.title_pattern,[Text.RegularExpressions.RegexOptions]::CultureInvariant,[TimeSpan]::FromMilliseconds(250))
            if($regex.IsMatch('')){throw 'empty title is accepted'}
        }catch{throw 'needs_input: ACTION_ICON_V8_POLICY: invalid or empty-matching title pattern'}
        $map[[string]$entry.icon]=$regex
    }
    return [pscustomobject]@{scope=$policy.scope;match_field=$policy.match_field;coverage=$policy.coverage;patterns=$map}
}
function Assert-ProposalActionIconSemantics($Stage){
    if($Stage.id -cne 'actions' -or $Stage.layout_profile -cne 'reference-v8-actions'){throw 'needs_input: ACTION_ICON_V8_UNSUPPORTED: this registry is for explicit V8 actions only'}
    $policy=Get-ProposalActionIllustrationPolicy
    $index=0
    foreach($panel in @($Stage.panels)){
        if($null -eq $panel -or $panel.icon -isnot [string] -or [string]::IsNullOrWhiteSpace($panel.icon)){throw ('needs_input: ACTION_ICON_V8_UNSUPPORTED: choose an explicit registered icon for card '+$index)}
        if(-not $policy.patterns.ContainsKey([string]$panel.icon)){throw ('needs_input: ACTION_ICON_V8_UNSUPPORTED: unregistered icon on card '+$index)}
        if($panel.title -isnot [string] -or [string]::IsNullOrWhiteSpace($panel.title)){throw ('needs_input: ACTION_ICON_V8_UNSUPPORTED: main-concept title is required for card '+$index)}
        # Intentionally do not inspect body, outcome or other broad keywords.
        $title=$panel.title.Normalize([Text.NormalizationForm]::FormKC)
        try{$matchesTitle=$policy.patterns[[string]$panel.icon].IsMatch($title)}catch{throw 'needs_input: ACTION_ICON_V8_POLICY: title-pattern matching failed'}
        if(-not $matchesTitle){throw ('needs_input: ACTION_ICON_V8_MISMATCH: card '+$index+' title does not match its selected icon '+$panel.icon)}
        $index++
    }
    return $true
}
