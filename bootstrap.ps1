# Amorce publique HMG - ne contient aucune donnee metier/entreprise.
# Installe Git for Windows si absent + les prerequis LLM Hub/Bedrock (aws, az, gh, jq, extension gh-cicd -
# voir docs/setup-llmhub.md du repo prive), clone le repo prive claude-hmg-context (authentification GitHub
# via Git Credential Manager, fenetre de navigateur), puis lance son setup/install.ps1.
#
# Usage : coller la commande depuis n'importe quel PowerShell. L'admin n'est demande QUE si un des outils
# ci-dessous manque reellement (winget --scope machine/MSI en ont besoin) - si tout est deja installe (meme
# sur un compte non-admin), tout le reste (clone, install.ps1) tourne sans elevation. Ne JAMAIS exiger
# l'admin de facon inconditionnelle : sur un poste ou winget est bloque/casse par la politique entreprise
# (constate le 2026-09-28), forcer l'admin pour rien empeche d'utiliser des outils deja presents.
$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/mushadows/claude-hmg-context.git'

$Dest = ''
while ([string]::IsNullOrWhiteSpace($Dest)) {
  $Dest = Read-Host "Ou installer claude-hmg-context ? (chemin complet, ex: C:\hmg\claude-hmg-context)"
  if ([string]::IsNullOrWhiteSpace($Dest)) {
    Write-Warning "Un chemin est requis - il n'y a pas de valeur par defaut."
  }
}
$Dest = $Dest.Trim().Trim('"')

