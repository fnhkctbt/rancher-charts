# codex-einfra

Osobní izolovaný kontejner s **Codex CLI** a **CloudCLI web UI**, napojený na
modely **https://llm.ai.e-infra.cz** (OpenAI-kompatibilní endpoint, živá
synchronizace seznamu modelů každých 6 h).

Každý uživatel si nasadí vlastní instanci do svého Personal Project — vlastní
kontejner, vlastní disk (výchozí 500 GB), vlastní API klíč uložený jen jako
Secret v jeho namespace. Bez roota (uid 1000, všechny capabilities dropped,
seccomp RuntimeDefault, NetworkPolicy).

## Než začneš

1. MetaCentrum/eduID účet (přihlášení do Rancheru).
2. API klíč z https://llm.ai.e-infra.cz (menu „API klíč“).
3. Vygeneruj si dvě hesla: jedno pro basic-auth (vstup do web UI), druhé pro
   registraci v CloudCLI (až se UI otevře).

## Po instalaci

Otevři `https://codex-<tvoje-jmeno>.dyn.cloud.e-infra.cz` (2–5 min po startu),
přihlas se basic-auth, zaregistruj se v CloudCLI a vyber model. Hotovo.

## Poznámky

- Odinstalace přes Rancher Apps smaže i data na disku (PVC).
- Data na nfs-csi nejsou šifrovaná a záloha není (pro zálohu zvol
  `nfs-csi-backup`, 30 dní). Správci platformy k obsahu technicky přístup
  mají.
