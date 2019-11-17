{ stdenv, fetchurl, fetchgit, makeWrapper, llvmPackages_8, cmake }:

with stdenv.lib;

stdenv.mkDerivation rec {
  pname = "clazy";
  version = "1.6";

  src = fetchurl {
    url = "https://github.com/KDE/clazy/archive/v${version}.tar.gz";
    sha256 = "1xiqcl6brqa08saj4gsjkvdbsgx395xagkd3vmixa683y5bzfqq0";
  };

  buildInputs = [ llvmPackages_8.llvm 
                  llvmPackages_8.clang 
                  llvmPackages_8.clang-unwrapped 
                  cmake ];

  doCheck = true;

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  enableParallelBuilding = true;

  meta = {
    description = "Qt oriented code checker based on clang framework";
    longDescription = ''
      clazy is a compiler plugin which allows clang to understand Qt semantics.
      You get more than 50 Qt related compiler warnings, ranging from 
      unneeded memory allocations to misusage of API, including fix-its 
      for automatic refactoring.
    '';
    homepage = https://github.com/KDE/clazy;
    license = "LGPL2";
    maintainers = [ maintainers.deadloko ];
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
