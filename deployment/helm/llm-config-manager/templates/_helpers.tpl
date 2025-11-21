{{/*
Expand the name of the chart.
*/}}
{{- define "llm-config-manager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "llm-config-manager.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "llm-config-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "llm-config-manager.labels" -}}
helm.sh/chart: {{ include "llm-config-manager.chart" . }}
{{ include "llm-config-manager.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "llm-config-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llm-config-manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "llm-config-manager.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "llm-config-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "llm-config-manager.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- if .Values.global }}
    {{- if .Values.global.imageRegistry }}
        {{- $registryName = .Values.global.imageRegistry -}}
    {{- end -}}
{{- end -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else }}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end }}
{{- end }}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "llm-config-manager.imagePullSecrets" -}}
{{- if .Values.global }}
    {{- if .Values.global.imagePullSecrets }}
        {{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
        {{- end }}
    {{- end }}
{{- end }}
{{- if .Values.imagePullSecrets }}
    {{- range .Values.imagePullSecrets }}
  - name: {{ . }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Return the PostgreSQL hostname
*/}}
{{- define "llm-config-manager.postgresql.host" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else }}
{{- .Values.externalDatabase.host -}}
{{- end }}
{{- end }}

{{/*
Return the Redis hostname
*/}}
{{- define "llm-config-manager.redis.host" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis-master" .Release.Name -}}
{{- else }}
{{- .Values.externalRedis.host -}}
{{- end }}
{{- end }}

{{/*
Return the ConfigMap name
*/}}
{{- define "llm-config-manager.configMapName" -}}
{{- printf "%s-config" (include "llm-config-manager.fullname" .) -}}
{{- end }}

{{/*
Return the Secret name
*/}}
{{- define "llm-config-manager.secretName" -}}
{{- printf "%s-secrets" (include "llm-config-manager.fullname" .) -}}
{{- end }}

{{/*
Compile all warnings into a single message
*/}}
{{- define "llm-config-manager.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "llm-config-manager.validateValues.database" .) -}}
{{- $messages := append $messages (include "llm-config-manager.validateValues.redis" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}
{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/*
Validate database configuration
*/}}
{{- define "llm-config-manager.validateValues.database" -}}
{{- if and (not .Values.postgresql.enabled) (not .Values.externalDatabase.host) -}}
llm-config-manager: database
    You must enable the internal PostgreSQL or provide an external database host
{{- end -}}
{{- end -}}

{{/*
Validate Redis configuration
*/}}
{{- define "llm-config-manager.validateValues.redis" -}}
{{- if and (not .Values.redis.enabled) (not .Values.externalRedis.host) -}}
llm-config-manager: redis
    You must enable the internal Redis or provide an external Redis host
{{- end -}}
{{- end -}}
