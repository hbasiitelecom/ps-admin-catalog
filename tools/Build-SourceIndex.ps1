#Requires -Version 7.0
<#
=====================================================================================
 Generateur d'index de source
 ---------------------------------------------------------------------------------
 Clone une source, l'analyse, et publie un index JSON que l'application consomme
 telle quelle. Le poste de l'utilisateur ne clone plus rien et n'analyse plus rien :
 il telecharge l'index, puis le script qu'il veut lancer, a la demande.

 Concu pour tourner dans l'integration continue du depot catalogue.

   pwsh tools/Build-SourceIndex.ps1 -Catalog catalog.json -Out index

 IMPORTANT : la section « Analyse » ci-dessous doit rester alignee avec la section 4
 de PS-Admin-Launcher.ps1. Le champ indexVersion sert de contrat : l'application
 refuse un index dont la version ne correspond pas a celle qu'elle sait lire, et
 retombe alors sur son analyse locale.
=====================================================================================
#>
[CmdletBinding()]
param(
    [string]$Catalog = 'catalog.json',
    [string]$Out     = 'index',
    [string[]]$Only,                       # limiter a certaines sources
    [switch]$IncludeDisabled,              # indexer aussi les sources desactivees
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$IndexVersion = 1

function Say([string]$m, [string]$c = 'Gray') { Write-Host "  $m" -ForegroundColor $c }
function Step([string]$m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }

# ----------------------------------------------------------------------------------
# Analyse - doit rester alignee avec la section 4 de l'application
# ----------------------------------------------------------------------------------
$SeverityRank = @{ 'ok' = 0; 'warn' = 1; 'broken' = 2 }

$DefaultImpactVerbs = @{
    read        = @('Get','Export','Find','Measure','Search','Show','Read','Test','Compare')
    modify      = @('Set','New','Add','Update','Enable','Disable','Grant','Register','Move','Rename','Send','Invoke','Start')
    destructive = @('Remove','Delete','Clear','Reset','Revoke','Uninstall','Unregister','Block')
}
$DefaultIgnoredCommands = @(
    'New-Object','Add-Member','Set-Content','Add-Content','Out-File','Export-Csv','Import-Csv',
    'Export-Clixml','Import-Clixml','Write-Host','Write-Output','Write-Progress','Write-Warning',
    'Write-Error','Write-Verbose','Write-Debug','Install-Module','Import-Module','Remove-Module',
    'Get-Module','Get-Command','Get-Help','New-Item','Remove-Item','Test-Path','Get-Content',
    'Get-ChildItem','Select-Object','Where-Object','ForEach-Object','Sort-Object','Group-Object',
    'Measure-Object','New-TimeSpan','Get-Date','Start-Sleep','ConvertTo-SecureString',
    'ConvertFrom-Json','ConvertTo-Json','ConvertFrom-Csv','ConvertTo-Csv','New-PSSession',
    'Remove-PSSession','Set-ExecutionPolicy','Clear-Host','Read-Host','Get-Credential',
    'New-Variable','Set-Variable','Clear-Variable','Remove-Variable','Compare-Object',
    'Select-String','Set-Location','Join-Path','Split-Path','Start-Process','Invoke-Item',
    'Out-Null','Out-GridView','Format-Table','Format-List','New-Guid','Set-StrictMode','New-Alias'
)
$SensitiveParamPattern  = '(?i)(password|passwd|pwd|secret|token|credential|apikey|api_key)$'
$DefaultExcludePatterns = @(
    '*/tests/*','*/test/*','*.tests.ps1','*.test.ps1',
    '*/private/*','*/internal/*','*/helpers/*',
    '*/build/*','*/.build/*','*/.github/*','*/docs/*','*/examples/*/output/*'
)
$FallbackService = 'Autre / local'

function Test-PathMatchesAny([string]$RelPath, [string[]]$Patterns) {
    foreach ($p in $Patterns) { if ($RelPath -like $p) { return $true } }
    return $false
}

function Get-SourceScriptFiles($Source, [string]$Root) {
    $layout = if ($Source.layout) { [string]$Source.layout } else { 'folders' }
    $files = switch ($layout) {
        'flat' { @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -ErrorAction SilentlyContinue) }
        'tree' { @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }) }
        default {
            $acc = [System.Collections.Generic.List[object]]::new()
            foreach ($d in (Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -notmatch '^\.' })) {
                foreach ($f in (Get-ChildItem -LiteralPath $d.FullName -Filter '*.ps1' -File -ErrorAction SilentlyContinue)) { $acc.Add($f) }
            }
            foreach ($f in (Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -ErrorAction SilentlyContinue)) { $acc.Add($f) }
            @($acc)
        }
    }
    $inc = @($Source.include | Where-Object { $_ })
    $exc = @($Source.exclude | Where-Object { $_ })
    if (-not $exc.Count) { $exc = $DefaultExcludePatterns }

    $kept = foreach ($f in $files) {
        $rel = '/' + ($f.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/').ToLowerInvariant()
        if ($inc.Count -and -not (Test-PathMatchesAny $rel $inc)) { continue }
        if (Test-PathMatchesAny $rel $exc) { continue }
        $f
    }
    return @($kept)
}

