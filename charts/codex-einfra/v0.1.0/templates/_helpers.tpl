{{/* Standard labels */}}
{{- define "codex-einfra.labels" -}}
app.kubernetes.io/name: codex-einfra
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
