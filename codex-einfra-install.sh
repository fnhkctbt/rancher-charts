#!/usr/bin/env bash
# ============================================================================
# codex-einfra — interaktivní instalace do e-INFRA CZ Kubernetes
#
# KDE SPUSTIT (2 možnosti, obojí funguje):
#   1) Rancher UI (doporučeno, bez lokálních nástrojů):
#      Přihlas se na https://rancher.cloud.e-infra.cz → vpravo nahoře ikonka
#      terminálu ( Activate Shell / kubectl ) → vlož CELÝ obsah tohoto
#      souboru → Enter. Následuje formulář.
#   2) Vlastní počítač s kubeconfigem z Rancheru (~/.kube/config):
#      bash codex-einfra-install.sh
#
# Formulář se ptá na: API klíč (skrytě), heslo (skrytě), jméno pro DNS,
# velikost disku, volitelně Harbor pull secret. Klíče jdou POUZE do
# Kubernetes Secrets ve tvém namespace — nikdy do žádného souboru.
#
# Odinstalace:  codex-einfra-install.sh --remove
# ============================================================================
set -euo pipefail

IMAGE="cerit.io/ctbt/codex-einfra:1.0.5"
PREFIX="codex"

say() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mCHYBA:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl nenalezen — spusť v Rancher kubectl shellu nebo s kubeconfigem."

# ── odinstalace ─────────────────────────────────────────────────────────────
if [ "${1:-}" = "--remove" ]; then
  say "Odinstaluji codex-einfra (POZOR: smaže i data na disku!)."
  NS="$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || true)"
  NS="${NS:-default}"
  read -rp "Namespace [$NS]: " tmp; NS="${tmp:-$NS}"
  for obj in httproute/"$PREFIX-websecure" httproute/"$PREFIX-web-redirect" \
             middleware.traefik.io/"$PREFIX-basic-auth" networkpolicy/"$PREFIX-netpol" \
             deployment/"$PREFIX" service/"$PREFIX-svc" pvc/"$PREFIX-data" \
             secret/"$PREFIX-apikey" secret/"$PREFIX-basic-auth-users" secret/"$PREFIX-harbor-pull"; do
    kubectl delete "$obj" --ignore-not-found -n "$NS"
  done
  say "Hotovo."
  exit 0
fi

# ── 0) kontroly ──────────────────────────────────────────────────────────────
say "Kontrola přístupu ke clusteru…"
CTX="$(kubectl config current-context 2>/dev/null || echo "?")"
echo "    kontext: $CTX"
kubectl get --raw /readyz >/dev/null 2>&1 || die "API není dostupné — zkontroluj přihlášení/kubeconfig."

# ── 1) namespace ────────────────────────────────────────────────────────────
DEF_NS="$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || true)"
DEF_NS="${DEF_NS:-default}"
say "Tvoje namespaces:"
kubectl get namespaces -o name 2>/dev/null | sed 's|^|    |' || true
read -rp "Do kterého namespace instalovat? [$DEF_NS]: " NS
NS="${NS:-$DEF_NS}"
kubectl get namespace "$NS" >/dev/null 2>&1 || die "Namespace '$NS' neexistuje."

# ── 2) formulář ──────────────────────────────────────────────────────────────
say "Jméno instance — z něho vznikne adresa https://codex-<jmeno>.dyn.cloud.e-infra.cz"
read -rp "Krátké jméno (malá písmena, čísla, pomlčky) [codex]: " HOSTPART
HOSTPART="${HOSTPART:-codex}"
HOSTNAME="codex-${HOSTPART}.dyn.cloud.e-infra.cz"
echo "    → adresa bude: https://$HOSTNAME"

read -rp "Basic-auth uživatel (přihlášení do web UI): " AUTH_USER
[ -n "$AUTH_USER" ] || die "Uživatel nesmí být prázdný."
while true; do
  read -rsp "Basic-auth heslo (skryté): " AUTH_PASS; echo
  [ "${#AUTH_PASS}" -ge 8 ] || { echo "    Minimálně 8 znaků."; continue; }
  read -rsp "Heslo znovu (skryté): " AUTH_PASS2; echo
  [ "$AUTH_PASS" = "$AUTH_PASS2" ] && break
  echo "    Hesla se neshodují, zkus znovu."
done

read -rsp "e-infra API klíč z https://llm.ai.e-infra.cz (skryté): " API_KEY; echo
[ -n "$API_KEY" ] || die "API klíč nesmí být prázdný."

say "Výchozí model (v aplikaci lze kdykoli přepnout, živý seznam se synchronizuje):"
echo "    1) glm-5.3"
echo "    2) qwen3.8-flash-next"
echo "    3) gpt-oss-120b"
read -rp "Volba [1]: " M
case "${M:-1}" in
  2) MODEL="qwen3.8-flash-next" ;;
  3) MODEL="gpt-oss-120b" ;;
  *) MODEL="glm-5.3" ;;
esac

say "Disk (PVC):"
read -rp "Velikost [500Gi]: " ST_SIZE
ST_SIZE="${ST_SIZE:-500Gi}"
DEF_SC="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}' 2>/dev/null || true)"
DEF_SC="$(printf '%s' "$DEF_SC" | head -n1 | tr -d '[:space:]')"
DEF_SC="${DEF_SC:-nfs-csi}"
echo "    Dostupné storage classy:"
kubectl get storageclass -o name 2>/dev/null | sed 's|^storageclass\.storage\.k8s\.io/|      |' || true
read -rp "Storage class [$DEF_SC]: " ST_CLASS
ST_CLASS="${ST_CLASS:-$DEF_SC}"
echo "    Pozn.: nfs-csi = bez zálohy; nfs-csi-backup = 30denní záloha."

