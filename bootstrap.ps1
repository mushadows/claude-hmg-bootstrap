# Amorce publique HMG - ne contient aucune donnee metier/entreprise.
# Installe Git for Windows si absent, clone le repo prive claude-hmg-context (authentification GitHub via
# Git Credential Manager, fenetre de navigateur), puis lance son setup/install.ps1.
#
# Usage : coller la commande depuis n'importe quel PowerShell. L'admin n'est demande QUE si Git est absent
# (winget --scope machine en a besoin) - si Git est deja installe (meme sur un compte non-admin), tout le
# reste (clone, install.ps1) tourne sans elevation. Ne JAMAIS exiger l'admin de facon inconditionnelle : sur
# un poste ou winget est bloque/casse par la politique entreprise (constate le 2026-09-28), forcer l'admin
# pour rien empeche d'utiliser un Git deja present sur le compte classique.
$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/mushadows/claude-hmg-context.git'
$Dest = 'C:\hmg\claude-hmg-context'

function Test-Cmd([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Sync-PathFromMachine {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Test-Cmd 'git')) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Write-Error "Git introuvable et ce PowerShell n'est pas administrateur - relance depuis un PowerShell administrateur (clic droit > Executer en tant qu'administrateur) pour installer Git via winget, OU installe Git manuellement (https://git-scm.com/download/win) puis relance cette commande depuis un PowerShell classique (pas besoin d'admin si Git est deja present)."
    exit 1
  }
  if (Test-Cmd 'winget') {
    Write-Host "Git introuvable - installation via winget (scope machine)..."
    # --scope machine : evite qu'une elevation via un compte admin SEPARE du compte local (identifiants
    # differents, cas frequent si le compte local n'est pas dans le groupe Administrateurs) installe dans
    # le profil de ce compte admin, invisible ensuite pour le compte local (incident reel du 2026-09-28).
    winget install --id Git.Git -e --source winget --scope machine --accept-package-agreements --accept-source-agreements
    Sync-PathFromMachine
  }
  if (-not (Test-Cmd 'git')) {
    # winget peut etre absent, casse (source corrompue - erreur 0x8a15000f constatee le 2026-09-28,
    # "winget source reset --force" peut aider) OU bloque par politique entreprise - pas d'equivalent npm
    # pour Git (ce n'est pas un paquet Node), donc pas de fallback automatise possible ici.
    Write-Error "Git introuvable et l'installation via winget a echoue (source cassee/bloquee, ou pas encore detecte dans cette session) - essaie 'winget source reset --force' puis relance, ou installe Git for Windows manuellement (https://git-scm.com/download/win) puis relance cette commande."
    exit 1
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
  # C:\hmg peut etre en lecture seule pour un compte non-admin sur un poste verrouille - Git lui-meme ne
  # necessite pas d'admin, mais creer un dossier a la racine de C: si.
  Write-Error "Impossible de creer/ecrire dans $Dest ($_) - si ton compte n'a pas le droit de creer de dossier a la racine de C:\, demande a un admin de creer C:\hmg une fois (droits d'ecriture pour ton compte), ou relance cette commande depuis un PowerShell administrateur juste pour cette etape."
  exit 1
}

Write-Host "Lancement de l'installation HMG (setup\install.ps1)..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'setup\install.ps1')
