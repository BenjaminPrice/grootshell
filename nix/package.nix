{
  lib,
  src,
  runCommand,
  writeShellApplication,
  symlinkJoin,
  makeFontsConf,
  quickshell,
  # Fonts. The shell hardcodes these family names in config/Appearance.qml, so
  # they are wrapped into a FONTCONFIG_FILE rather than left to the system set —
  # a shell that renders tofu because the host forgot a font package is a bad
  # failure mode, and this one cannot happen.
  material-symbols,
  rubik,
  nerd-fonts,
  # Everything the QML shells out to. There is no C++ plugin, so anything the
  # shell cannot get from Quickshell's own services comes from one of these.
  bash,
  cliphist,
  coreutils,
  gawk,
  glib,
  gnugrep,
  gnused,
  grim,
  hyprland,
  libnotify,
  lm_sensors,
  networkmanager,
  procps,
  slurp,
  swappy,
  util-linux,
  wl-clipboard,
}:

let
  runtimeDeps = [
    bash
    cliphist
    coreutils
    gawk
    glib # gdbus, for desktop portal odds and ends
    gnugrep
    gnused
    grim
    hyprland # hyprctl
    libnotify
    lm_sensors # sensors, for the performance tab
    networkmanager # nmcli, for the wifi popout
    procps
    slurp
    swappy
    util-linux
    wl-clipboard
  ];

  fontconfig = makeFontsConf {
    fontDirectories = [
      material-symbols
      rubik
      nerd-fonts.caskaydia-cove
    ];
  };

  # The QML tree, isolated from the flake's own nix/ and docs. Quickshell is
  # pointed at this directory; it is also exactly what a dev checkout looks like,
  # which is why GROOTSHELL_CONFIG_PATH can swap one for the other.
  qml =
    runCommand "grootshell-qml"
      {
        inherit src;
      }
      ''
        mkdir -p $out
        cp -r $src/shell.qml $src/config $src/services $src/components $src/modules $out/
        # assets/ is optional while the tree is young.
        [ -d $src/assets ] && cp -r $src/assets $out/ || true
      '';

  # GROOTSHELL_CONFIG_PATH is the whole dev loop: unset it and the shell runs the
  # store copy above; set it and Quickshell watches a writable checkout and
  # hot-reloads on save. Deliberately a runtime lookup rather than a build-time
  # substitution, so switching between the two needs no rebuild.
  mkWrapper =
    name: extraArgs:
    writeShellApplication {
      inherit name;
      runtimeInputs = [ quickshell ] ++ runtimeDeps;
      text = ''
        export FONTCONFIG_FILE="''${FONTCONFIG_FILE:-${fontconfig}}"
        export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-wayland}"
        exec qs -p "''${GROOTSHELL_CONFIG_PATH:-${qml}}" ${extraArgs} "$@"
      '';
    };

  shell = mkWrapper "grootshell" "";

  # Separate binary rather than a subcommand: Hyprland keybinds invoke this
  # directly, and `grootshell-ipc call launcher toggle` reads better in a bind
  # than an argv-sniffing wrapper would.
  ipc = mkWrapper "grootshell-ipc" "ipc";
in
symlinkJoin {
  name = "grootshell";

  paths = [
    shell
    ipc
  ];

  postBuild = ''
    mkdir -p $out/share
    ln -s ${qml} $out/share/grootshell
  '';

  meta = {
    description = "A Quickshell desktop shell for groot";
    homepage = "https://github.com/BenjaminPrice/quickshell-dots";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "grootshell";
  };
}
