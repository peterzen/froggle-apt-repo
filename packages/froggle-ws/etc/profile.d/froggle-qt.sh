# Installed by froggle-ws. Let qt5ct/qt6ct theme Qt apps (dark palette from
# /etc/xdg/qt5ct and /etc/xdg/qt6ct). qt6ct also answers to "qt5ct", so one
# value covers Qt 5 and 6. Plasma has its own platform theme; leave it alone.
if [ -z "${QT_QPA_PLATFORMTHEME:-}" ] && [ "${XDG_CURRENT_DESKTOP:-}" != "KDE" ]; then
    export QT_QPA_PLATFORMTHEME=qt5ct
fi
