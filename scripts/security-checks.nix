# nix eval --impure --json --file scripts/security-checks.nix summary
# nix build --impure --no-link --file scripts/security-checks.nix ca nginx
let
  source = builtins.path {
    path = ../.;
    filter = path: _: !(builtins.elem (baseNameOf path) [
      ".git" ".worktrees" ".superpowers" "result" "__pycache__"
    ]);
  };
  flake = builtins.getFlake (builtins.unsafeDiscardStringContext (toString source));
  host = flake.nixosConfigurations.laeradr;
  c = host.config;
  lib = host.pkgs.lib;
  apps = lib.attrValues c.virtualisation.oci-containers.containers;
  sites = lib.filterAttrs (name: _: name != "files-lan") c.services.nginx.virtualHosts;
  deployFixture = host.pkgs.writeShellScript "ci-deploy-fixture" (
    lib.replaceStrings
      [ "/tank/ci/publish/requests/gifs.digest" ]
      [ "$TEST_REQUEST" ]
      c.systemd.services.sccl-deploy-gifs.script
  );
  fakeDocker = host.pkgs.writeShellScriptBin "docker" ''
    printf 'docker %s\n' "$*" >> "$TEST_LOG"
    if [[ "''${FAIL_PULL:-0}" == 1 && "$1" == pull ]]; then exit 1; fi
  '';
  fakeSystemctl = host.pkgs.writeShellScriptBin "systemctl" ''
    printf 'systemctl %s\n' "$*" >> "$TEST_LOG"
  '';
  invariants =
    assert lib.assertMsg (lib.versionAtLeast c.boot.kernelPackages.kernel.version "6.18.57") "Unpatched kernel";
    assert lib.assertMsg (lib.all (ct: !(builtins.hasAttr "/run/secrets" ct.bindMounts)) (lib.attrValues c.containers)) "Broad container secret mount";
    assert lib.assertMsg (lib.all (app: app.user != null && app.user != "root" && !(builtins.elem "--network=host" app.extraOptions)) apps) "Privileged OCI application";
    assert lib.assertMsg (lib.all (app: lib.all (port: lib.hasPrefix "127.0.0.1:" port) app.ports) apps) "Public OCI backend";
    assert lib.assertMsg (lib.all (vhost: !vhost.addSSL) (lib.attrValues sites)) "Optional HTTPS remains";
    assert lib.assertMsg (c.systemd.services.forgejo-runner.serviceConfig.User == "forgejo-ci") "Runner has production identity";
    assert lib.assertMsg (!c.services.openssh.settings.KbdInteractiveAuthentication) "Interactive SSH enabled";
    true;
in {
  summary = assert invariants; {
    kernel = c.boot.kernelPackages.kernel.version;
    kanidm = c.services.kanidm.package.version;
    migrationVersions = lib.mapAttrs (_: stage: stage.configuration.services.kanidm.package.version) c.specialisation;
    failedAssertions = builtins.filter (a: !a.assertion) c.assertions;
    runnerUser = c.systemd.services.forgejo-runner.serviceConfig.User;
    runnerDocker = c.systemd.services.forgejo-runner.environment.DOCKER_HOST;
    deployPaths = lib.mapAttrs (_: path: path.pathConfig) c.systemd.paths;
    networkReadiness = {
      inherit (c.networking.dhcpcd) persistent wait allowInterfaces;
      services = lib.genAttrs [ "sshd" "nginx" ] (name: {
        inherit (c.systemd.services.${name}) after wants startLimitIntervalSec;
      });
    };
    oci = lib.mapAttrs (_: app: { inherit (app) user ports extraOptions; }) c.virtualisation.oci-containers.containers;
    containerCA = lib.mapAttrs (_: ct: toString ct.config.security.pki.caBundle) c.containers;
  };
  system = assert invariants; c.system.build.toplevel;
  ca = host.pkgs.runCommand "sccl-ca-bundle-check" { bundle = c.security.pki.caBundle; } ''
    mkdir -p "$out"
    cp "$bundle" "$out/ca-bundle.crt"
  '';
  nginx = host.pkgs.writeText "nginx-security-check-command" c.systemd.services.nginx.serviceConfig.ExecStart;
  bridge = c.services.mautrix-discord.package;
  ciDeploy = host.pkgs.runCommand "check-ci-digest-deploy" {
    nativeBuildInputs = [ fakeDocker fakeSystemctl host.pkgs.coreutils host.pkgs.diffutils ];
  } ''
    export STATE_DIRECTORY="$TMPDIR/state"
    export TEST_REQUEST="$TMPDIR/request"
    export TEST_LOG="$TMPDIR/actions"
    mkdir -p "$STATE_DIRECTORY"

    ${deployFixture}
    test ! -s "$TEST_LOG"

    printf 'not-a-digest\n' > "$TEST_REQUEST"
    result=0
    ${deployFixture} || result=$?
    test "$result" = 2
    test ! -s "$TEST_LOG"

    digest="sha256:$(printf '%064d' 0)"
    printf '%s\n' "$digest" > "$TMPDIR/link-target"
    rm "$TEST_REQUEST"
    ln -s "$TMPDIR/link-target" "$TEST_REQUEST"
    result=0
    ${deployFixture} || result=$?
    test "$result" = 2
    test ! -s "$TEST_LOG"

    rm "$TEST_REQUEST"
    mkfifo "$TEST_REQUEST"
    result=0
    ${deployFixture} || result=$?
    test "$result" = 2
    test ! -s "$TEST_LOG"

    rm "$TEST_REQUEST"
    printf '%s\n--privileged\n' "$digest" > "$TEST_REQUEST"
    result=0
    ${deployFixture} || result=$?
    test "$result" = 2
    test ! -s "$TEST_LOG"

    printf '%s\n' "$digest" > "$TEST_REQUEST"
    FAIL_PULL=1 ${deployFixture} && exit 1
    test ! -e "$STATE_DIRECTORY/digest"
    printf 'docker pull 10.69.0.17:5000/scclie/gif@%s\n' "$digest" > "$TMPDIR/expected"
    cmp "$TEST_LOG" "$TMPDIR/expected"

    : > "$TEST_LOG"
    ${deployFixture}
    printf 'docker pull 10.69.0.17:5000/scclie/gif@%s\ndocker tag 10.69.0.17:5000/scclie/gif@%s 10.69.0.17:5000/scclie/gif:main\nsystemctl restart docker-gifs.service\n' "$digest" "$digest" > "$TMPDIR/expected"
    cmp "$TEST_LOG" "$TMPDIR/expected"
    test "$(cat "$STATE_DIRECTORY/digest")" = "$digest"

    ${deployFixture}
    cmp "$TEST_LOG" "$TMPDIR/expected"
    touch "$out"
  '';
}
