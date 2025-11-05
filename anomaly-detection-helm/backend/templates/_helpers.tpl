{{- define "backend.name" -}}
{{- default "backend" .Chart.Name -}}
{{- end -}}


{{- define "backend.fullname" -}}
{{- printf "%s" (include "backend.name" .) -}}
{{- end -}}