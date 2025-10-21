{{/*
Return the fully qualified app name for resources
*/}}
{{- define "producer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 -}}
{{- end -}}

{{- define "producer.fullname" -}}
{{- $name := include "producer.name" . -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 -}}
{{- else -}}
{{- printf "%s" $name | trunc 63 -}}
{{- end -}}
{{- end -}}
