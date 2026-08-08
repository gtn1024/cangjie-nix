{ lib, stdenv, fetchurl, makeWrapper, pkgs, unzip, binutils, gcc, glibc, openssl, patchelf }:

stdenv.mkDerivation rec {
  pname = "cangjie";
  version = "1.0.5";

  src =
    let
      getArch =
        {
          "x86_64-linux" = "linux_x64";
        }
        .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

      getUrl =
        {
          "x86_64-linux" = "https://gitcode.com/gtn1024/cangjie-distribution/releases/download/v${version}/cangjie-sdk-linux-x64-${version}.tar.gz";
        }
        .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

      getHash =
        arch:
        {
          "linux_x64" = "bacad84df8e0281c5395bab4c40e481e3ea6cc712eed5c953903b0d561a14562";
        }
        .${arch};
    in
    fetchurl {
      url = getUrl;
      sha256 = getHash getArch;
    };

  nativeBuildInputs = [ makeWrapper binutils.bintools gcc patchelf ];

  buildInputs = [
    binutils.bintools
    glibc
    openssl
    stdenv.cc.cc.lib
    # Add additional runtime libraries that might be needed
    gcc.cc.lib
  ];

  installPhase = ''
    mkdir -p $out
    mv * $out

    # Create lib directory and symlink ld-linux-x86-64.so.2
    mkdir -p $out/lib
    ${if stdenv.system == "x86_64-linux" then ''
      ln -s ${glibc}/lib/ld-linux-x86-64.so.2 $out/lib/
      ln -s ${stdenv.cc.cc.lib}/lib/libstdc++.so.6 $out/lib/
    '' else if stdenv.system == "aarch64-linux" then ''
      ln -s ${glibc}/lib/ld-linux-aarch64.so.1 $out/lib/
      ln -s ${stdenv.cc.cc.lib}/lib/libstdc++.so.6 $out/lib/
    '' else ""}
  '';

  postFixup =
    let
      # Include LLVM library paths from the distribution itself
      llvmLibPath = "$out/third_party/llvm/lib";
      libraryPath = lib.makeLibraryPath [ glibc openssl stdenv.cc.cc.lib gcc.cc.lib ] + ":${llvmLibPath}";
      interpreter = {
        "x86_64-linux" = "${glibc}/lib/ld-linux-x86-64.so.2";
        "aarch64-linux" = "${glibc}/lib/ld-linux-aarch64.so.1";
      }.${stdenv.system};

      # Use sysroot approach combined with explicit binary tool paths
      sysroot = stdenv.cc.cc;
      # Cangjie needs explicit paths to find ar, ld and other binutils
      binPath = "${binutils.bintools}/bin";
      gccVersion = stdenv.cc.cc.version;
      gccLib = "${stdenv.cc.cc}/lib/gcc/${stdenv.targetPlatform.config}/${gccVersion}";
    in ''
      # Discover and include all library directories from the distribution
      libDirs=$(find $out -name "*.so*" -type f | xargs dirname | sort -u | tr '\n' ':')

      # Patch all ELF binaries in the distribution
      find $out -type f -executable -exec file {} \; | grep -E "ELF.*executable" | cut -d: -f1 | while read binary; do
        echo "Patching binary: $binary"
        patchelf \
          --set-interpreter "${interpreter}" \
          --set-rpath "${libraryPath}:$libDirs" \
          "$binary" || echo "Failed to patch $binary (might not be dynamically linked)"
      done

      # Create a wrapper script using --sysroot with explicit binary tool paths
      mv $out/bin/cjc $out/bin/.cjc-unwrapped
      cat > $out/bin/cjc <<EOF
#!/bin/sh
# Use --sysroot for automatic toolchain detection combined with -B for binary tools and -L for libraries
exec $out/bin/.cjc-unwrapped \\
  --sysroot "${sysroot}" \\
  -B"${binPath}" \\
  -B"${gccLib}" \\
  -B"${glibc}/lib" \\
  -L"${gccLib}" \\
  -L"${glibc}/lib" \\
  -L"${stdenv.cc.cc.lib}/lib" \\
  -L"${gcc.cc.lib}/lib" \\
  "\$@"
EOF
      chmod +x $out/bin/cjc
    '';

  meta = {
    homepage = "https://cangjie-lang.cn/";
    description = "Cangjie compiler";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    outputsToInstall = [ "out" ];
  };
}
