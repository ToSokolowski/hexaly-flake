{
  description = "Hexaly Optimizer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});
  in {
    packages = forAllSystems (system: {
      default = let
        pkgs = nixpkgsFor.${system};
      in
        pkgs.stdenv.mkDerivation {
          pname = "hexaly-optimizer";
          version = "14.5";

          # Download from the web
          src = pkgs.fetchurl {
            url = "https://www.hexaly.com/downloads/14_5_20260417/Hexaly_14_5_20260417_Linux64.run";
            # You must provide the correct hash for this specific file
            hash = "sha256-6KQM+nXlI3CQSn5Rav77IW3h6RYksPDg/0GoUCj0yyg=";
          };

          nativeBuildInputs = [pkgs.autoPatchelfHook];

          buildInputs = [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];

          unpackPhase = ''
            # The downloaded file is in the Nix store.
            # We run it with 'sh' to extract it.
            sh $src --target source --noroot --nointeractive
            cd source
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib $out/opt/hexaly
            cp -r . $out/opt/hexaly
            ln -s $out/opt/hexaly/bin/hexaly $out/bin/hexaly
            cp -r lib/* $out/lib/ || true
          '';

          meta = {
            description = "Hexaly Optimizer";
            homepage = "https://www.hexaly.com/";
            platforms = ["x86_64-linux" "aarch64-linux"];
          };
        };
    });

    # The NixOS Module remains here so you can use it in your system config
    nixosModules.hexaly = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.programs.hexaly;
    in {
      options.programs.hexaly = {
        enable = lib.mkEnableOption "Hexaly Optimizer";
        licensePath = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to your license.dat file.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          (
            if cfg.licensePath != null
            then
              self.packages.${pkgs.system}.default.overrideAttrs (old: {
                postInstall =
                  (old.postInstall or "")
                  + ''
                    cp ${cfg.licensePath} $out/opt/hexaly/license.dat
                  '';
              })
            else self.packages.${pkgs.system}.default
          )
        ];

        environment.variables = lib.mkIf (cfg.licensePath != null) {
          HX_LICENSE_PATH = "${cfg.licensePath}";
        };
      };
    };
  };
}
