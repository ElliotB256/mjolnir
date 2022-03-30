{
   description = "ThorLabs camera viewer";

   inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-21.11;
   inputs.sipyco.url = github:m-labs/sipyco;
   inputs.sipyco.inputs.nixpkgs.follows = "nixpkgs";
   inputs.thorlabs-tsi-sdk.url = git+https://gitlab.com/aion-physics/code/artiq/drivers/thorlabs-tsi-sdk;
   inputs.thorlabs-tsi-sdk.inputs.nixpkgs.follows = "nixpkgs";

   outputs = { self, nixpkgs, sipyco, thorlabs-tsi-sdk }:
      let
         pkgs = import nixpkgs { system = "x86_64-linux"; };
      in rec {

      packages.x86_64-linux.pyzmq = pkgs.python3Packages.buildPythonPackage rec {
         pname = "pyzmq";
         version = "22.3.0";
         src = pkgs.python3Packages.fetchPypi {
            pname = "pyzmq";
            inherit version;
            sha256 = "8eddc033e716f8c91c6a2112f0a8ebc5e00532b4a6ae1eb0ccc48e027f9c671c";
         };
         doCheck = false;
         propagatedBuildInputs = with pkgs.python3Packages; [ packaging pyparsing ];
      };

      packages.x86_64-linux.mjolnir = pkgs.python3Packages.buildPythonPackage rec {
         pname = "mjolnir";
         version = "0.2";
         src = self;
         nativeBuildInputs = [ pkgs.qt5.wrapQtAppsHook ];
         propagatedBuildInputs = with pkgs.python3Packages; [ 
            numpy
            distro
            scipy
            packages.x86_64-linux.pyzmq
            pyqt5
            pyqtgraph
            quamash
            sipyco.packages.x86_64-linux.sipyco
            thorlabs-tsi-sdk.packages.x86_64-linux.thorlabs-tsi
         ];
         dontWrapQtApps = true;
         postFixup = ''
            wrapQtApp "$out/bin/mjolnir_gui"
         '';
      };

      devShell.x86_64-linux = pkgs.mkShell {
         name = "mjolnir-dev-shell";
         packages = [ 
            pkgs.stdenv.cc.cc.lib 
         ];
         buildInputs = [
            pkgs.stdenv.cc.cc.lib
            (pkgs.python3.withPackages(ps: [ packages.x86_64-linux.mjolnir ]))
         ];
         shellHook = ''
            echo Entering mjolnir-dev-shell...
            # fixes libstdc++ issues
            export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib/:${thorlabs-tsi-sdk}/lib
            echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
         '';
      };
   };
}


