import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import { WorkspaceSwitcherPopup } from 'resource:///org/gnome/shell/ui/workspaceSwitcherPopup.js';

export default class DisableWorkspaceSwitcherPopup extends Extension {
	constructor(metaData) {
		super(metaData);
		this._originalWorkspaceSwitcherPopupDisplay = WorkspaceSwitcherPopup.prototype.display;
	}

	enable() {
		WorkspaceSwitcherPopup.prototype.display = () => { }
	}

	disable() {
		WorkspaceSwitcherPopup.prototype.display = this._originalWorkspaceSwitcherPopupDisplay;
	}
}