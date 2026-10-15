# rancher-charts

Helm charty pro Rancher (e-INFRA CZ / CERIT-SC Kubernetes) — osobní instalace
pro tým FN HK CTBT.

## codex-einfra

Osobní izolovaný kontejner s Codex CLI + CloudCLI web UI, modely
https://llm.ai.e-infra.cz. Vlastní disk 500 GB, běh bez roota (uid 1000),
NetworkPolicy, basic-auth.

### Přidání do Rancheru (jednorázově provede každý uživatel s vlastním projektem)

Rancher → Apps → Repositories → **Add** →
- Name: `fnhk-charts`
- Git Repo URL: `https://github.com/fnhkctbt/rancher-charts`
- Branch: `master`

Pak Apps → Charts → **codex-einfra** → Install → vyplň formulář
(API klíč, jméno instance, basic-auth heslo, velikost disku).

Detaily: `charts/codex-einfra/v0.1.0/app-readme.md`