say "Image je v PRIVÁTNÍM Harbor projektu — pull secret? (jen pro vlastní test)"
read -rp "Vyplnit Harbor údaje? [y/N]: " DO_PULL
PULL_BLOCK="      imagePullSecrets: []"
PULL_NAME=""
case "${DO_PULL:-}" in
  y|Y|yes|a|A)
  read -rp "Harbor username (přihlášení na hub.cerit.io): " HB_USER
  read -rsp "Harbor CLI secret (skryté; hub.cerit.io → User Profile): " HB_SECRET; echo
  [ -n "$HB_USER" ] && [ -n "$HB_SECRET" ] || die "Neúplné Harbor údaje."
  PULL_NAME="$PREFIX-harbor-pull"
  kubectl create secret docker-registry "$PULL_NAME" \
    --docker-server=cerit.io --docker-username="$HB_USER" \
    --docker-password="$HB_SECRET" -n "$NS" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  unset HB_SECRET
  PULL_BLOCK="      imagePullSecrets:
        - name: $PULL_NAME"
  say "Pull secret vytvořen."
  ;;
esac

# ── 3) secrets (klíče nikdy do manifestu!) ──────────────────────────────────
say "Vytvářím Kubernetes Secrets v namespace $NS…"
kubectl create secret generic "$PREFIX-apikey" \
  --from-literal=EINFRA_API_KEY="$API_KEY" -n "$NS" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
unset API_KEY

# htpasswd hash: apr1 přes openssl (když je), jinak {SHA} z sha1sum+base64
if command -v openssl >/dev/null 2>&1; then
  HASH="$(openssl passwd -apr1 "$AUTH_PASS")"
else
  SHA1HEX="$(printf '%s' "$AUTH_PASS" | sha1sum | cut -d' ' -f1)"
  HASH="{SHA}$(printf '%s' "$SHA1HEX" | sed 's/../\\x&/g' | printf '%b' | base64 -w0 2>/dev/null || printf '%s' "$SHA1HEX" | sed 's/../\\x&/g' | printf '%b' | base64)"
fi
kubectl create secret generic "$PREFIX-basic-auth-users" \
  --from-literal=users="$AUTH_USER:$HASH" -n "$NS" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
unset AUTH_PASS HASH

# ── 4) manifest ────────────────────────────────────────────────────────────
say "Aplikuji deployment…"
cat <<YAML | kubectl apply -n "$NS" -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PREFIX-data
  labels: { app: codex }
spec:
  accessModes: [ ReadWriteOnce ]
  storageClassName: $ST_CLASS
  resources:
    requests:
      storage: $ST_SIZE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $PREFIX
  labels: { app: codex }
spec:
  replicas: 1
  strategy: { type: Recreate }
  selector:
    matchLabels: { app: codex }
  template:
    metadata:
      labels: { app: codex }
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile: { type: RuntimeDefault }
$PULL_BLOCK
      containers:
        - name: codex
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef: { name: $PREFIX-apikey }
          env:
            - { name: SERVER_PORT, value: "3001" }
            - { name: HOST, value: "0.0.0.0" }
            - { name: EINFRA_MODEL, value: "$MODEL" }
            - { name: ADMIN_USER, value: "codex" }
            - { name: ADMIN_PASSWORD, value: "" }
            - { name: ALLOW_REGISTRATION, value: "true" }
            - { name: DATABASE_PATH, value: "/data/db/auth.db" }
            - { name: CWD, value: "/workspace" }
            - { name: SESSION_IDLE_SEC, value: "7200" }
          ports:
            - containerPort: 3001
          resources:
            requests: { cpu: "2", memory: 8Gi }
            limits: { cpu: "8", memory: 32Gi }
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: { drop: [ "ALL" ] }
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim: { claimName: $PREFIX-data }
---
apiVersion: v1
kind: Service
metadata:
  name: $PREFIX-svc
  labels: { app: codex }
spec:
  type: ClusterIP
  selector: { app: codex }
  ports:
    - name: http
      port: 80
      targetPort: 3001
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: $PREFIX-basic-auth
spec:
  basicAuth:
    secret: $PREFIX-basic-auth-users
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: $PREFIX-websecure
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: kube-system
      sectionName: websecure
  hostnames:
    - $HOSTNAME
  rules:
    - filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: $PREFIX-basic-auth
      backendRefs:
        - name: $PREFIX-svc
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: $PREFIX-web-redirect
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: kube-system
      sectionName: web
  hostnames:
    - $HOSTNAME
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $PREFIX-netpol
spec:
  podSelector:
    matchLabels: { app: codex }
  policyTypes: [ Ingress ]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
      ports:
        - protocol: TCP
          port: 3001
YAML

# ── 5) hotovo ───────────────────────────────────────────────────────────────
say "Čekám na rollout (2–5 min, první start stahuje image)…"
kubectl rollout status deployment/"$PREFIX" -n "$NS" --timeout=600s || true
say "Hotovo!"
echo "    Adresa:   https://$HOSTNAME"
echo "    Přihlášení: basic-auth ($AUTH_USER + zvolené heslo)"
echo "    Uvnitř:   zaregistruj se v CloudCLI a vyber model."
echo "    Logy:     kubectl logs -n $NS deployment/$PREFIX"
echo "    Odinstalace: $0 --remove"
