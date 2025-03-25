{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    ...
  } @ inputs: let
    systems = [
      "aarch64-darwin"
    ];

    inherit (self.lib) makeOverridable;

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    lib = inputs.nixpkgs.lib.extend (
      _: _: {
        # Custom libs here
      }
    );

    devShells =
      forAllSystems
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-unstable = import inputs.nixpkgs-unstable {system = pkgs.stdenv.system;};

        defaultPackages = with pkgs; [
          just
          yq
          pre-commit
        ];
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = defaultPackages;
            }
          ];
        };

        devops = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = with pkgs;
                [
                  colima
                  azure-cli
                  kubectl
                  k9s
                  kubectx
                  fluxcd
                  terraform
                ]
                ++ defaultPackages;

              # NOTE: You may need to install azure-cli and kubectl with Homebrew

              dotenv.enable = true;

              git-hooks.hooks = {
                actionlint.enable = true;
                check-toml.enable = true;
                check-yaml.enable = true;
                check-json.enable = true;
                shellcheck.enable = true;
              };
            }
          ];
        };
        python = makeOverridable devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = with pkgs;
                [
                  ruff
                  pkgs-unstable.uv
                ]
                ++ defaultPackages;

              languages.python = {
                uv.enable = true;
                uv.package = pkgs-unstable.uv;
                uv.sync.enable = true;
              };
            }
          ];
        };
        python-django = self.devShells."${system}".python.override {
          modules = [
            {
              packages = [pkgs-unstable.lazysql];
            }
          ];
        };
      });
  };
}
