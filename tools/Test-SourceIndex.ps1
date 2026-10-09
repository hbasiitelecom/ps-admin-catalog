#Requires -Version 7.0
<#
=====================================================================================
 Verifications du generateur d'index
 ---------------------------------------------------------------------------------
 Le generateur clone des depots et prend des minutes : il ne peut pas tourner a
 chaque demande de fusion. Ces verifications chargent ses fonctions sans executer
 la generation, et eprouvent ce qui peut l'etre hors reseau.

 La partie couverte ici est celle des fichiers voisins : relever les noms dans le
 code, puis ne declarer que ceux qui existent vraiment dans l'arbre indexe.
=====================================================================================
#>
$ok = 0; $ko = 0
function Verif([string]$Nom, [scriptblock]$Bloc) {
    try {
        if (& $Bloc) { $script:ok++; Write-Host "  ok    $Nom" -ForegroundColor Green }
        else { $script:ko++; Write-Host "  ECHEC $Nom" -ForegroundColor Red }
    } catch { $script:ko++; Write-Host "  ECHEC $Nom : $($_.Exception.Message)" -ForegroundColor Red }
}

# On charge le generateur jusqu'a sa section de generation, qui agit des qu'elle
# est lue. Les fonctions sont au-dessus.
$src = Join-Path $PSScriptRoot 'Build-SourceIndex.ps1'
$txt = Get-Content -LiteralPath $src -Raw
$marque = '# Generation'
$i = $txt.IndexOf($marque)
if ($i -lt 0) { throw "section « Generation » introuvable dans Build-SourceIndex.ps1" }
. ([scriptblock]::Create($txt.Substring(0, $i)))

Write-Host ''
Write-Host 'Releve des noms' -ForegroundColor Cyan
Verif 'un fichier lu en .\ est releve' {
    @(Get-CompanionNames '$h = Get-Content -Raw -Path .\LicenseFriendlyName.txt') -contains 'LicenseFriendlyName.txt'
}
Verif 'la forme $PSScriptRoot est relevee' {
    @(Get-CompanionNames '$svc = Import-Csv "$PSScriptRoot/ServiceFriendlyName.csv"') -contains 'ServiceFriendlyName.csv'
}
Verif 'Join-Path $PSScriptRoot est releve' {
    @(Get-CompanionNames "Join-Path `$PSScriptRoot 'parametres.json'") -contains 'parametres.json'
}
Verif 'un script dot-source est releve' {
    @(Get-CompanionNames '. .\Commun.ps1') -contains 'Commun.ps1'
}
Verif 'une extension inconnue est ignoree' {
    @(Get-CompanionNames '.\charge-utile.exe').Count -eq 0
}
Verif 'un chemin avec separateur est ignore' {
    # « ..\..\secrets\jeton.txt » ne doit jamais devenir un nom voisin.
    @(Get-CompanionNames '.\..\..\secrets\jeton.txt') -notcontains 'jeton.txt'
}
Verif 'un retour en arriere est ignore' {
    @(Get-CompanionNames '.\..txt').Count -eq 0
}
Verif 'une URL ne declenche rien' {
    @(Get-CompanionNames 'Invoke-RestMethod https://exemple.org/donnees.json').Count -eq 0
}
Verif 'un nom n''est releve qu''une fois' {
    @(Get-CompanionNames '.\a.txt et encore .\a.txt et "$PSScriptRoot\a.txt"').Count -eq 1
}

Write-Host ''
Write-Host 'Declaration' -ForegroundColor Cyan
$racine = Join-Path ([IO.Path]::GetTempPath()) ('bsi-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $racine 'Dossier') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $racine 'Dossier/donnees.txt') -Value 'abc' -NoNewline
$blob = @{ 'Dossier/donnees.txt' = ('a' * 40) }

try {
    Verif 'un voisin present dans l''arbre est declare' {
        $r = @(Resolve-Companions 'Dossier/Script.ps1' @('donnees.txt') $blob $racine)
        $r.Count -eq 1 -and $r[0].RelPath -eq 'Dossier/donnees.txt' -and $r[0].Bytes -eq 3 -and $r[0].Sha -eq ('a' * 40)
    }
    Verif 'un voisin absent de l''arbre n''est pas declare' {
        # Le cas normal d'un fichier de SORTIE : le script l'ecrit, il n'existe pas
        # en amont, rien ne doit etre declare.
        @(Resolve-Companions 'Dossier/Script.ps1' @('resultat.csv') $blob $racine).Count -eq 0
    }
    Verif 'un voisin d''un autre dossier n''est pas declare' {
        @(Resolve-Companions 'Ailleurs/Script.ps1' @('donnees.txt') $blob $racine).Count -eq 0
    }
    Verif 'un script a la racine resout sans dossier' {
        $b2 = @{ 'seul.txt' = ('b' * 40) }
        Set-Content -LiteralPath (Join-Path $racine 'seul.txt') -Value 'xy' -NoNewline
        $r = @(Resolve-Companions 'Script.ps1' @('seul.txt') $b2 $racine)
        $r.Count -eq 1 -and $r[0].RelPath -eq 'seul.txt'
    }
    Verif 'aucun nom ne declare rien, et l''appelant compte zero' {
        # Une fonction PowerShell qui rend un tableau vide ne rend RIEN : la
        # variable recoit $null. C'est pourquoi le generateur enveloppe l'appel
        # dans @( ), et pourquoi la verification fait de meme. Rendre « , @() »
        # reglerait le cas vide mais envelopperait les autres : le remede serait
        # pire. La regle du depot reste « @( ) chez l'appelant ».
        @(Resolve-Companions 'Dossier/Script.ps1' @() $blob $racine).Count -eq 0
    }
} finally { Remove-Item -LiteralPath $racine -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host "  $ok reussie(s), $ko echec(s)" -ForegroundColor $(if ($ko) { 'Red' } else { 'Green' })
Write-Host ''
exit $(if ($ko) { 1 } else { 0 })
