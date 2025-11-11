{{/*
Return the fully qualified app name for resources
*/}}
{{- define "consumer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 -}}
{{- end -}}

{{- define "consumer.fullname" -}}
{{- $name := include "consumer.name" . -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 -}}
{{- else -}}
{{- printf "%s" $name | trunc 63 -}}
{{- end -}}
{{- end -}}
