self:
{
  config,
  lib,
  pkgs,
  ...
}:

# A NixOS module for grootshell, so running it is `enable = true` rather than
# reverse-engineering a systemd unit from someone else's dotfiles.
#
# ## What this owns, and what it does not
#
# It owns the things the SHELL needs to work: the user service and its PATH, the
# fonts and icon themes it draws with, the tools it shells out to, the
# environment that lets a keybind find a running instance, and the cheatsheet
# file. Turn it on and you have a working shell.
#
# It deliberately does NOT own your system's appearance — no cursor themes, no
# GTK or Qt settings files, no dconf keys. Those are opinions about a whole
# desktop rather than about this shell, and a module that quietly rewrites your
# GTK theme because you wanted a bar is a module nobody should install. The shell
# will write GTK, Qt and terminal palettes when the wallpaper changes, because
# you asked it to by picking a wallpaper; it will not decide your icon theme.
#
# Nor does it generate compositor keybinds. Hyprland is configured many ways —
# hyprland.conf, Home Manager, the Lua config manager this shell was built
# against — and emitting binds for one of them would be wrong for the rest. You
# bind the keys; `keybinds` here is what populates the in-shell cheatsheet, so
# the two agree without this module having to guess how you write config.
#
# ## Nix is optional
#
# Everything below is convenience. The shell resolves its own helper scripts
# relative to shell.qml, so `qs -p /path/to/checkout` works with no Nix at all —
# see the README. This module exists so that Nix users do not have to.

let
  cfg = config.programs.grootshell;
