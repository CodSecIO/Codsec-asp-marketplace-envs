{{- define "asp-frontend.name" -}}{{ .Release.Name }}{{- end -}}
{{- define "asp-frontend.labels" -}}
app.kubernetes.io/name: {{ include "asp-frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
