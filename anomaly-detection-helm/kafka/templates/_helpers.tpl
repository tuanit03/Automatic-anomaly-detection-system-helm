{{- define "kafka.name" -}}
{{- default "kafka" .Chart.Name -}}
{{- end -}}


{{- define "kafka.fullname" -}}
{{- printf "%s" (include "kafka.name" .) -}}
{{- end -}}