{ lib, stdenv, fetchurl, makeWrapper, unzip, binutils, gcc, glibc, openssl, patchelf }:

stdenv.mkDerivation rec {
  pname = "cangjie";
  version = "0.53.13";

  src =
    let
      getArch =
        {
          "aarch64-darwin" = "darwin_aarch64";
          "x86_64-darwin" = "darwin_x64";
          "aarch64-linux" = "linux_aarch64";
          "x86_64-linux" = "linux_x64";
        }
        .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

      getUrl =
        {
          "aarch64-darwin" = "https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=Cangjie-0.53.13-darwin_aarch64.tar.gz&objectKey=6719f1b33af6947e3c6af322";
          "x86_64-darwin" = "https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=Cangjie-0.53.13-darwin_x64.tar.gz&objectKey=6719f1c13af6947e3c6af325";
          "aarch64-linux" = "https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=Cangjie-0.53.13-linux_aarch64.tar.gz&objectKey=6719f1ec3af6947e3c6af328";
          "x86_64-linux" = "https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=Cangjie-0.53.13-linux_x64.tar.gz&objectKey=6719f1eb3af6947e3c6af327";
        }
        .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

      getHash =
        arch:
        {
          "darwin_aarch64" = "sha256-k9DL++MY9qcUo3u8w3B+AHDoMPNbhcIo6S01j2jKKMY=";
          "darwin_x64" = "sha256-zOaS1+M481R9KDzWj7Ke3IqwdHysfmp3AkUvq/qmuRg=";
          "linux_aarch64" = "sha256-m0AntvtN/8NNmLJqrjD1EymjLuQjt63B01NJqux0/5o=";
          "linux_x64" = "sha256-s8AIfbJgBfYxZ2f9fMv8QPchz9LQkvlL85piHH2R+7s=";
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
    in ''
      patchelf \
        --set-interpreter "${interpreter}" \
        --set-rpath "${libraryPath}" \
        $out/bin/cjc

      wrapProgram $out/bin/cjc
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
