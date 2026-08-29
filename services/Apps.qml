pragma Singleton

import Quickshell

// Launching things so they outlive the shell that launched them.
//
// A process started from here is a child of the shell, and a child of the shell
// is in the shell's systemd cgroup. systemd's default KillMode is
// control-group: `systemctl restart grootshell` SIGTERMs everything in that
// cgroup. So opening a browser from the launcher and then restarting the shell
// — which the dev loop does constantly — killed the browser.
//
// Qt's startDetached, which DesktopEntry.execute() uses, does not help. It
// detaches the child from the parent PROCESS; the cgroup is a separate thing and
// the child stays in it.
//
// Every launch therefore goes through a transient systemd scope, which moves the
// process into a unit of its own. This is the job app2unit does in other
// configs, done with systemd-run rather than by taking a dependency.
//
// --collect so the scope is garbage-collected when the process exits rather than
// lingering as a dead unit; --quiet so systemd-run does not narrate to a journal
// nobody reads.

Singleton {
    id: root

    readonly property var scopeArgs: ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--"]

    // Run an argv array outside the shell's cgroup.
    function launch(command: var): void {
        if (!command || command.length === 0)
            return;
        Quickshell.execDetached(root.scopeArgs.concat(Array.from(command)));
    }

    // Run a desktop entry the same way.
    //
    // Deliberately not entry.execute(): that is the call whose cgroup behaviour
    // is the problem. `command` is the exec line already parsed and stripped of
    // its field codes, which is what execute() would have used anyway.
    function launchEntry(entry): void {
        if (!entry)
            return;
        const command = entry.command;
        if (command && command.length > 0)
            root.launch(command);
        else
            entry.execute(); // nothing better available; better than not launching
    }

    // Run a shell command line — the launcher's `>` mode.
    function shell(commandLine: string): void {
        if (!commandLine)
            return;
        root.launch(["bash", "-lc", commandLine]);
    }
}
