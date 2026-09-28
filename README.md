# claude-hmg-bootstrap

Script d'amorçage public, sans aucune donnée d'entreprise. Sert à démarrer l'installation sur un poste
Windows 11 qui n'a ni Git ni Claude Code CLI, et installe au passage les prérequis du setup LLM Hub/Bedrock
(`aws`, `az`, `gh`, `jq`, extension `gh-cicd`) — le vrai contenu (règles, rôles, skills, doc LLM Hub) vit dans
le repo privé `claude-hmg-context`, que ce script clone.

## Installation (une seule commande)
Ouvrir PowerShell (admin pas obligatoire si tout est déjà installé — voir ci-dessous), puis coller :

```powershell
irm https://raw.githubusercontent.com/mushadows/claude-hmg-bootstrap/main/bootstrap.ps1 | iex
```

Ce que ça fait :
1. Si Git, `aws`, `az`, `gh` ou `jq` manquent, les installe (winget en scope machine, avec repli sur le MSI
   officiel de chacun si winget est absent/bloqué — `jq` n'a ni winget garanti ni MSI, télécharge son binaire
   officiel directement) — **c'est le seul cas où l'admin est requis** (clic droit sur PowerShell > Exécuter
   en tant qu'administrateur). Si tout est déjà présent (même installé par quelqu'un d'autre, même sur un
   poste où `winget` est bloqué par la politique entreprise), tout tourne sans élévation.
2. Installe l'extension `gh extension install TotalEnergiesCode/gh-cicd` si `gh` est disponible (pas de
   secret dedans, juste l'outil — le wiring réel avec ton `client-id`/ARN LLM Hub reste une étape manuelle,
   voir `docs/setup-llmhub.md` dans `claude-hmg-context`)
3. Clone `claude-hmg-context` dans `C:\hmg\claude-hmg-context` (privé — une fenêtre de connexion GitHub
   s'ouvre ; il faut avoir été invité comme collaborateur sur ce repo au préalable)
4. Lance `setup/install.ps1` du repo cloné, qui installe Claude Code CLI si besoin (winget puis fallback npm)
   et termine la configuration

## Pourquoi un repo à part
`irm | iex` ne peut récupérer que du contenu **public** non authentifié — impossible de pointer directement
sur un repo privé avant que Git ne soit installé. Ce repo ne contient donc que la logique d'amorçage, jamais
de règles ni d'information sur l'entreprise.
