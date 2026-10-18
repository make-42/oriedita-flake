{
  description = "Oriedita – origami crease pattern editor and folding simulator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      jdk = pkgs.jdk17;
      meta' = builtins.fromJSON (builtins.readFile ./version.json);

      # Native libs needed by AWT/Swing at runtime
      runtimeLibs = with pkgs; [
        libx11
        libxext
        libxi
        libxrender
        libxtst
        libxxf86vm
        libGL
        fontconfig
        freetype
        gtk3
        glib
      ];

      oriedita = pkgs.maven.buildMavenPackage rec {
        pname = "oriedita";
        version = meta'.version;

        src = pkgs.fetchFromGitHub {
          owner = "oriedita";
          repo = "oriedita";
          rev = "v${version}";
          hash = meta'.srcHash;
        };

        mvnHash = meta'.mvnHash;
        mvnParameters = "-DskipTests";

        nativeBuildInputs = [pkgs.makeWrapper pkgs.copyDesktopItems];

        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "oriedita";
            desktopName = "Oriedita";
            comment = "Origami crease pattern editor and folding simulator";
            exec = "oriedita %f";
            categories = ["Graphics" "Education"];
            mimeTypes = ["application/x-oriedita"];
            terminal = false;
          })
        ];

        installPhase = ''
          runHook preInstall

          # Pick the runnable (shaded) jar produced by the app module.
          jar=$(find oriedita/target -maxdepth 1 -name 'oriedita*.jar' \
                  ! -name '*-sources.jar' ! -name '*-javadoc.jar' \
                  ! -name 'original-*' -printf '%s %p\n' \
                | sort -rn | head -n1 | cut -d' ' -f2-)

          if [ -z "$jar" ]; then
            echo "Could not find the built oriedita jar" >&2
            find . -name '*.jar' >&2
            exit 1
          fi

          install -Dm644 "$jar" $out/share/oriedita/oriedita.jar

          makeWrapper ${jdk}/bin/java $out/bin/oriedita \
            --add-flags "-jar $out/share/oriedita/oriedita.jar" \
            --set-default _JAVA_AWT_WM_NONREPARENTING 1 \
            --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs} \
            --prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name} \
            --prefix XDG_DATA_DIRS : ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Origami crease pattern editor and folding simulator (fork of Orihime)";
          homepage = "https://oriedita.github.io";
          license = licenses.mit; # verify against LICENSE.md
          mainProgram = "oriedita";
          platforms = platforms.linux;
        };
      };
    in {
      packages = {
        inherit oriedita;
        default = oriedita;
      };

      apps.default = flake-utils.lib.mkApp {drv = oriedita;};

      devShells.default = pkgs.mkShell {
        packages = [jdk pkgs.maven];
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;
        shellHook = ''
          export XDG_DATA_DIRS="${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:$XDG_DATA_DIRS"
        '';
      };
    });
}
