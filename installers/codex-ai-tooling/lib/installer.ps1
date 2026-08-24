Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.Serialization
$Script:QbitCodexInstallerRoot = ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
$Script:QbitToolkitRoot = ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

$InstallerId = 'installer.codex-ai-tooling'
$InstallerVersion = '1.1.1'
$StatePath = '.qbit/toolkit/installed/codex-ai-tooling.json'
$BeginMarker = '# qbit-toolkit:codex-ai-tooling:start'
$EndMarker = '# qbit-toolkit:codex-ai-tooling:end'
$AgentsBeginMarker = '<!-- qbit-toolkit:codex-ai-tooling:start -->'
$AgentsEndMarker = '<!-- qbit-toolkit:codex-ai-tooling:end -->'
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$WriteModeCanonicalWithTerminalLf = 'canonical-with-terminal-lf'
$WriteModeCanonicalExact = 'canonical-exact'

function ConvertTo-CanonicalPath([string]$Path) {
  return ([System.IO.Path]::GetFullPath($Path)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-TargetRoot([string]$InputPath) {
  if ([string]::IsNullOrWhiteSpace($InputPath)) { throw 'Target is required.' }
  $Resolved = ConvertTo-CanonicalPath $InputPath
  if (-not (Test-Path -LiteralPath $Resolved -PathType Container)) { throw "Target directory does not exist: $InputPath" }
  $RootPath = [System.IO.Path]::GetPathRoot($Resolved).TrimEnd('\', '/')
  if ($Resolved.TrimEnd('\', '/') -ieq $RootPath) { throw 'Refusing to target a filesystem root.' }
  if ($env:USERPROFILE -and ((ConvertTo-CanonicalPath $env:USERPROFILE) -ieq $Resolved)) { throw 'Refusing to target the user home root.' }
  $ToolkitRoot = $Script:QbitToolkitRoot
  if ($Resolved -ieq $ToolkitRoot) { throw 'Refusing to install qbit-toolkit into itself.' }
  $Inside = (& git -C $Resolved rev-parse --is-inside-work-tree 2>$null)
  if ($LASTEXITCODE -ne 0 -or $Inside.Trim() -ne 'true') { throw 'Target must be a Git work tree.' }
  $GitTop = ConvertTo-CanonicalPath ((& git -C $Resolved rev-parse --show-toplevel) -join '')
  if ($GitTop -ine $Resolved) { throw "Target must be the Git work tree root. Git root is: $GitTop" }
  return $Resolved
}

function Get-ProjectSlug([string]$RequestedSlug, [string]$FallbackName) {
  $Candidate = if ([string]::IsNullOrWhiteSpace($RequestedSlug)) { $FallbackName } else { $RequestedSlug }
  $Candidate = $Candidate.ToLowerInvariant() -replace '[ _]+', '-' -replace '[^a-z0-9-]', '-' -replace '-+', '-'
  $Candidate = $Candidate.Trim('-')
  if ($Candidate.Length -gt 50) { $Candidate = $Candidate.Substring(0, 50).Trim('-') }
  if ([string]::IsNullOrWhiteSpace($Candidate)) { throw 'ProjectSlug resolves to an empty slug.' }
  return $Candidate
}

function Resolve-Profile([string]$RequestedProfile, [string]$Root) {
  if ($RequestedProfile -ne 'auto') { return $RequestedProfile }
  if (Test-Path -LiteralPath (Join-Path $Root 'tsconfig.json')) { return 'typescript' }
  $PackageJson = Join-Path $Root 'package.json'
  if (Test-Path -LiteralPath $PackageJson) {
    try {
      $Package = Get-Content -LiteralPath $PackageJson -Raw | ConvertFrom-Json
      foreach ($Section in @('dependencies', 'devDependencies')) {
        if ($Package.PSObject.Properties.Name -contains $Section) {
          $Names = $Package.$Section.PSObject.Properties.Name
          if ($Names -contains 'typescript') { return 'typescript' }
        }
      }
    } catch {
      Write-Warning "Could not parse package.json for profile auto-detection: $($_.Exception.Message)"
    }
  }
  if (Test-Path -LiteralPath (Join-Path $Root 'Cargo.toml')) { return 'rust' }
  return 'generic'
}

function Test-AllowedOrigin([string]$Origin, [bool]$Explicit) {
  $Uri = $null
  if (-not [System.Uri]::TryCreate($Origin, [System.UriKind]::Absolute, [ref]$Uri)) { throw "Invalid allowed origin: $Origin" }
  if ($Uri.Scheme -notin @('http', 'https')) { throw "Allowed origin must use http or https: $Origin" }
  if (-not [string]::IsNullOrEmpty($Uri.UserInfo)) { throw "Allowed origin must not include credentials: $Origin" }
  if (-not [string]::IsNullOrEmpty($Uri.Fragment)) { throw "Allowed origin must not include a fragment: $Origin" }
  if ($Uri.Host -like '*`**') { throw "Allowed origin must not include a wildcard hostname: $Origin" }
  if (-not $Explicit -and $Uri.Host -notin @('localhost', '127.0.0.1')) { throw "Default origin must not be external: $Origin" }
  if ($Explicit -and $Uri.Host -notin @('localhost', '127.0.0.1') -and -not $Uri.Host.EndsWith('.local')) {
    Write-Warning "Explicit non-local allowed origin configured: $($Uri.GetLeftPart([UriPartial]::Authority))"
  }
  if ($Uri.HostNameType -eq [UriHostNameType]::IPv6) {
    $HostText = ([Net.IPAddress]::Parse($Uri.Host)).ToString()
    $PortText = if ($Uri.IsDefaultPort) { '' } else { ":$($Uri.Port)" }
    return "$($Uri.Scheme)://[$HostText]$PortText"
  }
  return $Uri.GetLeftPart([UriPartial]::Authority).TrimEnd('/')
}

function Get-TextSha256([string]$Text) {
  $Sha = [System.Security.Cryptography.SHA256]::Create()
  try { return -join ($Sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') }) }
  finally { $Sha.Dispose() }
}

function Get-EffectivePlanItemSha256([object]$PlanItem, [string]$RelativePath = '<plan item>') {
  return Get-TextSha256 (Get-EffectivePlanItemContent $PlanItem $RelativePath)
}

function Get-FileSha256([string]$Path) {
  $Stream = [System.IO.File]::Open($Path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
  $Sha = [System.Security.Cryptography.SHA256]::Create()
  try { return -join ($Sha.ComputeHash($Stream) | ForEach-Object { $_.ToString('x2') }) }
  finally { $Sha.Dispose(); $Stream.Dispose() }
}

function Read-TextFile([string]$Path) {
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Write-ExactTextFile([string]$Path, [string]$Content) {
  $Parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $Parent)) { New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
  $Temporary = "$Path.qbit-tmp-$([Guid]::NewGuid().ToString('N'))"
  try {
    [System.IO.File]::WriteAllText($Temporary, $Content, $Utf8NoBom)
    $Stream = [System.IO.File]::Open($Temporary,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
    try { $Stream.Flush($true) } finally { $Stream.Dispose() }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      try {
        [System.IO.File]::Replace($Temporary,$Path,$null)
      } catch {
        Move-Item -LiteralPath $Temporary -Destination $Path -Force
      }
    } else {
      [System.IO.File]::Move($Temporary,$Path)
    }
  } finally {
    if (Test-Path -LiteralPath $Temporary -PathType Leaf) { Remove-Item -LiteralPath $Temporary -Force }
  }
}

function Get-PlanItemWriteMode([object]$PlanItem, [string]$RelativePath = '<plan item>') {
  $HasWriteMode = $false
  $WriteMode = $null
  if ($PlanItem -is [System.Collections.IDictionary]) {
    $HasWriteMode = $PlanItem.Contains('WriteMode')
    if ($HasWriteMode) { $WriteMode = [string]$PlanItem['WriteMode'] }
  } elseif ($PlanItem -and ($PlanItem.PSObject.Properties.Name -contains 'WriteMode')) {
    $HasWriteMode = $true
    $WriteMode = [string]$PlanItem.WriteMode
  }
  if (-not $HasWriteMode) {
    throw "Plan item for $RelativePath is missing WriteMode."
  }
  if ($WriteMode -cnotin @($WriteModeCanonicalWithTerminalLf, $WriteModeCanonicalExact)) {
    throw "Plan item for $RelativePath has invalid WriteMode: $WriteMode"
  }
  return $WriteMode
}

function Get-EffectivePlanItemContent([object]$PlanItem, [string]$RelativePath = '<plan item>') {
  $WriteMode = Get-PlanItemWriteMode $PlanItem $RelativePath
  $HasContent = $false
  $Content = $null
  if ($PlanItem -is [System.Collections.IDictionary]) {
    $HasContent = $PlanItem.Contains('Content')
    if ($HasContent) { $Content = [string]$PlanItem['Content'] }
  } elseif ($PlanItem -and ($PlanItem.PSObject.Properties.Name -contains 'Content')) {
    $HasContent = $true
    $Content = [string]$PlanItem.Content
  }
  if (-not $HasContent) { throw "Plan item for $RelativePath is missing Content." }
  $Effective = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
  if ($WriteMode -ceq $WriteModeCanonicalWithTerminalLf -and -not $Effective.EndsWith("`n")) { $Effective += "`n" }
  return $Effective
}

function Write-PlanItemText([string]$Path, [object]$PlanItem, [string]$RelativePath = '<plan item>') {
  Write-ExactTextFile $Path (Get-EffectivePlanItemContent $PlanItem $RelativePath)
}

function Test-PlanItemContentMatchesFile([string]$Path, [object]$PlanItem, [string]$RelativePath = '<plan item>') {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  return (Get-FileSha256 $Path) -ceq (Get-EffectivePlanItemSha256 $PlanItem $RelativePath)
}

function Test-PlanItemLogicalTextMatchesFile([string]$Path, [object]$PlanItem, [string]$RelativePath = '<plan item>') {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  return (Read-TextFile $Path) -ceq (Get-EffectivePlanItemContent $PlanItem $RelativePath)
}

function Get-RelativePath([string]$Base, [string]$Path) {
  $Method = [System.IO.Path].GetMethod('GetRelativePath',[type[]]@([string],[string]))
  if ($Method) { return $Method.Invoke($null,@($Base,$Path)).Replace('\','/') }
  $BasePath = ConvertTo-CanonicalPath $Base
  if (-not $BasePath.EndsWith([IO.Path]::DirectorySeparatorChar)) { $BasePath += [IO.Path]::DirectorySeparatorChar }
  $BaseUri = New-Object Uri($BasePath)
  $PathUri = New-Object Uri((ConvertTo-CanonicalPath $Path))
  return [Uri]::UnescapeDataString($BaseUri.MakeRelativeUri($PathUri).ToString()).Replace('\','/')
}

function Sort-QbitPaths([string[]]$Paths) {
  $Sorted = [string[]]@($Paths)
  [Array]::Sort($Sorted, [StringComparer]::Ordinal)
  return @($Sorted)
}

function Join-UnderRoot([string]$Root, [string]$RelativePath) {
  if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|/)\.\.(/|$)') { throw "Unsafe relative path: $RelativePath" }
  $Full = ConvertTo-CanonicalPath (Join-Path $Root $RelativePath)
  $Prefix = (ConvertTo-CanonicalPath $Root) + [System.IO.Path]::DirectorySeparatorChar
  if (-not ($Full + [System.IO.Path]::DirectorySeparatorChar).StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $Full -ine (ConvertTo-CanonicalPath $Root)) {
    throw "Path escapes target root: $RelativePath"
  }
  return $Full
}

function Assert-SafeDestinationPath([string]$Root, [string]$RelativePath) {
  if (-not (Test-SafeStateRelativePath $RelativePath)) { throw "Unsafe target path: $RelativePath" }
  $Current = ConvertTo-CanonicalPath $Root
  $Components = $RelativePath.Replace('\','/').Split('/')
  for ($Index = 0; $Index -lt $Components.Count; $Index++) {
    $Current = Join-Path $Current $Components[$Index]
    if (-not (Test-Path -LiteralPath $Current)) { continue }
    $Item = Get-Item -LiteralPath $Current -Force
    if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unsafe reparse-point target path: $RelativePath" }
    if ($Index -lt $Components.Count - 1 -and -not $Item.PSIsContainer) { throw "Unsafe non-directory target parent: $RelativePath" }
    if ($Index -eq $Components.Count - 1 -and -not ($Item.PSIsContainer -or $Item -is [IO.FileInfo])) { throw "Unsafe target object type: $RelativePath" }
  }
}

function Test-SafeStateRelativePath([string]$RelativePath) {
  if ([string]::IsNullOrEmpty($RelativePath) -or $RelativePath -cnotmatch '^[A-Za-z0-9._/-]+$' -or [System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains('\') -or $RelativePath.Contains('|')) { return $false }
  foreach ($Segment in $RelativePath.Split('/')) {
    if ([string]::IsNullOrEmpty($Segment) -or $Segment -in @('.', '..') -or $Segment.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { return $false }
  }
  return $true
}

function Test-ProjectDisplayName([string]$DisplayName) {
  foreach ($Character in $DisplayName.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($Character) -eq [Globalization.UnicodeCategory]::Control) {
      throw 'ProjectDisplayName must not contain control characters.'
    }
  }
  return $DisplayName
}

function ConvertTo-JsonStringContent([string]$Value) {
  $Json = ConvertTo-Json -InputObject $Value -Compress
  return $Json.Substring(1, $Json.Length - 2)
}

function Get-TemplateSourceMap([string]$InstallerRoot, [string]$SelectedProfile) {
  if ($SelectedProfile -cnotin @('generic', 'typescript', 'rust')) { throw "Invalid state profile: $SelectedProfile" }
  $Map = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  $CaseMap = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($TemplateRoot in @((Join-Path $InstallerRoot 'templates/common'), (Join-Path $InstallerRoot "templates/profiles/$SelectedProfile"))) {
    if (-not (Test-Path -LiteralPath $TemplateRoot -PathType Container)) { throw "Missing template root: $TemplateRoot" }
    $SeenInRoot = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($File in @(Get-ChildItem -LiteralPath $TemplateRoot -Recurse -File -Force | Sort-Object FullName)) {
      $RelativePath = Get-RelativePath $TemplateRoot $File.FullName
      if ($RelativePath -eq 'README.md') { continue }
      if ($RelativePath.EndsWith('.tpl')) { $RelativePath = $RelativePath.Substring(0, $RelativePath.Length - 4) }
      if (-not (Test-SafeStateRelativePath $RelativePath)) { throw "Unsafe template destination: $RelativePath" }
      if (-not $SeenInRoot.Add($RelativePath)) { throw "Ambiguous duplicate template destination: $RelativePath" }
      if ($CaseMap.ContainsKey($RelativePath) -and $CaseMap[$RelativePath] -cne $RelativePath) { throw "Ambiguous case-fold template destination collision: $($CaseMap[$RelativePath]) and $RelativePath" }
      $CaseMap[$RelativePath] = $RelativePath
      $Map[$RelativePath] = $File.FullName
    }
  }
  return $Map
}

function Get-ExpectedManagedPaths([string]$InstallerRoot, [string]$SelectedProfile) {
  return @(Sort-QbitPaths @((Get-TemplateSourceMap $InstallerRoot $SelectedProfile).Keys))
}

function Get-ExpectedInstalledPaths([string]$InstallerRoot, [string]$SelectedProfile) {
  return @(Sort-QbitPaths (@(Get-ExpectedManagedPaths $InstallerRoot $SelectedProfile) + @('.gitignore', '.gitattributes', 'AGENTS.md', $StatePath)))
}

function Assert-ExactStringSet([string[]]$Actual, [string[]]$Expected, [string]$Name) {
  if ($Actual.Count -ne $Expected.Count) { throw "$Name does not match the expected profile manifest." }
  $ExpectedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($Path in $Expected) { if (-not $ExpectedSet.Add($Path)) { throw "$Name expected manifest contains a duplicate path: $Path" } }
  $ActualSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($Path in $Actual) {
    if (-not $ActualSet.Add($Path) -or -not $ExpectedSet.Contains($Path)) { throw "$Name does not match the expected profile manifest." }
  }
}

function Read-ValidatedInstallerState([string]$Path) {
  $Raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  try {
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Raw)
    $Reader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader(
      $Bytes,
      [System.Xml.XmlDictionaryReaderQuotas]::Max
    )
    try {
      $Xml = New-Object System.Xml.XmlDocument
      $Xml.Load($Reader)
    } finally {
      $Reader.Dispose()
    }
    if ($Xml.DocumentElement.GetAttribute('type') -cne 'object') { throw 'State root must be an object.' }
    function Assert-NoDuplicateJsonProperties([System.Xml.XmlElement]$Element) {
      if ($Element.GetAttribute('type') -ceq 'object') {
        $Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($Child in @($Element.ChildNodes | Where-Object NodeType -EQ ([System.Xml.XmlNodeType]::Element))) {
          $Name = if ($Child.HasAttribute('item')) { $Child.GetAttribute('item') } else { [System.Xml.XmlConvert]::DecodeName($Child.LocalName) }
          if (-not $Seen.Add($Name)) { throw "JSON object contains a duplicate property: $Name" }
          Assert-NoDuplicateJsonProperties $Child
        }
      } elseif ($Element.GetAttribute('type') -ceq 'array') {
        foreach ($Child in @($Element.ChildNodes | Where-Object NodeType -EQ ([System.Xml.XmlNodeType]::Element))) {
          Assert-NoDuplicateJsonProperties $Child
        }
      }
    }
    Assert-NoDuplicateJsonProperties $Xml.DocumentElement
    $ConvertFromJsonCommand = Get-Command ConvertFrom-Json
    $State = if ($ConvertFromJsonCommand.Parameters.ContainsKey('DateKind')) {
      $Raw | ConvertFrom-Json -DateKind String
    } else {
      $Raw | ConvertFrom-Json
    }
    $TopProperties = @($State.PSObject.Properties)
    $RequiredTopProperties = @('schemaVersion', 'installerId', 'installerVersion', 'toolkitSchemaVersion', 'profile', 'projectSlug', 'projectDisplayName', 'allowedOrigins', 'dockerImageName', 'installedAtUtc', 'installedRelativePaths', 'managedFiles', 'managedBlocks', 'stateFile')
    $RequiredTopSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($RequiredProperty in $RequiredTopProperties) { $null = $RequiredTopSet.Add($RequiredProperty) }
    foreach ($RequiredProperty in $RequiredTopProperties) {
      if (@($TopProperties | Where-Object Name -CEQ $RequiredProperty).Count -ne 1) { throw "State must contain exactly one $RequiredProperty property." }
    }
    if (@($TopProperties | Where-Object { -not $RequiredTopSet.Contains($_.Name) }).Count -ne 0) { throw 'State contains an unexpected top-level property.' }
    function Get-StateProperty([string]$Name) {
      $Property = @($TopProperties | Where-Object Name -CEQ $Name)[0]
      return ,($Property.Value)
    }
    function Assert-StateString([string]$Name, [object]$Expected = $null) {
      $Value = Get-StateProperty $Name
      if ($Value -isnot [string]) { throw "$Name must be a JSON string." }
      $Text = [string]$Value
      if ($null -ne $Expected -and $Text -cne [string]$Expected) { throw "$Name is invalid." }
      return $Text
    }
    $null = Assert-StateString 'schemaVersion' '1.0'
    $null = Assert-StateString 'installerId' $InstallerId
    $StateInstallerVersion = Assert-StateString 'installerVersion'
    if ($StateInstallerVersion -cnotin @('1.0.0', $InstallerVersion)) { throw 'installerVersion is invalid.' }
    $null = Assert-StateString 'toolkitSchemaVersion' '1.0'
    $Profile = Assert-StateString 'profile'
    if ($Profile -cnotin @('generic', 'typescript', 'rust')) { throw 'profile is invalid.' }
    $Slug = Assert-StateString 'projectSlug'
    if ($Slug.Length -gt 50 -or $Slug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'projectSlug is invalid.' }
    $null = Test-ProjectDisplayName (Assert-StateString 'projectDisplayName')
    $null = Assert-StateString 'dockerImageName'
    $InstalledAt = Assert-StateString 'installedAtUtc'
    if ($InstalledAt -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') { throw 'installedAtUtc is invalid.' }
    $ParsedInstalledAt = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($InstalledAt, 'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$ParsedInstalledAt)) { throw 'installedAtUtc is invalid.' }
    $null = Assert-StateString 'stateFile' $StatePath

    $OriginsElement = Get-StateProperty 'allowedOrigins'
    if ($OriginsElement -isnot [System.Array]) { throw 'allowedOrigins must be an array.' }
    $SeenOrigins = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($OriginElement in $OriginsElement) {
      if ($OriginElement -isnot [string]) { throw 'allowedOrigins entries must be strings.' }
      $Origin = [string]$OriginElement
      if ((Test-AllowedOrigin $Origin $true) -cne $Origin -or -not $SeenOrigins.Add($Origin)) { throw "Invalid or duplicate allowed origin: $Origin" }
    }
    if ($SeenOrigins.Count -eq 0) { throw 'allowedOrigins must not be empty.' }

    $InstalledElement = Get-StateProperty 'installedRelativePaths'
    if ($InstalledElement -isnot [System.Array]) { throw 'installedRelativePaths must be an array.' }
    $InstalledPaths = [Collections.Generic.List[string]]::new()
    $SeenInstalled = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($PathElement in $InstalledElement) {
      if ($PathElement -isnot [string]) { throw 'installedRelativePaths entries must be strings.' }
      $Rel = [string]$PathElement
      if (-not (Test-SafeStateRelativePath $Rel) -or -not $SeenInstalled.Add($Rel)) { throw "Unsafe or duplicate installedRelativePaths entry: $Rel" }
      $InstalledPaths.Add($Rel)
    }
    $ManagedFilesProperties = @($TopProperties | Where-Object Name -CEQ 'managedFiles')
    $ManagedBlocksProperties = @($TopProperties | Where-Object Name -CEQ 'managedBlocks')
    if ($ManagedFilesProperties.Count -ne 1) { throw 'State must contain exactly one managedFiles section.' }
    if ($ManagedBlocksProperties.Count -ne 1) { throw 'State must contain exactly one managedBlocks section.' }
    if ($ManagedFilesProperties[0].Value -isnot [pscustomobject]) { throw 'managedFiles must be an object.' }
    if ($ManagedBlocksProperties[0].Value -isnot [pscustomobject]) { throw 'managedBlocks must be an object.' }

    $SeenFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($Property in $ManagedFilesProperties[0].Value.PSObject.Properties) {
      $Rel = $Property.Name
      if (-not (Test-SafeStateRelativePath $Rel)) { throw "Unsafe managed file path: $Rel" }
      if ($Rel -ceq 'AGENTS.md') { throw 'AGENTS.md must not be whole-file managed.' }
      if (-not $SeenFiles.Add($Rel)) { throw "Duplicate managed file path: $Rel" }
      if ($Property.Value -isnot [string] -or [string]$Property.Value -notmatch '^[0-9a-f]{64}$') { throw "Managed file state for $Rel has invalid sha256." }
    }

    $RequiredBlocks = @('.gitignore', '.gitattributes', 'AGENTS.md')
    $RequiredBlockSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($RequiredBlock in $RequiredBlocks) { $null = $RequiredBlockSet.Add($RequiredBlock) }
    $SeenBlocks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($Property in $ManagedBlocksProperties[0].Value.PSObject.Properties) {
      $Rel = $Property.Name
      if (-not (Test-SafeStateRelativePath $Rel)) { throw "Unsafe managed block path: $Rel" }
      if (-not $SeenBlocks.Add($Rel)) { throw "Duplicate managed block path: $Rel" }
      if (-not $RequiredBlockSet.Contains($Rel)) { throw "Unexpected managed block path: $Rel" }
      if ($Property.Value -isnot [pscustomobject]) { throw "Managed block state for $Rel must be an object." }
      $Fields = @($Property.Value.PSObject.Properties)
      foreach ($RequiredField in @('sha256', 'createdFile', 'insertedSeparatorLfCount')) {
        if (@($Fields | Where-Object Name -CEQ $RequiredField).Count -ne 1) { throw "Managed block state for $Rel must contain exactly one $RequiredField." }
      }
      $RequiredFieldSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($RequiredField in @('sha256', 'createdFile', 'insertedSeparatorLfCount')) { $null = $RequiredFieldSet.Add($RequiredField) }
      if (@($Fields | Where-Object { -not $RequiredFieldSet.Contains($_.Name) }).Count -ne 0) { throw "Managed block state for $Rel contains an unexpected field." }
      $ShaField = @($Fields | Where-Object Name -CEQ 'sha256')[0].Value
      $CreatedField = @($Fields | Where-Object Name -CEQ 'createdFile')[0].Value
      $SeparatorField = @($Fields | Where-Object Name -CEQ 'insertedSeparatorLfCount')[0].Value
      if ($ShaField -isnot [string] -or [string]$ShaField -notmatch '^[0-9a-f]{64}$') { throw "Managed block state for $Rel has invalid sha256." }
      if ($CreatedField -isnot [bool]) { throw "Managed block state for $Rel has invalid createdFile." }
      $SeparatorHasValidType = (($SeparatorField -is [System.Int32]) -or ($SeparatorField -is [System.Int64]))
      $SeparatorHasValidValue = $false
      if ($SeparatorHasValidType) { $SeparatorHasValidValue = (($SeparatorField -ge 0) -and ($SeparatorField -le 2)) }
      if ((-not $SeparatorHasValidType) -or (-not $SeparatorHasValidValue)) { throw "Managed block state for $Rel has invalid insertedSeparatorLfCount." }
    }
    foreach ($RequiredBlock in $RequiredBlocks) {
      if (-not $SeenBlocks.Contains($RequiredBlock)) { throw "State is missing required managed block: $RequiredBlock" }
    }
    $ExpectedInstalled = @(Sort-QbitPaths (@($SeenFiles) + @($SeenBlocks) + @($StatePath)))
    Assert-ExactStringSet @($InstalledPaths) $ExpectedInstalled 'installedRelativePaths'
    if (($InstalledPaths -join "`n") -cne ($ExpectedInstalled -join "`n")) { throw 'installedRelativePaths is not in deterministic ordinal order.' }
  } catch {
    throw "State ownership metadata is invalid: $($_.Exception.Message)"
  }
  return $State
}

function Assert-PortableOwnershipState([string]$Root, [object]$State) {
  $RelativePath = '.qbit-toolkit/codex-ai-tooling/manifest.json'
  $Property = @($State.managedFiles.PSObject.Properties | Where-Object Name -CEQ $RelativePath)
  if ($Property.Count -eq 0) { return }
  Assert-SafeDestinationPath $Root $RelativePath
  $Path = Join-UnderRoot $Root $RelativePath
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Portable ownership manifest is missing.' }
  if ((Get-FileSha256 $Path) -cne [string]$Property[0].Value) { throw 'Portable ownership manifest hash does not match compatibility ownership state.' }
  try { $Manifest = Read-TextFile $Path | ConvertFrom-Json } catch { throw 'Portable ownership manifest is invalid JSON.' }
  $ExpectedFiles = @(Sort-QbitPaths @($State.managedFiles.PSObject.Properties.Name | Where-Object { $_ -cne $RelativePath }))
  $ActualFiles = @(Sort-QbitPaths @($Manifest.installed_entries | ForEach-Object { [string]$_.relative_path }))
  Assert-ExactStringSet $ActualFiles $ExpectedFiles 'portable installed_entries'
  foreach ($Block in $Manifest.managed_blocks) {
    $StateBlock = @($State.managedBlocks.PSObject.Properties | Where-Object Name -CEQ ([string]$Block.relative_path))
    if ($StateBlock.Count -ne 1 -or [string]$StateBlock[0].Value.sha256 -cne [string]$Block.sha256) { throw "Portable managed block differs: $($Block.relative_path)" }
  }
  if (@($Manifest.managed_blocks).Count -ne @($State.managedBlocks.PSObject.Properties).Count) { throw 'Portable managed block count differs.' }
}

function Render-Template([string]$Text, [hashtable]$Values) {
  $Rendered = $Text
  foreach ($Key in $Values.Keys) { $Rendered = $Rendered.Replace(('{{' + $Key + '}}'), [string]$Values[$Key]) }
  return $Rendered
}

function Get-ManagedBlockText([string]$BlockBody, [string]$Begin = $BeginMarker, [string]$End = $EndMarker) {
  $Body = $BlockBody.Trim("`r", "`n")
  return "$Begin`n$Body`n$End`n"
}

function Get-ManagedBlockAnalysis([string]$Text, [string]$Begin = $BeginMarker, [string]$End = $EndMarker, [string]$Path = '<text>') {
  $Canonical = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
  $BeginRawCount = [regex]::Matches($Canonical, [regex]::Escape($Begin)).Count
  $EndRawCount = [regex]::Matches($Canonical, [regex]::Escape($End)).Count
  $BeginMatches = @([regex]::Matches($Canonical, '(?m)^' + [regex]::Escape($Begin) + '$'))
  $EndMatches = @([regex]::Matches($Canonical, '(?m)^' + [regex]::Escape($End) + '$'))
  if ($BeginRawCount -ne $BeginMatches.Count -or $EndRawCount -ne $EndMatches.Count) {
    throw "Managed block markers must appear only as exact complete lines in $Path."
  }
  if ($BeginMatches.Count -eq 0 -and $EndMatches.Count -eq 0) {
    return [pscustomobject]@{ Status = 'absent'; Prefix = $Canonical; Block = ''; Suffix = ''; StartIndex = -1; EndIndex = -1; HasTerminalLf = $false }
  }
  if ($BeginMatches.Count -eq 0) { throw "Managed block begin marker is missing in $Path." }
  if ($EndMatches.Count -eq 0) { throw "Managed block end marker is missing in $Path." }
  if ($BeginMatches.Count -gt 1) { throw "Managed block begin marker is duplicated in $Path." }
  if ($EndMatches.Count -gt 1) { throw "Managed block end marker is duplicated in $Path." }
  $BeginMatch = $BeginMatches[0]
  $EndMatch = $EndMatches[0]
  if ($EndMatch.Index -lt $BeginMatch.Index) { throw "Managed block markers are reversed in $Path." }
  $EndLineEnd = $EndMatch.Index + $EndMatch.Length
  $HasTerminalLf = $EndLineEnd -lt $Canonical.Length -and $Canonical[$EndLineEnd] -eq "`n"
  $SegmentEnd = if ($HasTerminalLf) { $EndLineEnd + 1 } else { $EndLineEnd }
  $Block = $Canonical.Substring($BeginMatch.Index, $SegmentEnd - $BeginMatch.Index)
  $CanonicalBlock = if ($Block.EndsWith("`n")) { $Block } else { $Block + "`n" }
  return [pscustomobject]@{
    Status = 'valid'
    Prefix = $Canonical.Substring(0, $BeginMatch.Index)
    Block = $CanonicalBlock
    Suffix = $Canonical.Substring($SegmentEnd)
    StartIndex = $BeginMatch.Index
    EndIndex = $SegmentEnd
    HasTerminalLf = $HasTerminalLf
  }
}

function Get-ManagedBlockSeparatorCount([string]$Existing) {
  if ([string]::IsNullOrEmpty($Existing)) { return 0 }
  if ($Existing.EndsWith("`n")) { return 1 }
  return 2
}

function New-ManagedBlockRecord([string]$BlockText, [bool]$CreatedFile, [int]$InsertedSeparatorLfCount) {
  if ($InsertedSeparatorLfCount -lt 0 -or $InsertedSeparatorLfCount -gt 2) { throw "Invalid managed-block separator count: $InsertedSeparatorLfCount" }
  return [ordered]@{
    sha256 = Get-TextSha256 $BlockText
    createdFile = $CreatedFile
    insertedSeparatorLfCount = $InsertedSeparatorLfCount
  }
}

function Get-ManagedBlockRecordValue([object]$PreviousState, [string]$RelativePath) {
  if ($PreviousState -and ($PreviousState.PSObject.Properties.Name -ccontains 'managedBlocks') -and $PreviousState.managedBlocks) {
    $Property = @($PreviousState.managedBlocks.PSObject.Properties | Where-Object Name -CEQ $RelativePath)[0]
    if ($Property) { return $Property.Value }
  }
  return $null
}

function ConvertTo-ManagedBlockRecord([object]$Record, [string]$RelativePath) {
  if (-not $Record) { return $null }
  foreach ($Required in @('sha256', 'createdFile', 'insertedSeparatorLfCount')) {
    if (-not ($Record.PSObject.Properties.Name -ccontains $Required)) { throw "Managed block state for $RelativePath is missing $Required." }
  }
  if ($Record.createdFile -isnot [bool]) { throw "Managed block state for $RelativePath has invalid createdFile." }
  $SeparatorCount = [int]$Record.insertedSeparatorLfCount
  if ($SeparatorCount -lt 0 -or $SeparatorCount -gt 2) { throw "Managed block state for $RelativePath has invalid separator count." }
  if ([string]$Record.sha256 -notmatch '^[0-9a-f]{64}$') { throw "Managed block state for $RelativePath has invalid sha256." }
  return [ordered]@{
    sha256 = [string]$Record.sha256
    createdFile = [bool]$Record.createdFile
    insertedSeparatorLfCount = $SeparatorCount
  }
}

function Resolve-ManagedBlockUpdate([string]$Existing, [bool]$FileExists, [string]$BlockBody, [string]$Begin = $BeginMarker, [string]$End = $EndMarker, [object]$PreviousRecord = $null, [string]$RelativePath = '<text>', [ValidateSet('fail','replace')] [string]$OwnedModifiedPolicy = 'fail') {
  $BlockText = Get-ManagedBlockText $BlockBody $Begin $End
  $Analysis = Get-ManagedBlockAnalysis $Existing $Begin $End $RelativePath
  if ($Analysis.Status -eq 'valid') {
    $Record = ConvertTo-ManagedBlockRecord $PreviousRecord $RelativePath
    if (-not $Record) { throw "Unowned managed markers exist in $RelativePath." }
    if ((Get-TextSha256 $Analysis.Block) -cne $Record.sha256 -and $OwnedModifiedPolicy -ne 'replace') { throw "Managed block was modified after installation: $RelativePath." }
    $Record.sha256 = Get-TextSha256 $BlockText
    return [pscustomobject]@{
      Content = $Analysis.Prefix + $BlockText + $Analysis.Suffix
      BlockText = $BlockText
      Record = $Record
      Analysis = $Analysis
    }
  }
  if ($PreviousRecord) { throw "Previously managed block is absent or malformed in $RelativePath." }
  $SeparatorCount = Get-ManagedBlockSeparatorCount $Existing
  $Separator = "`n" * $SeparatorCount
  $Content = $Existing + $Separator + $BlockText
  return [pscustomobject]@{
    Content = $Content
    BlockText = $BlockText
    Record = New-ManagedBlockRecord $BlockText (-not $FileExists) $SeparatorCount
    Analysis = $Analysis
  }
}

function Merge-ManagedBlock([string]$Existing, [string]$BlockBody, [string]$Begin = $BeginMarker, [string]$End = $EndMarker) {
  return (Resolve-ManagedBlockUpdate $Existing $true $BlockBody $Begin $End $null '<text>' 'fail').Content
}

function Remove-ManagedBlockFromText([string]$Text, [object]$Record, [string]$Begin = $BeginMarker, [string]$End = $EndMarker, [string]$RelativePath = '<text>', [switch]$ReplaceModifiedOwned) {
  $Analysis = Get-ManagedBlockAnalysis $Text $Begin $End $RelativePath
  if ($Analysis.Status -ne 'valid') { throw "Managed block is absent in $RelativePath." }
  $StateRecord = ConvertTo-ManagedBlockRecord $Record $RelativePath
  $ActualHash = Get-TextSha256 $Analysis.Block
  if ($ActualHash -ne $StateRecord.sha256 -and -not $ReplaceModifiedOwned) { throw "Managed block was modified after installation: $RelativePath. Use owned-modified=replace to back it up and remove it." }
  $SeparatorCount = [int]$StateRecord.insertedSeparatorLfCount
  if ($SeparatorCount -gt 0) {
    if ($Analysis.Prefix.Length -lt $SeparatorCount -or $Analysis.Prefix.Substring($Analysis.Prefix.Length - $SeparatorCount) -ne ("`n" * $SeparatorCount)) {
      if (-not $ReplaceModifiedOwned) { throw "Managed block separator metadata does not match $RelativePath." }
      return $Analysis.Prefix + $Analysis.Suffix
    }
    return $Analysis.Prefix.Substring(0, $Analysis.Prefix.Length - $SeparatorCount) + $Analysis.Suffix
  }
  return $Analysis.Prefix + $Analysis.Suffix
}

function Backup-ExistingPath([string]$Root, [string]$BackupRoot, [string]$RelativePath) {
  $Source = Join-UnderRoot $Root $RelativePath
  if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $null }
  $Destination = Join-UnderRoot $Root (Join-Path $BackupRoot $RelativePath)
  $Parent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $Parent)) { New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
  return $Destination
}

function Get-TemplatePlan([string]$InstallerRoot, [string]$SelectedProfile, [hashtable]$Values) {
  $Map = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
  $Sources = Get-TemplateSourceMap $InstallerRoot $SelectedProfile
  foreach ($RelativePath in @(Sort-QbitPaths @($Sources.Keys))) {
    $Map[$RelativePath] = [ordered]@{ RelativePath = $RelativePath; Content = (Render-Template (Read-TextFile $Sources[$RelativePath]) $Values); Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf }
  }
  return $Map
}

function ConvertTo-QbitPrettyJson([object]$Value, [int]$Depth = 10) {
  $Compact = [string]($Value | ConvertTo-Json -Depth $Depth -Compress)
  $Builder = [Text.StringBuilder]::new()
  $Indent = 0
  $InString = $false
  $Escaped = $false
  for ($Index = 0; $Index -lt $Compact.Length; $Index++) {
    $Character = $Compact[$Index]
    if ($InString) {
      $null = $Builder.Append($Character)
      if ($Escaped) { $Escaped = $false }
      elseif ($Character -eq '\') { $Escaped = $true }
      elseif ($Character -eq '"') { $InString = $false }
      continue
    }
    if ($Character -eq '"') { $InString = $true; $null = $Builder.Append($Character); continue }
    if ($Character -in @('{','[')) {
      $Closing = if ($Character -eq '{') { '}' } else { ']' }
      if ($Index + 1 -lt $Compact.Length -and $Compact[$Index + 1] -eq $Closing) {
        $null = $Builder.Append($Character).Append($Closing)
        $Index++
        continue
      }
      $Indent++
      $null = $Builder.Append($Character).Append("`n").Append(' ' * ($Indent * 2))
      continue
    }
    if ($Character -in @('}',']')) {
      $Indent--
      if ($Indent -lt 0) { throw 'ConvertTo-Json returned unbalanced JSON.' }
      $null = $Builder.Append("`n").Append(' ' * ($Indent * 2)).Append($Character)
      continue
    }
    if ($Character -eq ',') { $null = $Builder.Append(',').Append("`n").Append(' ' * ($Indent * 2)); continue }
    if ($Character -eq ':') { $null = $Builder.Append(': '); continue }
    if (-not [char]::IsWhiteSpace($Character)) { $null = $Builder.Append($Character) }
  }
  if ($InString -or $Indent -ne 0) { throw 'ConvertTo-Json returned incomplete JSON.' }
  return $Builder.ToString()
}

function New-StateContent([System.Collections.IDictionary]$Plan, [System.Collections.IDictionary]$BlockRecords, [object]$PreviousState, [string]$SelectedProfile, [string]$Slug, [string]$DisplayName, [string[]]$Origins, [string]$DockerImage) {
  $InstalledAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
  if ($PreviousState) { $InstalledAt = $PreviousState.installedAtUtc }
  $ManagedFiles = [ordered]@{}
  foreach ($RelativePath in (Sort-QbitPaths @($Plan.Keys))) {
    if ($Plan[$RelativePath].Kind -in @('merge', 'state', 'observed')) { continue }
    $ManagedFiles[$RelativePath] = Get-EffectivePlanItemSha256 $Plan[$RelativePath] $RelativePath
  }
  $Blocks = [ordered]@{}
  foreach ($Key in (Sort-QbitPaths @($BlockRecords.Keys))) { $Blocks[$Key] = $BlockRecords[$Key] }
  $InstalledPaths = @(Sort-QbitPaths (@($ManagedFiles.Keys) + @($Blocks.Keys) + @($StatePath)))
  $State = [ordered]@{
    schemaVersion = '1.0'
    installerId = $InstallerId
    installerVersion = $InstallerVersion
    toolkitSchemaVersion = '1.0'
    profile = $SelectedProfile
    projectSlug = $Slug
    projectDisplayName = $DisplayName
    allowedOrigins = $Origins
    dockerImageName = $DockerImage
    installedAtUtc = $InstalledAt
    installedRelativePaths = $InstalledPaths
    managedFiles = $ManagedFiles
    managedBlocks = $Blocks
    stateFile = $StatePath
  }
  return (ConvertTo-QbitPrettyJson $State 10) + "`n"
}

function New-PortableOwnershipManifest([System.Collections.IDictionary]$Plan, [System.Collections.IDictionary]$BlockRecords, [string]$SelectedProfile, [string]$Slug) {
  $ManifestPath = '.qbit-toolkit/codex-ai-tooling/manifest.json'
  $Entries = New-Object System.Collections.Generic.List[object]
  $OriginalRecords = New-Object System.Collections.Generic.List[object]
  $DigestLines = New-Object System.Text.StringBuilder
  foreach ($RelativePath in (Sort-QbitPaths @($Plan.Keys))) {
    if ($RelativePath -ceq $ManifestPath -or $Plan[$RelativePath].Kind -eq 'merge') { continue }
    $Hash = Get-EffectivePlanItemSha256 $Plan[$RelativePath] $RelativePath
    $null = $DigestLines.Append($RelativePath).Append("`t").Append($Hash).Append("`n")
    if ($Plan[$RelativePath].Kind -eq 'observed') {
      $OriginalRecords.Add([ordered]@{ relative_path=$RelativePath; ownership_type='observed-identical-unowned'; sha256=$Hash })
      continue
    }
    $Entries.Add([ordered]@{
      relative_path = $RelativePath
      object_type = 'file'
      ownership_type = 'installer-owned'
      expected_sha256 = $Hash
      installed_sha256 = $Hash
      payload_version = $InstallerVersion
      created_by_installer = $true
      adopted_identical_unowned = $false
      replaced_existing_owned = $false
      backup_reference = $null
      executable = $RelativePath.EndsWith('.sh',[StringComparison]::Ordinal)
      expected_text_encoding = 'utf-8'
      expected_line_endings = 'lf'
    })
  }
  $Blocks = New-Object System.Collections.Generic.List[object]
  foreach ($RelativePath in (Sort-QbitPaths @($BlockRecords.Keys))) {
    $Hash = [string]$BlockRecords[$RelativePath].sha256
    $null = $DigestLines.Append($RelativePath).Append("`t").Append($Hash).Append("`n")
    $Blocks.Add([ordered]@{ relative_path = $RelativePath; sha256 = $Hash })
  }
  $Value = [ordered]@{
    schema_version = '1.0'
    installer_version = $InstallerVersion
    profile = $SelectedProfile
    target_identity = $Slug
    payload_manifest_sha256 = Get-TextSha256 $DigestLines.ToString()
    installed_entries = $Entries.ToArray()
    managed_blocks = $Blocks.ToArray()
    generated_state_entries = @('backups','lock.json','recovery','transactions')
    original_state_records = $OriginalRecords.ToArray()
    last_successful_operation = if ($env:QBIT_TOOLKIT_OPERATION) { $env:QBIT_TOOLKIT_OPERATION } else { 'install' }
  }
  return (ConvertTo-QbitPrettyJson $Value 10) + "`n"
}

function ConvertTo-QbitCanonicalJson([object]$Value) {
  if ($null -eq $Value) { return 'null' }
  if ($Value -is [string] -or $Value.GetType().IsPrimitive) { return ($Value | ConvertTo-Json -Compress) }
  if ($Value -is [datetime]) { return ($Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) | ConvertTo-Json -Compress) }
  if ($Value -is [System.Collections.IDictionary]) {
    $Parts = @()
    foreach ($Key in (Sort-QbitPaths @($Value.Keys))) {
      $Parts += (($Key | ConvertTo-Json -Compress) + ':' + (ConvertTo-QbitCanonicalJson $Value[$Key]))
    }
    return '{' + ($Parts -join ',') + '}'
  }
  if ($Value -is [pscustomobject]) {
    $Parts = @()
    foreach ($Name in (Sort-QbitPaths @($Value.PSObject.Properties.Name))) {
      $Property = @($Value.PSObject.Properties | Where-Object Name -CEQ $Name)[0]
      $Parts += (($Property.Name | ConvertTo-Json -Compress) + ':' + (ConvertTo-QbitCanonicalJson $Property.Value))
    }
    return '{' + ($Parts -join ',') + '}'
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    $Parts = @()
    foreach ($Item in $Value) { $Parts += ConvertTo-QbitCanonicalJson $Item }
    return '[' + ($Parts -join ',') + ']'
  }
  $PropertyNames = @(Sort-QbitPaths @($Value.PSObject.Properties.Name))
  if ($PropertyNames.Count -gt 0) {
    $Parts = @()
    foreach ($Name in $PropertyNames) {
      $Property = @($Value.PSObject.Properties | Where-Object Name -CEQ $Name)[0]
      $Parts += (($Property.Name | ConvertTo-Json -Compress) + ':' + (ConvertTo-QbitCanonicalJson $Property.Value))
    }
    return '{' + ($Parts -join ',') + '}'
  }
  return ($Value | ConvertTo-Json -Compress)
}

function Test-StateContentEquivalent([string]$ExistingContent, [string]$DesiredContent) {
  try {
    $ExistingStateComparable = ConvertTo-QbitCanonicalJson ($ExistingContent | ConvertFrom-Json)
    $DesiredStateComparable = ConvertTo-QbitCanonicalJson ($DesiredContent | ConvertFrom-Json)
    return $ExistingStateComparable -ceq $DesiredStateComparable
  } catch {
    return $false
  }
}

function Remove-EmptyManagedParents([string]$Root, [string[]]$RelativePaths) {
  $RootPath = ConvertTo-CanonicalPath $Root
  $Candidates = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($RelativePath in $RelativePaths) {
    $Parent = Split-Path -Parent (Join-UnderRoot $Root $RelativePath)
    while ($Parent -and $Parent -ine $RootPath -and $Parent.StartsWith($RootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      $null = $Candidates.Add($Parent)
      $Parent = Split-Path -Parent $Parent
    }
  }
  foreach ($Directory in @($Candidates | Sort-Object Length -Descending)) {
    if ((Test-Path -LiteralPath $Directory -PathType Container) -and -not (Get-ChildItem -LiteralPath $Directory -Force)) { Remove-Item -LiteralPath $Directory -Force }
  }
}

function Set-TransactionJournalStatus([string]$JournalPath, [ValidateSet('committed','rolled_back','recovered')] [string]$Status) {
  $Raw = Read-TextFile $JournalPath
  $Pattern = '"status"\s*:\s*"active"'
  if ([regex]::Matches($Raw, $Pattern).Count -ne 1) { throw 'Transaction journal does not contain exactly one active status.' }
  $Updated = [regex]::Replace($Raw, $Pattern, ('"status": "' + $Status + '"'))
  Write-ExactTextFile $JournalPath $Updated
}

function Invoke-PendingTransactionRecovery([string]$Root) {
  $RuntimeRoot = Join-UnderRoot $Root '.qbit-toolkit/codex-ai-tooling'
  if (-not (Test-Path -LiteralPath $RuntimeRoot -PathType Container)) { return }
  $TransactionsRoot = Join-Path $RuntimeRoot 'transactions'
  $RecoveryRoot = Join-Path $RuntimeRoot 'recovery'
  $BackupsRoot = Join-Path $RuntimeRoot 'backups'
  $LockPath = Join-Path $RuntimeRoot 'lock.json'
  $ActiveTransactions = @()
  if (Test-Path -LiteralPath $TransactionsRoot -PathType Container) {
    foreach ($Transaction in @(Get-ChildItem -LiteralPath $TransactionsRoot -Directory -ErrorAction SilentlyContinue)) {
      $Journal = Join-Path $Transaction.FullName 'journal.json'
      if (-not (Test-Path -LiteralPath $Journal -PathType Leaf)) { continue }
      try { $Record = Read-TextFile $Journal | ConvertFrom-Json } catch { throw "Recovery journal is malformed: $($Transaction.Name)" }
      if ([string]$Record.status -ceq 'active') { $ActiveTransactions += $Transaction }
    }
  }
  if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf) -and $ActiveTransactions.Count -eq 0) { return }
  if (-not (Test-Path -LiteralPath $RecoveryRoot -PathType Container)) { New-Item -ItemType Directory -Path $RecoveryRoot -Force | Out-Null }
  if (Test-Path -LiteralPath $LockPath -PathType Leaf) {
    try { $ExistingLock = Read-TextFile $LockPath | ConvertFrom-Json } catch { throw 'Uncertain installer lock is malformed.' }
    $SameHost = [string]$ExistingLock.host_identity -ceq [Environment]::MachineName
    $ExistingProcess = if ($SameHost) { Get-Process -Id ([int]$ExistingLock.process_id) -ErrorAction SilentlyContinue } else { $null }
    if (-not $SameHost -or $ExistingProcess) { throw 'Active installer lock or uncertain cross-host lock detected.' }
    $StaleName = "stale-lock-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture))-$PID.json"
    Move-Item -LiteralPath $LockPath -Destination (Join-Path $RecoveryRoot $StaleName)
  }
  foreach ($Transaction in $ActiveTransactions) {
    $Journal = Join-Path $Transaction.FullName 'journal.json'
    $CandidateBackup = Join-Path $BackupsRoot $Transaction.Name
    $BackedFile = Join-Path $Transaction.FullName 'backed'
    $CreatedFile = Join-Path $Transaction.FullName 'created'
    if (Test-Path -LiteralPath $BackedFile -PathType Leaf) {
      foreach ($RelativePath in @(Get-Content -LiteralPath $BackedFile)) {
        if (-not $RelativePath) { continue }
        $Source = Join-Path $CandidateBackup $RelativePath
        $Destination = Join-UnderRoot $Root $RelativePath
        $Parent = Split-Path -Parent $Destination
        if (-not (Test-Path -LiteralPath $Parent -PathType Container)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
      }
    }
    if (Test-Path -LiteralPath $CreatedFile -PathType Leaf) {
      foreach ($RelativePath in @(Get-Content -LiteralPath $CreatedFile)) {
        if (-not $RelativePath) { continue }
        $Destination = Join-UnderRoot $Root $RelativePath
        if (Test-Path -LiteralPath $Destination -PathType Leaf) { Remove-Item -LiteralPath $Destination -Force }
      }
    }
    Set-TransactionJournalStatus $Journal 'recovered'
  }
}

function Invoke-TransactionalWrite([string]$Root, [System.Collections.IDictionary]$Plan, [string[]]$RemovePaths = @(), [string]$StateRelativePath = '', [switch]$DryRun) {
  $EffectiveContents = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  foreach ($RelativePath in $Plan.Keys) { $EffectiveContents[$RelativePath] = Get-EffectivePlanItemContent $Plan[$RelativePath] $RelativePath }
  foreach ($RelativePath in $RemovePaths) {
    if ($Plan.ContainsKey($RelativePath)) { throw "Transaction path is both written and removed: $RelativePath" }
    $null = Join-UnderRoot $Root $RelativePath
  }
  if ($StateRelativePath -and -not $Plan.ContainsKey($StateRelativePath)) { throw "State plan item is missing: $StateRelativePath" }
  $NonStateWrites = @(Sort-QbitPaths @($Plan.Keys | Where-Object { $_ -cne $StateRelativePath }))
  $Timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture) + "-$PID"
  $BackupRoot = ".qbit-toolkit/codex-ai-tooling/backups/$Timestamp"
  $Backups = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  $RemoveSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($RelativePath in $RemovePaths) {
    if (-not $RemoveSet.Add($RelativePath)) { throw "Duplicate transaction removal path: $RelativePath" }
  }
  $Created = New-Object System.Collections.Generic.List[string]
  $BackupRootCreated = $false
  $LockAcquired = $false
  $LockPath = $null
  $JournalPath = $null
  try {
    foreach ($RelativePath in @($Plan.Keys) + @($RemovePaths)) {
      $Destination = Join-UnderRoot $Root $RelativePath
      if (Test-Path -LiteralPath $Destination -PathType Container) { throw "Cannot overwrite directory: $RelativePath" }
      if ($RemoveSet.Contains($RelativePath) -and -not (Test-Path -LiteralPath $Destination -PathType Leaf)) { throw "Cannot remove missing or non-regular transaction path: $RelativePath" }
    }
    if ($DryRun) { return }
    $RuntimeRoot = Join-UnderRoot $Root '.qbit-toolkit/codex-ai-tooling'
    $TransactionsRoot = Join-Path $RuntimeRoot 'transactions'
    $RecoveryRoot = Join-Path $RuntimeRoot 'recovery'
    foreach ($Directory in @($RuntimeRoot,$TransactionsRoot,(Join-Path $RuntimeRoot 'backups'),$RecoveryRoot)) {
      if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    }
    $LockPath = Join-Path $RuntimeRoot 'lock.json'
    if (Test-Path -LiteralPath $LockPath -PathType Leaf) {
      try { $ExistingLock = Read-TextFile $LockPath | ConvertFrom-Json } catch { throw 'Uncertain installer lock is malformed.' }
      $SameHost = [string]$ExistingLock.host_identity -ceq [Environment]::MachineName
      $ExistingProcess = if ($SameHost) { Get-Process -Id ([int]$ExistingLock.process_id) -ErrorAction SilentlyContinue } else { $null }
      if (-not $SameHost -or $ExistingProcess) { throw 'Active installer lock or uncertain cross-host lock detected.' }
      $StaleName = "stale-lock-$Timestamp.json"
      Move-Item -LiteralPath $LockPath -Destination (Join-Path $RecoveryRoot $StaleName)
    }
    foreach ($Transaction in @(Get-ChildItem -LiteralPath $TransactionsRoot -Directory -ErrorAction SilentlyContinue)) {
      $CandidateJournal = Join-Path $Transaction.FullName 'journal.json'
      if (-not (Test-Path -LiteralPath $CandidateJournal -PathType Leaf)) { continue }
      try { $Candidate = Read-TextFile $CandidateJournal | ConvertFrom-Json } catch { throw "Recovery journal is malformed: $($Transaction.Name)" }
      if ([string]$Candidate.status -cne 'active') { continue }
      $CandidateBackup = Join-Path (Join-Path $RuntimeRoot 'backups') $Transaction.Name
      $BackedFile = Join-Path $Transaction.FullName 'backed'
      $CreatedFile = Join-Path $Transaction.FullName 'created'
      if (Test-Path -LiteralPath $BackedFile -PathType Leaf) {
        foreach ($RelativePath in @(Get-Content -LiteralPath $BackedFile)) {
          if (-not $RelativePath) { continue }
          $Source = Join-Path $CandidateBackup $RelativePath
          $Destination = Join-UnderRoot $Root $RelativePath
          $Parent = Split-Path -Parent $Destination
          if (-not (Test-Path -LiteralPath $Parent -PathType Container)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
          Copy-Item -LiteralPath $Source -Destination $Destination -Force
        }
      }
      if (Test-Path -LiteralPath $CreatedFile -PathType Leaf) {
        foreach ($RelativePath in @(Get-Content -LiteralPath $CreatedFile)) {
          if (-not $RelativePath) { continue }
          $Destination = Join-UnderRoot $Root $RelativePath
          if (Test-Path -LiteralPath $Destination -PathType Leaf) { Remove-Item -LiteralPath $Destination -Force }
        }
      }
      Write-ExactTextFile $CandidateJournal ((Read-TextFile $CandidateJournal).Replace('"status": "active"','"status": "recovered"'))
    }
    $LockStream = $null
    try {
      $LockStream = [IO.File]::Open($LockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      $LockContent = [ordered]@{
        schema_version = '1.0'
        operation = if ($env:QBIT_TOOLKIT_OPERATION) { $env:QBIT_TOOLKIT_OPERATION } else { 'install' }
        process_id = $PID
        host_identity = [Environment]::MachineName
        start_time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
        transaction_id = $Timestamp
      } | ConvertTo-Json
      $LockBytes = New-Object Text.UTF8Encoding($false)
      $LockData = $LockBytes.GetBytes($LockContent + "`n")
      $LockStream.Write($LockData,0,$LockData.Length)
      $LockStream.Flush($true)
      $LockStream.Dispose()
      $LockAcquired = $true
    } catch {
      if ($LockStream) { $LockStream.Dispose() }
      throw 'Active installer lock detected.'
    }
    $TransactionDirectory = Join-Path $TransactionsRoot $Timestamp
    New-Item -ItemType Directory -Path $TransactionDirectory -Force | Out-Null
    $JournalPath = Join-Path $TransactionDirectory 'journal.json'
    $Journal = [ordered]@{
      schema_version = '1.0'
      transaction_id = $Timestamp
      operation = if ($env:QBIT_TOOLKIT_OPERATION) { $env:QBIT_TOOLKIT_OPERATION } else { 'install' }
      status = 'active'
    } | ConvertTo-Json
    Write-ExactTextFile $JournalPath ($Journal + "`n")
    $BackedLog = Join-Path $TransactionDirectory 'backed'
    $CreatedLog = Join-Path $TransactionDirectory 'created'
    Write-ExactTextFile $BackedLog ''
    Write-ExactTextFile $CreatedLog ''
    foreach ($RelativePath in @($Plan.Keys) + @($RemovePaths)) {
      $Destination = Join-UnderRoot $Root $RelativePath
      if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        $Backups[$RelativePath] = Backup-ExistingPath $Root $BackupRoot $RelativePath
        $BackupRootCreated = $true
        Add-Content -LiteralPath $BackedLog -Value $RelativePath -Encoding UTF8
      } elseif ($Plan.ContainsKey($RelativePath)) {
        $Created.Add($RelativePath)
        Add-Content -LiteralPath $CreatedLog -Value $RelativePath -Encoding UTF8
      }
    }
    foreach ($RelativePath in $NonStateWrites) {
      $Destination = Join-UnderRoot $Root $RelativePath
      Write-ExactTextFile $Destination $EffectiveContents[$RelativePath]
    }
    foreach ($RelativePath in @(Sort-QbitPaths $RemovePaths)) {
      $Destination = Join-UnderRoot $Root $RelativePath
      Remove-Item -LiteralPath $Destination -Force
    }
    if ($env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES) { throw 'Injected installer failure after non-state writes and stale removals.' }
    if ($StateRelativePath) {
      $Destination = Join-UnderRoot $Root $StateRelativePath
      Write-ExactTextFile $Destination $EffectiveContents[$StateRelativePath]
    }
    if ($RemovePaths.Count -gt 0) { Remove-EmptyManagedParents $Root $RemovePaths }
    Set-TransactionJournalStatus $JournalPath 'committed'
    Remove-Item -LiteralPath $LockPath -Force
    $LockAcquired = $false
  } catch {
    $Cause = $_.Exception.Message
    if (-not $LockAcquired) { throw $Cause }
    $RollbackErrors = @()
    if ($env:QBIT_TOOLKIT_TEST_FAIL_ROLLBACK) { $RollbackErrors += 'injected rollback failure' }
    if ($RollbackErrors.Count -gt 0) { throw "Installation failed; rollback had errors: $($RollbackErrors -join '; '). Recovery is required." }
    foreach ($RelativePath in $Backups.Keys) {
      try { Copy-Item -LiteralPath $Backups[$RelativePath] -Destination (Join-UnderRoot $Root $RelativePath) -Force } catch { $RollbackErrors += "${RelativePath}: $($_.Exception.Message)" }
    }
    foreach ($RelativePath in $Created) {
      try { $Path = Join-UnderRoot $Root $RelativePath; if (Test-Path -LiteralPath $Path -PathType Leaf) { Remove-Item -LiteralPath $Path -Force } } catch { $RollbackErrors += "${RelativePath}: $($_.Exception.Message)" }
    }
    try { Remove-EmptyManagedParents $Root @($Created) } catch { $RollbackErrors += "created-path cleanup: $($_.Exception.Message)" }
    if ($BackupRootCreated) {
      # Retain backups as transaction evidence.
    }
    if ($JournalPath) {
      try { Set-TransactionJournalStatus $JournalPath 'rolled_back' } catch { $RollbackErrors += "journal update: $($_.Exception.Message)" }
    }
    try { if ($LockPath -and (Test-Path -LiteralPath $LockPath -PathType Leaf)) { Remove-Item -LiteralPath $LockPath -Force }; $LockAcquired = $false } catch { $RollbackErrors += "lock cleanup: $($_.Exception.Message)" }
    if ($RollbackErrors.Count -gt 0) { throw "Installation failed at '$RelativePath'; rollback had errors: $($RollbackErrors -join '; '). Correct the target manually and rerun." }
    throw "Installation failed at '$RelativePath'; rollback succeeded. Correct the reported issue and rerun. Cause: $Cause"
  }
}
