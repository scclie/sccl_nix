{ pkgs, prompp }:
{
  monitoring-alerts = pkgs.runCommand "monitoring-alerts-check" {
    nativeBuildInputs = [ prompp ];
  } ''
    cp ${./alerts.yml} alerts.yml
    cp ${./alerts.test.yml} alerts.test.yml
    promtool check rules alerts.yml
    promtool test rules alerts.test.yml
    touch "$out"
  '';

}
