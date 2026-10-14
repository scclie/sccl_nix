{ pkgs, ... }:
let
  voice-dictate = pkgs.writeShellApplication {
    name = "voice-dictate";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      pipewire
      systemd
      whisper-cpp
      wtype
    ];
    text = ''
      set -euo pipefail

      unit="voice-dictate-record.service"
      state_dir="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/voice-dictation"
      audio_file="$state_dir/input.wav"
      data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/whisper-cpp"
      model_file="$data_dir/ggml-small.bin"
      model_ready_file="$data_dir/.ggml-small.bin.ready"

      notify() {
        notify-send "$@" >/dev/null 2>&1 || true
      }

      fail() {
        notify --urgency=critical "voice dict" "$1"
        printf '%s\n' "voice dict: $1" >&2
        exit 1
      }

      if systemctl --user is-active --quiet "$unit"; then
        notify "voice dict" "stopping recording…"

        systemctl --user kill --signal=INT "$unit" || fail "unable to stop recording."
        for _ in $(seq 1 50); do
          systemctl --user is-active --quiet "$unit" || break
          sleep 0.1
        done
        systemctl --user is-active --quiet "$unit" && fail "recording did not stop."

        [ -s "$audio_file" ] || fail "no audio was recorded."

        if [ ! -s "$model_file" ] || [ ! -f "$model_ready_file" ]; then
          mkdir -p "$data_dir"
          rm -f "$model_file" "$model_ready_file"
          notify "voice dict" "downloading the model"
          (
            cd "$data_dir"
            whisper-cpp-download-ggml-model small
          ) || fail "unable to download the model."
          [ -s "$model_file" ] || fail "the downloaded model is empty."
          touch "$model_ready_file"
        fi

        notify "voice dict" "recognising speech…"
        text="$(whisper-cli -np -nt -l ru -m "$model_file" -f "$audio_file" 2>/dev/null)" \
          || fail "speech recognition failed."
        text="$(printf '%s\n' "$text" | sed '/^[[:space:]]*$/d')"

        [ -n "$text" ] || fail "no speech"

        printf '%s' "$text" | wtype -d 10 - || fail "unable to type"
        notify "voice dict" "text typed"
      else
        mkdir -p "$state_dir"
        rm -f "$audio_file"

        systemd-run --user --unit=voice-dictate-record --collect --quiet \
          pw-record --rate 16000 --channels 1 --format s16 "$audio_file" \
          || fail "unable to start microphone recording."
        notify "voice dict" "recording started"
      fi
    '';
  };
in {
  home.packages = [ voice-dictate ];
}
