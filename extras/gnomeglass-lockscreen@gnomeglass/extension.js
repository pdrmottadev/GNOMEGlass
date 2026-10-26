// GNOME Glass: lock screen
//
// When the screen locks, the Shell switches to the "unlock-dialog" mode and
// disables the extensions that don't declare that mode. User Themes is one of
// them, and its disable() puts the Shell back on the default theme. This
// extension declares the mode and, only while the screen is locked, reapplies
// the GNOMEGlass stylesheet selected in User Themes. Outside the lock screen
// it does nothing.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const USER_THEME_SCHEMA = 'org.gnome.shell.extensions.user-theme';

function glassStylesheet() {
    const source = Gio.SettingsSchemaSource.get_default();
    if (!source.lookup(USER_THEME_SCHEMA, true))
        return null;

    const name = new Gio.Settings({schema_id: USER_THEME_SCHEMA}).get_string('name');
    if (!name.startsWith('GNOMEGlass'))
        return null;

    // Same search order as User Themes
    const dirs = [
        GLib.build_filenamev([GLib.get_home_dir(), '.themes']),
        GLib.build_filenamev([GLib.get_user_data_dir(), 'themes']),
        ...GLib.get_system_data_dirs().map(dir => GLib.build_filenamev([dir, 'themes'])),
    ];
    for (const dir of dirs) {
        const file = Gio.File.new_for_path(GLib.build_filenamev([dir, name, 'gnome-shell', 'gnome-shell.css']));
        if (file.query_exists(null))
            return file;
    }
    return null;
}

export default class GNOMEGlassLockScreen extends Extension {
    enable() {
        this._applied = false;
        this._sessionId = Main.sessionMode.connect('updated', () => this._queueSync());
        this._queueSync();
    }

    disable() {
        Main.sessionMode.disconnect(this._sessionId);
        if (this._idleId)
            GLib.source_remove(this._idleId);
        this._idleId = 0;

        // Only undo it if we applied it (screen still locked)
        if (this._applied) {
            Main.setThemeStylesheet(null);
            Main.loadTheme();
        }
        this._applied = false;
    }

    // Runs after the extension manager has already disabled User Themes
    _queueSync() {
        if (this._idleId)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._idleId = 0;
            this._sync();
            return GLib.SOURCE_REMOVE;
        });
    }

    _sync() {
        if (Main.sessionMode.currentMode !== 'unlock-dialog') {
            // Back in the session: User Themes reapplies the theme on its own
            this._applied = false;
            return;
        }

        const stylesheet = glassStylesheet();
        if (!stylesheet)
            return;

        Main.setThemeStylesheet(stylesheet.get_path());
        Main.loadTheme();
        this._applied = true;
    }
}
