{{/*
==============================================================================
  _helpers.tpl — Reusable named templates for the OrderManager Helm chart.
  These templates generate consistent names, labels, and selectors across
  all Kubernetes resources in the chart. They ensure that resource naming
  follows Kubernetes conventions (max 63 characters) and that label selectors
  remain stable for rolling updates and service discovery.
==============================================================================
*/}}

{{/*
Expand the name of the chart.
Uses .Values.nameOverride if set, otherwise falls back to the chart name
defined in Chart.yaml. The result is truncated to 63 characters to comply
with Kubernetes naming constraints (RFC 1123 DNS label).
*/}}
{{- define "ordermanager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Generate a fully qualified app name.
If .Values.fullnameOverride is set, use it directly (truncated to 63 chars).
Otherwise, combine the Helm release name with the chart name to produce a
unique name per release. This prevents naming collisions when multiple
releases of the same chart are installed in a cluster.
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
Common labels applied to every resource in the chart.
These labels support operational concerns:
  - helm.sh/chart: Identifies the chart name and version for auditing
  - app.kubernetes.io/name: Standard app identifier for grouping resources
  - app.kubernetes.io/instance: Distinguishes between multiple releases
  - app.kubernetes.io/managed-by: Indicates Helm manages this resource lifecycle
*/}}
{{- define "ordermanager.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "ordermanager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used by Services, Deployments, and HPAs to match pods.
These are a minimal subset of the common labels — only the fields that
uniquely identify the application pods. Selector labels must remain
immutable after a Deployment is created, so they intentionally exclude
version-specific fields like helm.sh/chart.
*/}}
{{- define "ordermanager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ordermanager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
