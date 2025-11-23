{ config, pkgs, ... }:

let
  mesaPath = pkgs.mesa;
  eglVendorFile = "${mesaPath}/share/glvnd/egl_vendor.d/50_mesa.json";

  orcaSlicerWrapped = pkgs.writeShellScriptBin "orca-slicer-zink" ''
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export MESA_LOADER_DRIVER_OVERRIDE=zink
    export GALLIUM_DRIVER=zink
    export WEBKIT_DISABLE_DMABUF_RENDERER=1

    export __EGL_VENDOR_LIBRARY_FILENAMES="${eglVendorFile}"

    exec ${pkgs.orca-slicer}/bin/orca-slicer "$@"
  '';

in {
  home.packages = [
    pkgs.orca-slicer
    orcaSlicerWrapped
  ];

  xdg.desktopEntries."orca-slicer" = {
    name = "Orca Slicer (Zink)";
    comment = "3D printer slicer wrapped for Zink/Mesa compatibility.";
    exec = "orca-slicer-zink";
    icon = "orca-slicer";
    terminal = false;
    categories = [ "Utility" "Graphics" ];
  };
}
