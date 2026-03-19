{{/*
Reusable Helm template helpers for the OrderManager chart.
These named templates generate consistent names and labels across
all Kubernetes resources produced by this chart.
*/}}

{{/*
Short name: defaults to Chart.Name, truncated to 63 chars (K8s label limit).
Override with .Values.nameOverride if a custom short name is needed.
*/}}
{{- define "ordermanager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified resource name: "<release>-<chart>", truncated to 63 chars.
Override entirely with .Values.fullnameOverride.
*/}}
{{- define "ordermanager.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Standard metadata labels applied to every resource.
Includes chart version for auditability and Helm-managed-by marker.
*/}}
{{- define "ordermanager.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "ordermanager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used by Services and Deployments to match pods.
Must be a subset of ordermanager.labels to satisfy K8s selector immutability.
*/}}
{{- define "ordermanager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ordermanager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
