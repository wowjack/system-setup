{
  # Home Manager owns ~/.bashrc and ~/.profile; add shell customisation here.
  programs.bash.enable = true;

  # direnv loads a project's environment when you cd into it. With nix-direnv, a
  # project's `.envrc` containing `use flake` gives you that project's devShell
  # (its own compilers, language servers, etc.) and caches it so it survives
  # garbage collection. Run `direnv allow` once per project to trust its .envrc.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
