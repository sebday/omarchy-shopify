import QtQuick

Item {
    id: root

    property var shell: null
    property bool openedOnStart: false

    onShellChanged: {
        if (!shell || openedOnStart)
            return
        openedOnStart = true
        Qt.callLater(function() {
            if (shell && typeof shell.summon === "function")
                shell.summon("evo.shopify", "{}")
        })
    }
}
