{{- define "opsflow.validate" -}}
{{- if ne .Release.Namespace "opsflow" -}}
{{- fail "This migration chart requires release opsflow in namespace opsflow; names/selectors are fixed to existing resources." -}}
{{- end -}}
{{- if hasKey .Values.config "DB_PASSWORD" -}}{{ fail "DB_PASSWORD must stay in the existing Secret, never Helm values" }}{{- end -}}
{{- end -}}
{{- define "opsflow.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}
