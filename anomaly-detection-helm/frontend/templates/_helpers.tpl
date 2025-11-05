{{- define "frontend.name" -}}
{{- default "frontend" .Chart.Name -}}
{{- end -}}


{{- define "frontend.fullname" -}}
{{- printf "%s" (include "frontend.name" .) -}}
{{- end -}}