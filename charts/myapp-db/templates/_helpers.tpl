{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "myapp.fullname" -}}
{{- printf "%s" (include "myapp.name" .) -}}
{{- end -}}