in
{
  options.programs.grootshell = {
    enable = lib.mkEnableOption "the grootshell desktop shell";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "grootshell.packages.\${system}.default";
      description = "The grootshell package. Carries the shell, its IPC wrapper, and the theme and calendar helpers.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        The user whose session runs the shell.

        Used for the per-user profile on the service's PATH, so applications you
        installed with `users.users.<name>.packages` are launchable from the
        launcher.
      '';
      example = "alice";
    };

    devPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/alice/dev/quickshell-dots";
      description = ''
        Run the QML from a writable checkout instead of the store.

        Quickshell hot-reloads on save, so this turns editing the shell from a
        rebuild per change into a save per change. Leave it null to run the
        packaged copy.
      '';
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = ''
        The systemd user target the shell is bound to.

        `graphical-session.target` is the standard one. A compositor-specific
        target — `hyprland-session.target`, say — is worth using if you have one,
        because it stops the shell outliving the compositor as an orphan pointed
        at a dead Wayland socket.
      '';
    };

    keybinds = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.unspecified);
      default = [ ];
      example = lib.literalExpression ''
        [
          { keys = [ "SUPER + space" ]; description = "Application launcher"; category = "Shell"; }
        ]
      '';
      description = ''
        The keybind list, for the shell's own cheatsheet on SUPER+/.

        Written to `/etc/grootshell/keybinds.json` as
        `[{ keys, description, category }]`. Anything else in an entry is
        ignored, so the same list can carry your dispatchers and be passed
        straight through — which is the point: one definition, so the cheatsheet
        cannot drift from the bindings it documents.

        This module does not create the binds themselves. See the note at the top
        of this file.
      '';
    };

    calendarUrlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/calendar/ical-urls";
      description = ''
        A file of `name|url` lines, one per calendar, for the agenda.

        Only needed when the list is somewhere unguessable — a decrypted secret,
        typically. Left null, the fetcher reads
        `$XDG_CONFIG_HOME/grootshell/calendars`, which is the right place for a
        list that is not a secret.
      '';
    };

    clipboardHistory = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run cliphist watchers, which the clipboard panel reads.

        Two watchers, text and image: `wl-paste --watch` takes one MIME class at
        a time, and without the image one screenshots never enter the history.
      '';
    };

    fonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the fonts the shell is designed around.

        The package already wraps them into its own fontconfig, so the shell
        renders correctly either way. This installs them SYSTEM-wide, which is a
        different thing: a Material Symbols glyph missing from a GTK file dialog
        is exactly as broken as one missing from the bar.
      '';
    };

    theming = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install what the wallpaper theme generator needs, and the GTK stylesheet
        that makes its output visible.

        matugen does the palette; adw-gtk3 is what makes GTK3 applications
        actually follow it, because stock Adwaita bakes its colours in and
        ignores the ones we define.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.devPath == null || lib.hasPrefix "/" (toString cfg.devPath);
        message = "programs.grootshell.devPath must be an absolute path; quickshell resolves it directly, not relative to the service's working directory.";
      }
    ];

    systemd.user.services = {
      grootshell = {
        description = "grootshell desktop shell";
        partOf = [ cfg.target ];
        wantedBy = [ cfg.target ];
        after = [ cfg.target ];

        environment = lib.filterAttrs (_: v: v != null) {
          GROOTSHELL_CONFIG_PATH = toString (
            if cfg.devPath != null then cfg.devPath else "${cfg.package}/share/grootshell"
          );
          GROOTSHELL_CALENDAR_URL_FILE = cfg.calendarUrlFile;
        };

        # The session's PATH, because the shell LAUNCHES things.
        #
        # A systemd service gets the closed PATH NixOS builds, and the package's
        # own wrapper adds only what its QML shells out to. Neither contains
        # /run/current-system/sw/bin, so a .desktop entry with a bare name in its
        # Exec silently fails to start — and the ones that write an absolute store
        # path work, which hides it for weeks.
        #
        # Both profiles, so user packages are launchable too. Also what makes
        # xdg-open reachable, which the calendar's join links need.
        path = [
          cfg.package
          "/run/current-system/sw"
          "/etc/profiles/per-user/${cfg.user}"
        ];

        serviceConfig = {
          ExecStart = "${cfg.package}/bin/grootshell";
          Restart = "on-failure";
          RestartSec = "2s";

          # Only kill the shell itself, not everything sharing its cgroup.
          # Applications launched from the shell inherit it, and the default
          # KillMode=control-group takes the whole group down on restart.
          KillMode = "process";
        };

        # No rate limit on restarts. Quickshell exits non-zero when the QML fails
        # to load, so systemd's default — five starts in ten seconds, then give
        # up — turns any typo into a service that stays dead until someone runs
        # `reset-failed`, with the bar being the thing that just disappeared.
        unitConfig.StartLimitIntervalSec = 0;
      };
    }
    // lib.optionalAttrs cfg.clipboardHistory (
      lib.listToAttrs (
        map
          (type: {
            name = "cliphist-${type}";
            value = {
              description = "Clipboard history (${type})";
              partOf = [ cfg.target ];
              wantedBy = [ cfg.target ];
              after = [ cfg.target ];
              serviceConfig = {
                ExecStart = "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --type ${type} --watch ${lib.getExe pkgs.cliphist} store";
                Restart = "on-failure";
                RestartSec = "2s";
              };
            };
          })
          [
            "text"
            "image"
          ]
      )
    );

    # Quickshell identifies a running instance by its config path, so `qs ipc`
    # only reaches the shell if it resolves the SAME path the shell was launched
    # with. A compositor keybind inherits the compositor's environment, not the
    # service's — so without this, every keybind that talks to the shell resolves
    # the package's store path, fails to match an instance running from a dev
    # checkout, and silently does nothing.
    #
    # Session-wide rather than baked into the wrapper, so `grootshell-ipc` also
    # works when typed into a terminal.
    environment.sessionVariables.GROOTSHELL_CONFIG_PATH = toString (
      if cfg.devPath != null then cfg.devPath else "${cfg.package}/share/grootshell"
    );

    # /etc rather than the config directory: this describes the compositor, so it
    # is true for whoever logs in and is not something a user edits. The shell
    # falls back to ~/.config/grootshell/keybinds.json when there is none.
    environment.etc = lib.mkIf (cfg.keybinds != [ ]) {
      "grootshell/keybinds.json".text = builtins.toJSON (
        map (b: {
          keys = b.keys;
          description = b.description or "";
          category = b.category or "Other";
        }) cfg.keybinds
      );
    };

    environment.systemPackages =
      [ cfg.package ]
      ++ (with pkgs; [
        # What the QML shells out to. There is no C++ plugin, so anything the
        # shell cannot get from Quickshell's own services comes from one of these.
        cliphist
        grim
        slurp
        swappy
        wl-clipboard
        cava # the media tab's spectrum ring
        lm_sensors # temperatures on the performance tab
        networkmanager # nmcli, for the wifi popout

        # Icon THEMES, a different thing from the icon font. Without one, every
        # themed lookup resolves to nothing: tray icons render blank, and so do
        # the launcher's application icons and the workspace strip's.
        #
        # Papirus carries real entries for the long tail — Flatpak apps, input
        # methods, Steam — where Adwaita alone falls back to a generic square.
        # Adwaita and hicolor sit underneath as the fallbacks toolkits expect.
        papirus-icon-theme
        adwaita-icon-theme
        hicolor-icon-theme
      ])
      ++ lib.optionals cfg.theming (with pkgs; [
        matugen
        imagemagick
        adw-gtk3
      ]);

    fonts.packages = lib.mkIf cfg.fonts (
      with pkgs;
      [
        material-symbols # every icon in the shell
        rubik # interface text
        nerd-fonts.caskaydia-cove # figures and readouts
        noto-fonts-cjk-sans # the kanji numerals on empty workspaces
      ]
    );
  };
}
