# rancher-charts

Instalace **Codex CLI + CloudCLI** kontejneru na e-INFRA CZ Kubernetes
(modely https://llm.ai.e-infra.cz, vlastní disk, běh bez roota).

## Jak nainstalovat (Rancher kubectl shell — bez lokálních nástrojů)

1. Přihlas se na https://rancher.cloud.e-infra.cz
2. Vpravo nahoře otevři **kubectl shell** (ikonka terminálu)
3. Vlož celý obsah `codex-einfra-install.sh` a Enter
4. Formulář se zeptá na: e-infra **API klíč** (skrytě), **heslo** (skrytě),
   **jméno pro DNS**, velikost disku, volitelně Harbor pull secret
5. Po 2–5 min: `https://codex-<jméno>.dyn.cloud.e-infra.cz`

Klíče se ukládají POUZE do Kubernetes Secrets ve tvém namespace.
Odinstalace: skript spusť s `--remove`.

## Alternativa: import YAML

`codex-einfra.yaml` lze importovat přes Rancher UI (Import YAML) — předem
vyplň 3 označená místa (API klíč, htpasswd hash, hostname). Bez formuláře.

## Helm chart (pro budoucí PR do CERIT-SC/rancher-apps)

`charts/codex-einfra/v0.1.0/` — Rancher questions formulář
(`type: password` pro API klíč), instalovatelný po přidání repa jako
App Repository (cluster/project admin) nebo PR do rancher-apps.
