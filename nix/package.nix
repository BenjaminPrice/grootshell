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
  noto-fonts-cjk-sans,
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
  # The theme generator's own dependencies. matugen must be 4.1+ for --prefer;
  # the flake pins nixos-unstable, where it is.
  matugen,
  imagemagick,
  dconf,
  # The calendar fetcher's. Recurrence expansion is not something to reimplement
  # in QML, so this is Python and stays Python.
  python3,
  procps,
  slurp,
  swappy,
  systemd,
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
    # systemd-run, which the launcher uses to start applications in their own
    # transient scope. Without it every launched app sits in the shell's cgroup
    # and dies with the next `systemctl restart grootshell`.
    systemd
    util-linux
    wl-clipboard
  ];

  fontconfig = makeFontsConf {
    fontDirectories = [
      material-symbols
      rubik
      nerd-fonts.caskaydia-cove
      # For the kanji numerals on empty workspaces. None of the three above
      # carry CJK, and this fontconfig is CLOSED — the host having Noto CJK
      # installed does not help, because the shell does not read the system set.
      # Without this the workspace strip renders tofu.
      noto-fonts-cjk-sans
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

        # scripts/ and templates/ ship WITH the QML, not beside it.
        #
        # The shell resolves its own helpers from Quickshell.shellDir — the
        # directory holding shell.qml — so it can fall back to the scripts this
        # repo carries when the packaged wrappers are not on PATH. Leave these
        # out and that fallback resolves to nothing in the store copy while
        # working perfectly from a checkout, which is the worst kind of
        # difference between the two.
        cp -r $src/scripts $src/templates $out/
        chmod +x $out/scripts/*.sh $out/scripts/grootshell-ipc

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

  # The two helpers the shell shells out to.
  #
  # Both are thin wrappers around scripts that live in THIS repo, rather than
  # reimplementations of them in Nix. That is the whole point: the script is the
  # single definition, Nix supplies its dependencies, and a non-Nix user runs the
  # same file directly. The shell prefers these wrappers when they are on PATH
  # and falls back to the bundled scripts when they are not — see
  # services/Theming.qml and services/Calendar.qml.
  theme = writeShellApplication {
    name = "grootshell-theme";
    runtimeInputs = [
      matugen
      imagemagick
      dconf
      coreutils
      gnused
      gnugrep
    ];
    # Explicit rather than relying on the script finding templates/ beside its
    # own directory. That relative lookup is correct for this layout and would
    # break silently if the layout ever changed.
    text = ''
      export GROOTSHELL_TEMPLATES="${qml}/templates"
      exec "${qml}/scripts/generate-theme.sh" "$@"
    '';
  };

  calendarPython = python3.withPackages (ps: [
    ps.icalendar
    ps.recurring-ical-events
  ]);

  calendar = writeShellApplication {
    name = "grootshell-calendar";
    runtimeInputs = [ calendarPython ];
    text = ''
      exec python3 "${qml}/scripts/fetch_calendar.py" "$@"
    '';
  };

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
    theme
    calendar
  ];

  postBuild = ''
    mkdir -p $out/share
    ln -s ${qml} $out/share/grootshell
  '';

  meta = {
    description = "A Quickshell desktop shell for groot";
    homepage = "https://github.com/BenjaminPrice/grootshell";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "grootshell";
  };
}
