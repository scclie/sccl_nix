{ pkgs, ... }:

let
  prettierFormatter = {
    command = "prettier";
    args = [ "--stdin-filepath" "%{buffer_name}" ];
  };
  webLanguage = name: servers: {
    inherit name;
    language-servers = servers;
    formatter = prettierFormatter;
  };
in

{
  stylix.targets.helix.enable = false;

  programs.helix = {
    enable = true;
    defaultEditor = true;

    # Config/markup tools only; code toolchains and their LSPs come from PATH.
    extraPackages = with pkgs; [
      taplo
      markdown-oxide
      yaml-language-server
      vscode-langservers-extracted
      prettier
      nixfmt
    ];

    settings = {
      theme = "base16_terminal";
      editor = {
        line-number = "relative";
        cursorline = true;
        bufferline = "multiple";
        auto-format = false;
        completion-timeout = 100;
        popup-border = "all";
        gutters = [ "diagnostics" "spacer" "diff" "line-numbers" "spacer" ];
        indent-guides.render = true;
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
        statusline = {
          left = [ "mode" "spinner" "file-name" "read-only-indicator" "file-modification-indicator" ];
          right = [ "diagnostics" "version-control" "position" "file-type" ];
        };
        inline-diagnostics.cursor-line = "warning";
        end-of-line-diagnostics = "hint";
        file-picker.hidden = false;
      };
    };

    ignores = [
      ".git/"
      "node_modules/"
      "target/"
      "build/"
      "dist/"
      ".gradle/"
      ".zig-cache/"
      "zig-cache/"
      "zig-out/"
      ".venv/"
      "venv/"
      ".next/"
      ".godot/"
      "bin/"
      "obj/"
    ];

    languages = {
      language-server = {
        jdtls.timeout = 120;
        basedpyright.config.basedpyright.analysis = {
          typeCheckingMode = "basic";
          diagnosticMode = "openFilesOnly";
        };
        yaml-language-server.config.yaml = {
          schemaStore.enable = true;
          validate = true;
          format.enable = true;
        };
        lemminx.command = "lemminx";
        sqls.command = "sqls";
        godot = {
          command = "nc";
          args = [ "127.0.0.1" "6005" ];
        };
      };

      language = [
        {
          name = "java";
          language-servers = [ "jdtls" ];
        }
        {
          name = "zig";
          language-servers = [ "zls" ];
          formatter = { command = "zig"; args = [ "fmt" "--stdin" ]; };
        }
        (webLanguage "javascript" [ "typescript-language-server" ])
        (webLanguage "jsx" [ "typescript-language-server" ])
        (webLanguage "typescript" [ "typescript-language-server" ])
        (webLanguage "tsx" [ "typescript-language-server" ])
        (webLanguage "html" [ "vscode-html-language-server" ])
        (webLanguage "css" [ "vscode-css-language-server" ])
        (webLanguage "scss" [ "vscode-css-language-server" ])
        (webLanguage "json" [ "vscode-json-language-server" ])
        (webLanguage "jsonc" [ "vscode-json-language-server" ])
        (webLanguage "yaml" [ "yaml-language-server" ])
        {
          name = "nix";
          language-servers = [ "nixd" ];
          formatter.command = "nixfmt";
        }
        {
          name = "rust";
          language-servers = [ "rust-analyzer" ];
        }
        {
          name = "python";
          language-servers = [
            "basedpyright"
            { name = "ruff"; except-features = [ "hover" ]; }
          ];
          formatter = { command = "ruff"; args = [ "format" "--stdin-filename" "%{buffer_name}" "-" ]; };
        }
        {
          name = "c";
          language-servers = [ "clangd" ];
        }
        {
          name = "cpp";
          language-servers = [ "clangd" ];
        }
        {
          name = "c-sharp";
          language-servers = [ "csharp-ls" ];
        }
        {
          name = "kotlin";
          language-servers = [ "kotlin-language-server" ];
        }
        {
          name = "xml";
          language-servers = [ "lemminx" ];
        }
        {
          name = "toml";
          language-servers = [ "taplo" ];
          formatter = { command = "taplo"; args = [ "format" "-" ]; };
        }
        (webLanguage "markdown" [ "markdown-oxide" ])
        {
          name = "bash";
          language-servers = [ "bash-language-server" ];
          formatter = { command = "shfmt"; args = [ "-filename" "%{buffer_name}" ]; };
        }
        {
          name = "dockerfile";
          language-servers = [ "docker-langserver" ];
        }
        {
          name = "sql";
          language-servers = [ "sqls" ];
          formatter = { command = "sql-formatter"; args = [ "--language" "postgresql" ]; };
        }
        {
          name = "gdscript";
          language-servers = [ "godot" ];
        }
      ];
    };
  };
}
