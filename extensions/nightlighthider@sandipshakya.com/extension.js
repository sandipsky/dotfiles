const St = imports.gi.St;
const Main = imports.ui.main;


function init() {}

function enable() {
    Main.panel.statusArea.aggregateMenu._nightLight.indicators.hide()
    Main.panel.statusArea.aggregateMenu._nightLight._indicators = Main.panel.statusArea.aggregateMenu._nightLight.indicators
    //replacing it with another St.Boxlayout to avoid errors elsewhere.
    Main.panel.statusArea.aggregateMenu._nightLight.indicators = new St.BoxLayout()
}

function disable() {
    Main.panel.statusArea.aggregateMenu._nightLight.indicators.destroy()
    Main.panel.statusArea.aggregateMenu._nightLight.indicators = Main.panel.statusArea.aggregateMenu._nightLight._indicators
}
