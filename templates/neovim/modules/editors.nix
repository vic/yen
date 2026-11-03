# An editor is a Neovim variant: its theme and the languages it supports are data. Its `nvf` sink collects the nvf
# modules that the aspects give, and builds two packages: the terminal editor, and the same editor in neovide.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  yen.kinds.fleet = {
    spawns.editor = _: yen.editor;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.kinds.editor = {
    fields = {
      theme = yen.lib.str; # an nvf theme: tokyonight, catppuccin, gruvbox, rose-pine, …
      style = yen.lib.str; # the theme's style: night, mocha, dark, …
      languages = yen.lib.listOf yen.lib.str; # nvf languages: go, nix, typescript, css, markdown, …
    };
    sinks.nvf.out =
      { editor, nvf, ... }:
      let
        neovim =
          (inputs.nvf.lib.neovimConfiguration {
            inherit pkgs;
            modules = nvf;
          }).neovim;
      in
      {
        packages.x86_64-linux = {
          ${editor.name} = neovim;
          # neovide runs this variant's nvim: $NEOVIM_BIN
          "${editor.name}-gui" = pkgs.writeShellScriptBin "neovide-${editor.name}" ''
            NEOVIM_BIN=${neovim}/bin/nvim exec ${pkgs.neovide}/bin/neovide "$@"
          '';
        };
      };
  };

  # every variant: its theme, and the languages it lists
  yen.aspects.theme = {
    at = yen.kinds.editor;
    nvf =
      { editor, ... }:
      {
        config.vim.theme = {
          enable = true;
          name = editor.theme;
          inherit (editor) style;
        };
      };
  };
  yen.aspects.languages = {
    at = yen.kinds.editor;
    nvf =
      { editor, ... }:
      {
        config.vim.languages = lib.genAttrs editor.languages (_: {
          enable = true;
        });
      };
  };
  # what every variant shares
  yen.aspects.common = {
    at = yen.kinds.editor;
    nvf.config.vim = {
      lsp.enable = true;
      treesitter.enable = true;
      statusline.lualine.enable = true;
      telescope.enable = true;
    };
  };
}
