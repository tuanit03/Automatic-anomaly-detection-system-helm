{{- define "timescaledb.name" -}}
{{- default "timescaledb" .Chart.Name -}}
{{- end -}}


{{- define "timescaledb.fullname" -}}
{{- printf "%s" (include "timescaledb.name" .) -}}
{{- end -}}