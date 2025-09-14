{ lib, stdenv, fetchurl, makeWrapper, unzip, binutils, gcc, glibc, openssl, patchelf }:

stdenv.mkDerivation rec {
  pname = "cangjie";
  version = "1.0.1";

  src =
    let
      getArch =
        {
          "aarch64-darwin" = "darwin_aarch64";
          "aarch64-linux" = "linux_aarch64";
          "x86_64-linux" = "linux_x64";
        }
        .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

      getUrl =
        {
          "aarch64-darwin" = "https://github.com/gtn1024/cangjie-distribution/releases/download/v${version}/cangjie-sdk-mac-aarch64-${version}.tar.gz";
          "aarch64-linux" = "https://github.com/gtn1024/cangjie-distribution/releases/download/v${version}/cangjie-sdk-linux-aarch64-${version}.tar.gz";
          "x86_64-linux" = "https://github.com/gtn1024/cangjie-distribution/releases/download/v${version}/cangjie-sdk-linux-x64-${version}.tar.gz";
        }
        .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

      getHash =
        arch:
        {
          "darwin_aarch64" = "4c332718699d91bb37a8ef552b123279ac260ab6da75afd81a00e2e1bff71b5c";
          "linux_aarch64" = "dbc11eedb6ff60d846c8d3d12776cb461086127302e4d9e375f16054a6c92eec";
          "linux_x64" = "b0046ef76beb5df9a515e5b37f700e88f2b20413fddb3694c2d6ab4860497a3f";
        }
        .${arch};
    in
    fetchurl {
      url = getUrl;
      sha256 = getHash getArch;
    };

  nativeBuildInputs = [ makeWrapper binutils gcc patchelf ];

  buildInputs = [
    glibc
    openssl
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    mkdir -p $out
    mv * $out
  '';

  postFixup =
    let
      libraryPath = lib.makeLibraryPath [ glibc openssl stdenv.cc.cc.lib ];
      interpreter = {
        "x86_64-linux" = "${glibc}/lib/ld-linux-x86-64.so.2";
        "aarch64-linux" = "${glibc}/lib/ld-linux-aarch64.so.1";
      }.${stdenv.system};

      # Get the GCC toolchain path for C runtime files
      gccVersion = stdenv.cc.cc.version;
      gccLib = "${stdenv.cc.cc}/lib/gcc/${stdenv.targetPlatform.config}/${gccVersion}";
      toolchainPaths = [
        gccLib                  # Contains crtbeginS.o, crtendS.o
        "${glibc}/lib"         # Contains Scrt1.o, crti.o, crtn.o
      ];
      librarySearchPaths = [
        "${glibc}/lib"         # Contains libc.so, libm.so
        "${stdenv.cc.cc.lib}/lib"  # Contains libgcc_s.so and other gcc libs
      ];
    in ''
      patchelf \
        --set-interpreter "${interpreter}" \
        --set-rpath "${libraryPath}" \
        $out/bin/cjc

      # Create a wrapper script that automatically passes toolchain paths
      mv $out/bin/cjc $out/bin/.cjc-unwrapped
      cat > $out/bin/cjc <<EOF
#!/bin/sh
exec $out/bin/.cjc-unwrapped ${lib.concatMapStringsSep " " (path: "-B${path}") toolchainPaths} ${lib.concatMapStringsSep " " (path: "-L${path}") librarySearchPaths} "\$@"
EOF
      chmod +x $out/bin/cjc
    '';

  meta = {
    homepage = "https://cangjie-lang.cn/";
    description = "Cangjie compiler";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ gtn1024 ];
    platforms = lib.platforms.linux;
    outputsToInstall = [ "out" ];
  };
}
