{ stdenv, fetchFromGitLab, glib, gettext, substituteAll, gnome-menus }:

stdenv.mkDerivation rec {
  pname = "gnome-shell-arc-menu";
  version = "33";

  src = fetchFromGitLab {
    owner = "LinxGem33";
    repo = "Arc-Menu";
    rev = "v${version}-Stable";
    sha256 = "0ncb19jlwy2y9jcj8g6cdbasdv6n7hm96qv9l251z6qgrmg28x4z";
  };

  patches = [
    (substituteAll {
      src = ./fix_gmenu.patch;
      gmenu_path = "${gnome-menus}/lib/girepository-1.0";
    })
  ];

  buildInputs = [
    glib gettext
  ];

  makeFlags = [ "INSTALL_BASE=${placeholder "out"}/share/gnome-shell/extensions" ];

  uuid = "arc-menu@linxgem33.com";

  meta = with stdenv.lib; {
    description = "Gnome shell extension designed to replace the standard menu found in Gnome 3";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ dkabot ];
    homepage = https://gitlab.com/LinxGem33/Arc-Menu;
  };
}
