# Amorce publique HMG - ne contient aucune donnee metier/entreprise.
# Installe Git for Windows si absent, clone le repo prive claude-hmg-context (authentification GitHub via
# Git Credential Manager, fenetre de navigateur), puis lance son setup/install.ps1.
#
# Usage (ouvrir PowerShell en tant qu'administrateur, puis coller) :
#   irm https://raw.githubusercontent.com/mushadows/claude-hmg-bootstrap/main/bootstrap.ps1 | iex
$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/mushadows/claude-hmg-context.git'
$Dest = 'C:\hmg\claude-hmg-context'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Error "Ce script doit etre lance depuis un PowerShell administrateur : clic droit sur 'PowerShell' > 'Executer en tant qu'administrateur', puis retape la commande."
  exit 1
}

function Test-Cmd([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Sync-PathFromMachine {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Test-Cmd 'git')) {
  if (Test-Cmd 'winget') {
    Write-Host "Git introuvable - installation via winget (scope machine)..."
    # --scope machine : evite qu'une elevation via un compte admin SEPARE du compte local (identifiants
    # differents, cas frequent si le compte local n'est pas dans le groupe Administrateurs) installe dans
    # le profil de ce compte admin, invisible ensuite pour le compte local (incident reel du 2026-09-28).
    winget install --id Git.Git -e --source winget --scope machine --accept-package-agreements --accept-source-agreements
    Sync-PathFromMachine
  }
  if (-not (Test-Cmd 'git')) {
    # winget peut etre absent OU bloque par politique entreprise - pas d'equivalent npm pour Git (ce n'est
    # pas un paquet Node), donc pas de fallback automatise possible ici.
    Write-Error "Git introuvable et l'installation via winget a echoue (absent, bloque par politique entreprise, ou pas encore detecte dans cette session) - installe Git for Windows manuellement (https://git-scm.com/download/win) puis relance cette commande."
    exit 1
  }
}

if (-not (Test-Path (Join-Path $Dest '.git'))) {
  Write-Host "Clonage de claude-hmg-context (une fenetre de connexion GitHub va s'ouvrir - le repo est prive, il faut y avoir ete invite comme collaborateur)..."
  New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
  git clone $RepoUrl $Dest
} else {
  Write-Host "claude-hmg-context deja clone dans $Dest - mise a jour..."
  git -C $Dest pull --ff-only
}

Write-Host "Lancement de l'installation HMG (setup\install.ps1)..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'setup\install.ps1')
