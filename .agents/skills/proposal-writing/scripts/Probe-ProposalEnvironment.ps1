# Read-only, targeted capability check. Never opens, saves, captures or changes a document.
param([Parameter(Mandatory)][string]$TargetName)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Proposal.Com.ps1')
try {
    $presentation=Get-ProposalPowerPoint $TargetName
    [ordered]@{
        status='connected_readonly';target_name=[string]$presentation.Name
        powershell_version=$PSVersionTable.PSVersion.ToString()
        office_version=[string]$presentation.Application.Version
        slide_count=[int]$presentation.Slides.Count
        canvas_pt=@([double]$presentation.PageSetup.SlideWidth,[double]$presentation.PageSetup.SlideHeight)
        verified=@('existing_instance_attach','exact_open_document','read_presentation_metadata')
        not_verified=@('company_dlp','company_script_json_io','edit','save','manual_reopen','font_fallback','pixel_or_image_quality')
        office_disk_read=$false;office_modified=$false;new_application=$false;automatic_capture=$false
    } | ConvertTo-Json -Depth 4
    exit 0
} catch {
    [ordered]@{status='unavailable';error=$_.Exception.Message;office_disk_read=$false;office_modified=$false;new_application=$false;automatic_capture=$false}|ConvertTo-Json
    exit 2
}
