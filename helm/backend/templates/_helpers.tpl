{{- define "asp-backend.name" -}}{{ .Release.Name }}{{- end -}}
{{- define "asp-backend.labels" -}}
app.kubernetes.io/name: {{ include "asp-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
