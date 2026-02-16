{{- define "myapp-db.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "myapp-db.fullname" -}}
{{- printf "%s" (include "myapp-db.name" .) -}}
{{- end -}}
