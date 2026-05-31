{{- define "asp.name" -}}{{ .Release.Name }}{{- end -}}

{{/* Common labels. app.kubernetes.io/name is the Application CR selector. */}}
{{- define "asp.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Per-component selector labels. */}}
{{- define "asp.componentLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