function Get-ImpactVerbs($Cat) {
    $v = @{}
    foreach ($k in 'read','modify','destructive') {
        $v[$k] = if ($Cat.impact -and $Cat.impact.$k) { @($Cat.impact.$k) } else { $DefaultImpactVerbs[$k] }
    }
    $v['ignore'] = if ($Cat.impact -and $Cat.impact.ignore) { @($DefaultIgnoredCommands) + @($Cat.impact.ignore) } else { $DefaultIgnoredCommands }
    return $v
}

function Get-ScriptMetadata {
    param([System.IO.FileInfo]$File, [string]$FolderName, [string]$Root, [bool]$MultiInFolder,
          $Source, $Cat, $ImpactVerbs)

    $raw = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $raw) { $raw = '' }

    $ast = $null
    try {
        $tok = $null; $perr = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($raw, [ref]$tok, [ref]$perr)
    } catch { $ast = $null }

    # La premiere ligne ou chaque commande apparait : c'est elle qui rend un constat
    # verifiable. Un constat sans numero de ligne oblige a relire tout le script.
    $commands = @(); $cmdLine = @{}
    if ($ast) {
        try {
            foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $cn = $c.GetCommandName()
                if (-not $cn -or $cn -notmatch '^[A-Za-z]+-[A-Za-z0-9]+$') { continue }
                $cn = $cn.Substring(0,1).ToUpperInvariant() + $cn.Substring(1)
                if (-not $cmdLine.ContainsKey($cn)) { $cmdLine[$cn] = [int]$c.Extent.StartLineNumber }
            }
            $commands = @($cmdLine.Keys | Sort-Object)
        } catch { $commands = @(); $cmdLine = @{} }
    }

    $header = ''
    $m = [regex]::Match($raw, '^\s*<#(?<h>.*?)#>', 'Singleline')
    if ($m.Success) { $header = $m.Groups['h'].Value }

    $name = $FolderName
    $hn = [regex]::Match($header, '(?im)^\s*Name\s*:\s*(?<v>.+)$')
    if ($hn.Success) { $name = $hn.Groups['v'].Value.Trim() }
    elseif ($FolderName -eq $File.BaseName) { $name = $File.BaseName -replace '[-_]', ' ' }
    if ($MultiInFolder) { $name = "$FolderName - $($File.BaseName)" }

    $desc = ''
    $hd = [regex]::Match($header, '(?im)^\s*Description\s*:\s*(?<v>.+)$')
    if ($hd.Success) { $desc = $hd.Groups['v'].Value.Trim() }

    $docUrl = $null
    $hu = [regex]::Match($header, '(?i)detailed\s+script\s+execution\s*:?\s*(?<v>https?://\S+)')
    if (-not $hu.Success) { $hu = [regex]::Match($header, '(?i)(?<v>https?://\S+)') }
    if ($hu.Success) { $docUrl = $hu.Groups['v'].Value.TrimEnd('.', ',', ')') }

    $services = @()
    foreach ($svc in $Cat.services) { if ($svc.pattern -and $raw -match $svc.pattern) { $services += [string]$svc.label } }
    if (-not $services) { $services = @($FallbackService) }

    $status = 'ok'
    $badge  = if ($Cat.okLabel) { [string]$Cat.okLabel } else { 'PS7' }
    $reason = 'Aucun probleme de compatibilite detecte pour PowerShell 7.'
    foreach ($rule in $Cat.rules) {
        if (-not $rule.pattern) { continue }
        $sev = [string]$rule.severity
        if (-not $SeverityRank.ContainsKey($sev)) { continue }
        if ($SeverityRank[$sev] -le $SeverityRank[$status]) { continue }
        try { $hit = $raw -match $rule.pattern } catch { $hit = $false }
        if ($hit) { $status = $sev; $badge = if ($rule.label) { [string]$rule.label } else { $sev }; $reason = [string]$rule.reason }
    }

    $impact = 'indetermine'; $impactEvidence = @()
    if ($commands.Count) {
        $useful = @($commands | Where-Object { $_ -notin $ImpactVerbs.ignore -and $_ -notmatch '^(Connect|Disconnect)-' })
        $verbOf = { param($c) ($c -split '-', 2)[0] }
        $d = @($useful | Where-Object { (& $verbOf $_) -in $ImpactVerbs.destructive })
        $w = @($useful | Where-Object { (& $verbOf $_) -in $ImpactVerbs.modify })
        $r = @($useful | Where-Object { (& $verbOf $_) -in $ImpactVerbs.read })
        if     ($d.Count) { $impact = 'destructif';   $impactEvidence = @($d | Select-Object -First 4) }
        elseif ($w.Count) { $impact = 'modification'; $impactEvidence = @($w | Select-Object -First 4) }
        elseif ($r.Count) { $impact = 'lecture';      $impactEvidence = @($r | Select-Object -First 4) }
    }

    $parameters = @(); $sensLine = 0
    if ($ast -and $ast.ParamBlock) {
        foreach ($p in $ast.ParamBlock.Parameters) {
            $pname = $p.Name.VariablePath.UserPath
            $ptype = 'string'
            if ($p.StaticType) { $ptype = $p.StaticType.Name }
            $ta = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.TypeConstraintAst] } | Select-Object -First 1
            if ($ta) { $ptype = $ta.TypeName.ToString() }
            $mand = $false; $vset = @()
            foreach ($a in $p.Attributes) {
                if ($a -is [System.Management.Automation.Language.AttributeAst]) {
                    $an = $a.TypeName.ToString()
                    if ($an -match '(?i)^Parameter$') {
                        foreach ($na in $a.NamedArguments) {
                            if ($na.ArgumentName -match '(?i)^Mandatory$') {
                                $mand = ($na.Argument.Extent.Text -match '(?i)\$true') -or $na.ExpressionOmitted
                            }
                        }
                    } elseif ($an -match '(?i)^ValidateSet$') {
                        foreach ($pa in $a.PositionalArguments) { $vset += ($pa.Extent.Text.Trim("'", '"')) }
                    }
                }
            }
            $isSwitch = $ptype -match '(?i)^\[?switch\]?$'
            $sens = [bool](($pname -match $SensitiveParamPattern) -and -not $isSwitch)
            if ($sens -and -not $sensLine) { $sensLine = [int]$p.Extent.StartLineNumber }
            $parameters += [pscustomobject]@{
                Name = $pname; Type = $ptype; Mandatory = $mand
                ValidateSet = @($vset)
                Default = $(if ($p.DefaultValue) { $p.DefaultValue.Extent.Text } else { $null })
                Sensitive = $sens
            }
        }
    }

    $modules = @(([regex]::Matches($raw, '(?i)(?:Import-Module|Install-Module)\s+["'']?([A-Za-z0-9_.]+)') |
                  ForEach-Object { $_.Groups[1].Value }) | Sort-Object -Unique)

    $scopes = @()
    $sm = [regex]::Match($raw, '(?is)Connect-MgGraph[^\r\n]*?-Scopes\s+(?<v>[^\r\n]+)')
    if ($sm.Success) {
        $scopes = @(([regex]::Matches($sm.Groups['v'].Value, '[A-Za-z]+\.[A-Za-z]+(?:\.[A-Za-z]+)*') |
                     ForEach-Object { $_.Value }) | Sort-Object -Unique)
    }

    # Des faits, chacun avec l'endroit ou le verifier.
    $ln = { param($n) if ($cmdLine.ContainsKey($n)) { " (l. $($cmdLine[$n]))" } else { '' } }
    $findings = @()
    if ($sensLine) {
        $findings += "Accepte un identifiant en clair en parametre (l. $sensLine)"
    } elseif ($parameters | Where-Object { $_.Sensitive }) {
        $findings += 'Accepte un identifiant en clair en parametre'
    }
    if ($commands -contains 'Invoke-Expression') { $findings += "Utilise Invoke-Expression$(& $ln 'Invoke-Expression')" }
    $dl = @($commands | Where-Object { $_ -in @('Invoke-WebRequest','Invoke-RestMethod','Start-BitsTransfer') })
    if ($dl.Count) {
        $findings += "Telecharge depuis une URL externe : $(($dl | ForEach-Object { $_ + (& $ln $_) }) -join ', ')"
    }
    # Install-Module n'est pas retenu : 178 des 183 scripts d'AdminDroid appellent
    # le controle de prerequis. Un constat vrai partout n'apprend rien - le meme
    # piege que -Force, present sur 174 scripts sans y etre une confirmation.
    if ($impact -eq 'destructif' -and $impactEvidence.Count) {
        $findings += "Supprime des objets du tenant : $(($impactEvidence | ForEach-Object { $_ + (& $ln $_) }) -join ', ')"
    }

    $rel = $File.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
    $readme = Join-Path $File.DirectoryName 'README.md'

    [pscustomobject]@{
        Id = "$($Source.id):$rel"; RelPath = $rel
        SourceId = [string]$Source.id; SourceName = [string]$Source.name
        Name = $name; Folder = $FolderName; FileName = $File.Name
        Description = $desc; DocUrl = $docUrl
        HasReadme = [bool](Test-Path -LiteralPath $readme)
        Services = $services; ServicesText = ($services -join ' · ')
        Status = $status; Badge = $badge; Reason = $reason
        Impact = $impact; ImpactEvidence = @($impactEvidence)
        Commands = @($commands); Modules = @($modules); Scopes = @($scopes); Findings = @($findings)
        Notes = ''; Parameters = @($parameters); Hidden = $false
        Bytes = [int]$File.Length
        Sha = ''      # renseigne ensuite depuis git ls-tree
    }
}