function Test-Cmd([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Sync-PathFromMachine {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- Git + prerequis LLM Hub/Bedrock (aws, az, gh, jq) - installes ensemble s'il en manque un seul ---
$needsGit = -not (Test-Cmd 'git')
$needsAws = -not (Test-Cmd 'aws')
$needsAz  = -not (Test-Cmd 'az')
$needsGh  = -not (Test-Cmd 'gh')
$needsJq  = -not (Test-Cmd 'jq')

if ($needsGit -or $needsAws -or $needsAz -or $needsGh -or $needsJq) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Write-Error "Un ou plusieurs outils manquent (Git et/ou aws/az/gh/jq pour le setup LLM Hub) et ce PowerShell n'est pas administrateur - relance depuis un PowerShell administrateur pour les installer, OU installe-les manuellement puis relance cette commande depuis un PowerShell classique (pas besoin d'admin si tout est deja present)."
    exit 1
  }

  # winget d'abord (scope machine - evite le piege du compte admin separe, incident du 2026-09-28), sinon
  # MSI officiel en silencieux. Chaque outil est independant : un echec sur l'un n'empeche pas les autres.
  function Install-WingetOuMsi {
    param([string]$Nom, [string]$TestCmdName, [string]$WingetId, [string]$MsiUrl)
    Write-Host "$Nom introuvable - installation via winget (scope machine)..."
    if (Test-Cmd 'winget') {
      winget install --id $WingetId -e --source winget --scope machine --accept-package-agreements --accept-source-agreements
      Sync-PathFromMachine
    }
    if (-not (Test-Cmd $TestCmdName)) {
      Write-Warning "winget indisponible/bloque ou installation echouee pour $Nom - tentative via le MSI officiel..."
      $msiPath = Join-Path $env:TEMP "$Nom-installer.msi"
      try {
        Invoke-WebRequest -Uri $MsiUrl -OutFile $msiPath -UseBasicParsing
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
        if ($proc.ExitCode -ne 0) { throw "msiexec a retourne le code $($proc.ExitCode)" }
      } catch {
        Write-Warning "Installation MSI de $Nom echouee ($_) - installe-le manuellement : $MsiUrl"
      } finally {
        Remove-Item $msiPath -ErrorAction SilentlyContinue
      }
      Sync-PathFromMachine
    }
    if (-not (Test-Cmd $TestCmdName)) {
      Write-Warning "$Nom toujours introuvable - a installer manuellement si besoin pour le setup LLM Hub (voir docs/setup-llmhub.md)."
    }
  }

  if ($needsGit) {
    # Git a sa propre installation dediee : son installeur officiel est un .exe (Inno Setup), pas un MSI -
    # ne PAS reutiliser Install-WingetOuMsi (msiexec planterait dessus). winget uniquement, sinon manuel.
    if (Test-Cmd 'winget') {
      Write-Host "Git introuvable - installation via winget (scope machine)..."
      winget install --id Git.Git -e --source winget --scope machine --accept-package-agreements --accept-source-agreements
      Sync-PathFromMachine
    }
    if (-not (Test-Cmd 'git')) {
      # winget peut etre absent, casse (source corrompue - erreur 0x8a15000f constatee le 2026-09-28,
      # "winget source reset --force" peut aider) OU bloque par politique entreprise - pas d'equivalent npm
      # pour Git (ce n'est pas un paquet Node), donc pas de fallback automatise possible ici.
      Write-Error "Git introuvable et l'installation via winget a echoue (source cassee/bloquee, ou pas encore detectee dans cette session) - essaie 'winget source reset --force' puis relance, ou installe Git for Windows manuellement (https://git-scm.com/download/win) puis relance cette commande."
      exit 1
    }
  }
  if ($needsAws) { Install-WingetOuMsi -Nom 'AWS CLI' -TestCmdName 'aws' -WingetId 'Amazon.AWSCLI' -MsiUrl 'https://awscli.amazonaws.com/AWSCLIV2.msi' }
  if ($needsAz)  { Install-WingetOuMsi -Nom 'Azure CLI' -TestCmdName 'az' -WingetId 'Microsoft.AzureCLI' -MsiUrl 'https://aka.ms/installazurecliwindows' }
  if ($needsGh)  { Install-WingetOuMsi -Nom 'GitHub CLI' -TestCmdName 'gh' -WingetId 'GitHub.cli' -MsiUrl 'https://github.com/cli/cli/releases/latest/download/gh_amd64.msi' }
  if ($needsJq) {
    # Pas de MSI officiel pour jq - binaire seul, pas de package npm officiel non plus (les packages npm
    # existants type node-jq sont non officiels) : telechargement direct du binaire signe par le projet.
    Write-Host "jq introuvable - telechargement du binaire officiel..."
    $jqDir = 'C:\ProgramData\jq'
    try {
      New-Item -ItemType Directory -Force -Path $jqDir | Out-Null
      Invoke-WebRequest -Uri 'https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe' -OutFile (Join-Path $jqDir 'jq.exe') -UseBasicParsing
      $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
      if ($machinePath -notlike "*$jqDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$machinePath;$jqDir", 'Machine')
      }
      Sync-PathFromMachine
    } catch {
      Write-Warning "Telechargement de jq echoue ($_) - installe-le manuellement : https://jqlang.github.io/jq/download/"
    }
  }

  # Extension gh-cicd (pas de secret dedans, juste l'outil - le wiring LLM Hub avec client-id/ARN reste une
  # etape manuelle a part, voir le message de fin de script).
  if ((Test-Cmd 'gh') -and (-not (gh extension list 2>$null | Select-String 'gh-cicd'))) {
    Write-Host "Installation de l'extension gh-cicd (setup LLM Hub/Bedrock)..."
    try { gh extension install TotalEnergiesCode/gh-cicd } catch { Write-Warning "Installation de l'extension gh-cicd echouee ($_) - installe-la a la main : gh extension install TotalEnergiesCode/gh-cicd" }
  }
}

try {
  if (-not (Test-Path (Join-Path $Dest '.git'))) {
    Write-Host "Clonage de claude-hmg-context (une fenetre de connexion GitHub va s'ouvrir - le repo est prive, il faut y avoir ete invite comme collaborateur)..."
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
    git clone $RepoUrl $Dest
  } else {
    Write-Host "claude-hmg-context deja clone dans $Dest - mise a jour..."
    git -C $Dest pull --ff-only
  }
} catch {
  # Le dossier parent choisi peut etre en lecture seule pour un compte non-admin sur un poste verrouille -
  # Git lui-meme ne necessite pas d'admin, mais creer un dossier a cet emplacement si.
  Write-Error "Impossible de creer/ecrire dans $Dest ($_) - si ton compte n'a pas le droit de creer de dossier a cet emplacement, choisis un autre chemin (ex: dans ton profil utilisateur), demande a un admin de creer le dossier parent (droits d'ecriture pour ton compte), ou relance cette commande depuis un PowerShell administrateur juste pour cette etape."
  exit 1
}

Write-Host "Lancement de l'installation HMG (setup\install.ps1)..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'setup\install.ps1')
