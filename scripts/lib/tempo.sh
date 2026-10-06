# Plumbing, not a lesson: sourced by the tracing scripts, which run in the lab
# box and ask Tempo (tempo:3200, monitoring profile) for traces.

# new_traceparent: a made-up W3C traceparent, sampled: version 00, a random
# 32-hex-digit trace id, a random 16-hex-digit parent span id, flags 01.
new_traceparent() {
  echo "00-$(openssl rand -hex 16)-$(openssl rand -hex 8)-${1:-01}"
}

# trace_id <traceparent>: the trace id inside it.
trace_id() { echo "$1" | cut -d- -f2; }

# tempo_trace <trace id>: the trace as Tempo's JSON, or nothing (404) when
# Tempo has no span with that trace id.
tempo_trace() {
  curl -sS --fail http://tempo:3200/api/traces/"$1" 2>/dev/null || true
}

# span_count <trace id>: how many spans Tempo has for the trace so far.
span_count() {
  local count
  count=$(tempo_trace "$1" | jq '[.batches[]?.scopeSpans[].spans[]] | length' 2>/dev/null || true)
  echo "${count:-0}"
}

# span_id_base64 <16 hex digits>: a span id the way Tempo's JSON writes it.
span_id_base64() {
  printf "$(echo "$1" | sed 's/../\\x&/g')" | base64
}

# wait_for_spans <trace id> <at least>: until Tempo has that many spans for
# the trace and the count has stopped growing (spans arrive in batches).
wait_for_spans() {
  local last=-1 now
  for _ in $(seq 60); do
    now=$(span_count "$1")
    [ "$now" -ge "$2" ] && [ "$now" = "$last" ] && return 0
    last=$now
    sleep 2
  done
  echo "Tempo has $now spans for trace $1, expected at least $2" >&2
  return 1
}

# print_trace_tree <trace id>: one line per span, indented under its parent,
# as "<service>: <span name>". The SQL commands under a span are counted on
# its line instead of printed one by one. Spans with the same parent are
# sorted by service and name: some of them start at the same moment.
print_trace_tree() {
  tempo_trace "$1" | jq -r '
    [ .batches[]
      | (.resource.attributes[] | select(.key == "service.name") | .value.stringValue) as $service
      | .scopeSpans[] | .scope.name as $scope | .spans[]
      | { id: .spanId, parent: (.parentSpanId // ""), service: $service, name, sql: ($scope == "Npgsql") } ]
    as $spans
    | ($spans | map(.id)) as $ids
    | def children($id): $spans | map(select(.parent == $id and (.sql | not))) | sort_by(.service, .name);
      def sql_count($id): $spans | map(select(.parent == $id and .sql)) | length;
      def tree($span; $depth):
        ("  " * $depth) + $span.service + ": " + $span.name
          + (sql_count($span.id) as $n | if $n > 0 then "  (\($n) SQL)" else "" end),
        (children($span.id)[] | tree(.; $depth + 1));
      $spans | map(select((.parent as $p | $ids | index($p)) | not)) | sort_by(.service, .name)
      | .[] | tree(.; 0)'
}