# ----------------------------------------------------------------------------------
# Generation
# ----------------------------------------------------------------------------------
# Avec -File, « -Only a,b,c » arrive comme une seule chaine : on l'eclate.
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$cat = Get-Content -LiteralPath $Catalog -Raw -Encoding UTF8 | ConvertFrom-Json
$verbs = Get-ImpactVerbs $cat
if (-not (Test-Path -LiteralPath $Out)) { New-Item -ItemType Directory -Path $Out -Force | Out-Null }

$sources = @($cat.sources | Where-Object {
    ($IncludeDisabled -or $null -eq $_.enabled -or [bool]$_.enabled) -and
    (-not $Only -or $_.id -in $Only)
})

Write-Host ""
Write-Host "Catalogue $($cat.catalogVersion) - $($sources.Count) source(s) a indexer" -ForegroundColor White

$summary = [System.Collections.Generic.List[object]]::new()
foreach ($src in $sources) {
    Step "$($src.name)  ($($src.owner)/$($src.repo))"
    $work = Join-Path ([IO.Path]::GetTempPath()) ("idx-" + [guid]::NewGuid().ToString('N'))
    $branch = if ($src.branch) { $src.branch } else { 'main' }
    try {
        Say "clonage superficiel de la branche $branch…"
        $sw = [Diagnostics.Stopwatch]::StartNew()
        git clone --depth 1 --quiet --branch $branch "https://github.com/$($src.owner)/$($src.repo).git" $work 2>&1 | Out-Null
        if (-not (Test-Path -LiteralPath $work)) { throw "clonage impossible" }

        $commit = (git -C $work rev-parse HEAD).Trim()
        Say "commit $($commit.Substring(0,10))"

        # Empreintes de blob : garantissent que le poste executera exactement
        # le fichier qui a ete analyse ici.
        $blob = @{}
        foreach ($line in (git -C $work ls-tree -r $commit)) {
            if ($line -match '^\d+\s+blob\s+(?<sha>[0-9a-f]{40})\s+(?<path>.+)$') {
                $blob[$Matches['path']] = $Matches['sha']
            }
        }

        $files = Get-SourceScriptFiles $src $work
        Say "$($files.Count) fichier(s) eligible(s) sur $(@(Get-ChildItem $work -Filter *.ps1 -Recurse -File).Count) .ps1"

        $perFolder = @{}
        foreach ($f in $files) { $perFolder[$f.DirectoryName] = [int]$perFolder[$f.DirectoryName] + 1 }

        $scripts = [System.Collections.Generic.List[object]]::new()
        foreach ($f in $files) {
            $folderName = if ($f.DirectoryName -eq $work.TrimEnd('\','/')) { $f.BaseName } else { Split-Path $f.DirectoryName -Leaf }
            $multi = ($perFolder[$f.DirectoryName] -gt 1) -and ($f.DirectoryName -ne $work.TrimEnd('\','/'))
            try {
                $o = Get-ScriptMetadata -File $f -FolderName $folderName -Root $work -MultiInFolder $multi -Source $src -Cat $cat -ImpactVerbs $verbs
                $o.Sha = [string]$blob[$o.RelPath]
                $scripts.Add($o)
            } catch { Say "  ignore : $($f.Name) ($_)" DarkGray }
        }
        $sw.Stop()

        $payload = [pscustomobject]@{
            indexVersion   = $IndexVersion
            sourceId       = [string]$src.id
            sourceName     = [string]$src.name
            owner          = [string]$src.owner
            repo           = [string]$src.repo
            branch         = $branch
            commit         = $commit
            catalogVersion = [string]$cat.catalogVersion
            builtUtc       = (Get-Date).ToUniversalTime().ToString('o')
            # URL figee sur le commit : le contenu ne peut plus changer sous nos pieds.
            rawBase        = "https://raw.githubusercontent.com/$($src.owner)/$($src.repo)/$commit/"
            scriptCount    = $scripts.Count
            scripts        = @($scripts)
        }
        $file = Join-Path $Out "$($src.id).json"
        $payload | ConvertTo-Json -Depth 8 -Compress | Set-Content -LiteralPath $file -Encoding UTF8

        $ko = @($scripts | Where-Object { -not $_.Sha }).Count
        Say ("{0} scripts | ok={1} warn={2} broken={3} | {4} Ko | {5:N1} s" -f `
             $scripts.Count,
             @($scripts | Where-Object Status -eq 'ok').Count,
             @($scripts | Where-Object Status -eq 'warn').Count,
             @($scripts | Where-Object Status -eq 'broken').Count,
             [int]((Get-Item $file).Length / 1KB), ($sw.ElapsedMilliseconds / 1000)) Green
        if ($ko) { Say "$ko script(s) sans empreinte de blob" Yellow }

        $summary.Add([pscustomobject]@{
            id = [string]$src.id; name = [string]$src.name; commit = $commit
            scripts = $scripts.Count; sizeKb = [int]((Get-Item $file).Length / 1KB)
            builtUtc = $payload.builtUtc
        })
    } catch {
        Say "ECHEC : $_" Red
    } finally {
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Manifeste : ce que l'application lit en premier pour savoir quoi telecharger.
[pscustomobject]@{
    indexVersion   = $IndexVersion
    catalogVersion = [string]$cat.catalogVersion
    builtUtc       = (Get-Date).ToUniversalTime().ToString('o')
    sources        = @($summary)
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Out 'manifest.json') -Encoding UTF8

Write-Host ""
Write-Host ("Total : {0} source(s), {1} scripts, {2} Ko" -f `
    $summary.Count, ($summary | Measure-Object scripts -Sum).Sum, ($summary | Measure-Object sizeKb -Sum).Sum) -ForegroundColor White
