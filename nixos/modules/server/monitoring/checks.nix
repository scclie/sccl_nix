{ pkgs, prompp, dashboards }:
let
  config = pkgs.writeText "prompp-check.yml" (builtins.toJSON {
    global.scrape_interval = "1s";
    scrape_configs = [{
      job_name = "prometheus";
      static_configs = [{ targets = [ "127.0.0.1:19090" ]; }];
    }];
  });
in {
  monitoring-alerts = pkgs.runCommand "monitoring-alerts-check" {
    nativeBuildInputs = [ prompp ];
  } ''
    cp ${./alerts.yml} alerts.yml
    cp ${./alerts.test.yml} alerts.test.yml
    promtool check rules alerts.yml
    promtool test rules alerts.test.yml
    touch "$out"
  '';

  monitoring-dashboard = pkgs.runCommand "monitoring-dashboard-check" {
    nativeBuildInputs = [ prompp pkgs.curl pkgs.jq ];
  } ''
    prompp --config.file=${config} --web.listen-address=127.0.0.1:19090 \
      --storage.tsdb.path="$TMPDIR/data" --storage.tsdb.retention.time=365d \
      --storage.tsdb.retention.size=40GB > server.log 2>&1 &
    pid=$!
    trap 'kill "$pid"; wait "$pid" || true' EXIT
    curl -fsS --retry 20 --retry-delay 1 --retry-connrefused \
      http://127.0.0.1:19090/-/ready

    jq -r '.panels[].targets[].expr
      | gsub("\\$__rate_interval"; "1m")
      | gsub("\\$(instance|disk|interface|mountpoint)"; ".+")' \
      ${dashboards}/host.json | while IFS= read -r expr; do
        promtool --experimental promql format "$expr" > /dev/null
      done

    query() {
      curl -fsSG http://127.0.0.1:19090/api/v1/query --data-urlencode "query=$1"
    }
    for attempt in $(seq 1 30); do
      if query 'rate(prometheus_tsdb_head_samples_appended_total{job="prometheus"}[1m])' \
        | jq -e '.data.result | length > 0' > /dev/null; then
        break
      fi
      sleep 1
    done
    jq -r '.panels[].targets[].expr | select(contains("job=\"prometheus\""))
      | gsub("\\$__rate_interval"; "1m")' ${dashboards}/host.json \
      | while IFS= read -r expr; do
          query "$expr" | jq -e '.status == "success" and (.data.result | length > 0)'
        done
    curl -fsS http://127.0.0.1:19090/api/v1/status/flags \
      | jq -e '.data["storage.tsdb.retention.time"] == "1y"
        and .data["storage.tsdb.retention.size"] == "40GiB"'
    touch "$out"
  '';
}
