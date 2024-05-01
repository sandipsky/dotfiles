const { Gio, GObject} = imports.gi;
const ExtensionUtils = imports.misc.extensionUtils;
const extension = ExtensionUtils.getCurrentExtension();
const Main = imports.ui.main;

let signal_overlay_key = null;
let original_signal_overlay_key = null;
let settings = null;

// Variable to declare the value for the pop-launcher
var OVERVIEW_LAUNCHER = 2;

// Check if Pop shell is installed
function with_pop_shell(callback) {
    let pop_shell = Main.extensionManager.lookup("pop-shell@system76.com");
    if (pop_shell && pop_shell.stateObj) {
        let ext = pop_shell.stateObj.ext;
        if (ext) {
            return callback(ext);
        }
    }
}

// Overview functions
function overview_visible(kind) {
    if (kind == OVERVIEW_LAUNCHER) {
        if (with_pop_shell((ext) => {
            return ext.window_search.dialog.visible;
        }) === true) {
            return true;
        }
    } else {
        if (Main.overview.visibleTarget) {
            return true;
        }
    }
    return false;
}

function overview_show(kind) {
    if (kind == OVERVIEW_LAUNCHER) {
        Main.overview.hide();
        with_pop_shell((ext) => {
            ext.tiler.exit(ext);
            ext.window_search.load_desktop_files();
            ext.window_search.open(ext);
        });
    } else {
        Main.overview.show();
    }
}

function overview_hide(kind) {
    if (kind == OVERVIEW_LAUNCHER) {
        with_pop_shell((ext) => {
            ext.exit_modes();
        });
    } else {
        Main.overview.hide();
    }
}

function overview_toggle(kind) {
    if (Main.overview.animationInProgress) {
        // prevent accidental re-show
    } else if (overview_visible(kind)) {
        overview_hide(kind);
    } else {
        overview_show(kind);
    }
}

// Overlay-key 
var overlay_key_action = OVERVIEW_LAUNCHER;

function overlay_key() {
    overview_toggle(overlay_key_action);
}

function overlay_key_changed(settings) {
    if (overview_visible(overlay_key_action)) {
        overview_hide(overlay_key_action);
    }
    overlay_key_action = settings.get_enum("overlay-key-action");
}

function init(metadata) {}

function enable() {

    settings = ExtensionUtils.getSettings((extension.metadata["settings-schema"]));

    // Load overlay key action and keep it up to date with settings
    overlay_key_changed(settings);
    settings.connect("changed::overlay-key-action", () => {
        overlay_key_changed(settings);
    });
    
    // Block original overlay key handler
    original_signal_overlay_key = GObject.signal_handler_find(global.display, { signalId: "overlay-key" });
    if (original_signal_overlay_key !== null) {
        global.display.block_signal_handler(original_signal_overlay_key);
    }

    // Connect modified overlay key handler
    const A11Y_SCHEMA = 'org.gnome.desktop.a11y.keyboard';
    const STICKY_KEYS_ENABLE = 'stickykeys-enable';
    let _a11ySettings = new Gio.Settings({ schema_id: A11Y_SCHEMA });
    signal_overlay_key = global.display.connect("overlay-key", () => {
        if (!_a11ySettings.get_boolean(STICKY_KEYS_ENABLE))
            overlay_key();
    });
}

function disable() {
    
    // Disconnect modified overlay key handler
    if (signal_overlay_key !== null) {
        global.display.disconnect(signal_overlay_key);
        signal_overlay_key = null;
    }

    // Unblock original overlay key handler
    if (original_signal_overlay_key !== null) {
        global.display.unblock_signal_handler(original_signal_overlay_key);
        original_signal_overlay_key = null;
    }

    settings =  null;
}
