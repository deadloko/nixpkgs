{ stdenv, fetchurl, makeWrapper
, qtbase, qtquickcontrols, qtscript, qtdeclarative, qmake, llvmPackages_8
, withDocumentation ? false
}:

with stdenv.lib;

let
  baseVersion = "4.9";
  revision = "1";
in

stdenv.mkDerivation rec {
  pname = "qtcreator";
  version = "${baseVersion}.${revision}";

  src = fetchurl {
    url = "http://download.qt-project.org/official_releases/${pname}/${baseVersion}/${version}/qt-creator-opensource-src-${version}.tar.xz";
    sha256 = "10ddp1365rf0z4bs7yzc9hajisp3j6mzjshyd0vpi4ki126j5f3r";
  };

  buildInputs = [ qtbase qtscript qtquickcontrols qtdeclarative llvmPackages_8.libclang llvmPackages_8.clang-unwrapped llvmPackages_8.clang llvmPackages_8.llvm ];

  nativeBuildInputs = [ qmake makeWrapper ];

  # 0001-Fix-clang-libcpp-regexp.patch is for fixing regexp that is used to 
  # find clang libc++ library include paths. By default it's not covering paths
  # like libc++-version, which is default name for libc++ folder in nixos.
  patches = [ ./0001-Fix-clang-libcpp-regexp.patch ]; 

  doCheck = true;

  enableParallelBuilding = true;

  buildFlags = optional withDocumentation "docs";

  installFlags = [ "INSTALL_ROOT=$(out)" ] ++ optional withDocumentation "install_docs";

  preConfigure = ''
    substituteInPlace src/plugins/plugins.pro \
      --replace '$$[QT_INSTALL_QML]/QtQuick/Controls' '${qtquickcontrols}/${qtbase.qtQmlPrefix}/QtQuick/Controls'

    # Fix paths for llvm/clang includes directories.
    substituteInPlace src/shared/clang/clang_defines.pri \
      --replace '$$clean_path($${LLVM_LIBDIR}/clang/$${LLVM_VERSION}/include)' '${llvmPackages_8.clang-unwrapped}/lib/clang/8.0.0/include' \
      --replace '$$clean_path($${LLVM_BINDIR})' '${llvmPackages_8.clang}/bin'

    # Fix include path to find clang and clang-c include directories.  
    substituteInPlace src/plugins/clangtools/clangtools.pro \
      --replace 'INCLUDEPATH += $$LLVM_INCLUDEPATH' 'INCLUDEPATH += $$LLVM_INCLUDEPATH ${llvmPackages_8.clang-unwrapped}'

    # Fix paths to libclang library.
    substituteInPlace src/shared/clang/clang_installation.pri \
      --replace 'LIBCLANG_LIBS = -L$${LLVM_LIBDIR}' 'LIBCLANG_LIBS = -L${llvmPackages_8.libclang}/lib' \
      --replace 'LIBCLANG_LIBS += $${CLANG_LIB}' 'LIBCLANG_LIBS += -lclang'

    # Fix clazy plugin name. Reason: qt team maintaining their own fork of 
    # clang and clazy, which is heavily modified.
    substituteInPlace src/plugins/clangcodemodel/clangeditordocumentprocessor.cpp \
      --replace 'clang-lazy' 'clazy'
 
    substituteInPlace src/plugins/clangtools/clangtidyclazyrunner.cpp \
      --replace 'clang-lazy' 'clazy'
  '';

  preBuild = optional withDocumentation ''
    ln -s ${getLib qtbase}/$qtDocPrefix $NIX_QT5_TMP/share
  '';

  postInstall = ''
    substituteInPlace $out/share/applications/org.qt-project.qtcreator.desktop \
      --replace "Exec=qtcreator" "Exec=$out/bin/qtcreator"
  '';

  meta = {
    description = "Cross-platform IDE tailored to the needs of Qt developers";
    longDescription = ''
      Qt Creator is a cross-platform IDE (integrated development environment)
      tailored to the needs of Qt developers. It includes features such as an
      advanced code editor, a visual debugger and a GUI designer.
    '';
    homepage = https://wiki.qt.io/Category:Tools::QtCreator;
    license = "LGPL";
    maintainers = [ maintainers.akaWolf ];
    platforms = [ "i686-linux" "x86_64-linux" "aarch64-linux" "armv7l-linux" ];
  };
}
