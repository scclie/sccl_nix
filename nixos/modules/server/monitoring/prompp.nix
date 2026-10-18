{ lib, stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "prompp";
  version = "0.8.16";

  src = fetchurl {
    url = "https://github.com/deckhouse/prompp/releases/download/v${finalAttrs.version}/prompp-binaries-amd64.tar.gz";
    hash = "sha256-AK6bePPzf5tZhNHhs/pnd2ig3INbhzJgVrZMcXFfgE8=";
  };

  sourceRoot = ".";
  # static binas
  dontPatchELF = true;
  dontStrip = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 prompp promtool prompptool -t "$out/bin"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/prompp" --version
    "$out/bin/promtool" --version
    "$out/bin/prompptool" --help > /dev/null
    runHook postInstallCheck
  '';

  passthru.cli = finalAttrs.finalPackage;

  meta = {
    description = "prom++ server and tools";
    homepage = "https://github.com/deckhouse/prompp";
    license = lib.licenses.asl20;
    mainProgram = "prompp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
