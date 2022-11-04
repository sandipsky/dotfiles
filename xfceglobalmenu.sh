yay -S vala-panel-appmenu-common vala-panel-appmenu-registrar vala-panel-appmenu-xfce appmenu-gtk-module


xfconf-xquery -c xsettings -p /Gtk/ShellShowsMenubar -n -t bool -s true
xfconf-xquery -c xsettings -p /Gtk/ShellShowsAppmenu -n -t bool -s true
