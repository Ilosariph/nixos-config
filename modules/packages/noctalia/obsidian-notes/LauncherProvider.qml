import QtQuick
import Quickshell
import Quickshell.Io

Item {
    property var pluginApi
    property var launcher
    property bool handleSearch: false
    property string supportedLayouts: "list"
    property bool supportsAutoPaste: false
    property var currentResults: []
    property string currentQuery: ""
    property bool searching: false

    readonly property string vaultPath: pluginApi?.settings?.vaultPath ?? "~/Documents"
    readonly property var downrankedFolders: pluginApi?.settings?.downrankedFolders ?? ["archive"]
    readonly property int maxResults: pluginApi?.settings?.maxResults ?? 50

    property var _fnResults: []
    property var _rgResults: []
    property bool _fnDone: false
    property bool _rgDone: false
    property string _activeQuery: ""

    function _expandPath(path) {
        if (path.startsWith("~/"))
            return Quickshell.env("HOME") + path.slice(1)
        return path
    }

    function _isDownranked(relativePath) {
        const parts = relativePath.toLowerCase().split("/")
        for (const folder of downrankedFolders) {
            if (parts.includes(folder.toLowerCase()))
                return true
        }
        return false
    }

    function _combineResults(query) {
        if (!_fnDone || !_rgDone) return
        if (query !== _activeQuery) return

        const vault = _expandPath(vaultPath)
        const seen = new Set()
        const all = [..._fnResults, ..._rgResults]
        const unique = all.filter(p => {
            if (seen.has(p)) return false
            seen.add(p)
            return true
        })

        const normal = []
        const downranked = []
        for (const p of unique) {
            const rel = p.startsWith(vault + "/") ? p.slice(vault.length + 1) : p
            ;(_isDownranked(rel) ? downranked : normal).push({ abs: p, rel })
        }

        const toResult = ({ abs, rel }) => {
            const base = rel.split("/").pop().replace(/\.md$/, "")
            const isDown = _isDownranked(rel)
            return {
                name: base,
                description: rel,
                icon: isDown ? "archive" : "file-text",
                isTablerIcon: true,
                onActivate: () => {
                    Quickshell.execDetached(["xdg-open", abs])
                    launcher.close()
                }
            }
        }

        currentResults = [...normal, ...downranked].slice(0, maxResults).map(toResult)
        searching = false
    }

    Process {
        id: fdProc
        property string _query: ""
        stdout: SplitParser {
            onRead: line => {
                if (line.trim()) root._fnResults.push(line.trim())
            }
        }
        onExited: {
            root._fnDone = true
            root._combineResults(fdProc._query)
        }
    }

    Process {
        id: rgProc
        property string _query: ""
        stdout: SplitParser {
            onRead: line => {
                if (line.trim()) root._rgResults.push(line.trim())
            }
        }
        onExited: {
            root._rgDone = true
            root._combineResults(rgProc._query)
        }
    }

    id: root

    function handleCommand(searchText) {
        return searchText.startsWith(">notes")
    }

    function commands() {
        return [{
            command: ">notes",
            description: "Search Obsidian notes",
            icon: "brand-obsidian",
            isTablerIcon: true
        }]
    }

    function getResults(searchText) {
        const query = searchText.replace(/^>notes\s*/, "").trim()

        if (!query) {
            currentResults = []
            searching = false
            return []
        }

        if (fdProc.running) fdProc.running = false
        if (rgProc.running) rgProc.running = false

        searching = true
        _fnDone = false
        _rgDone = false
        _fnResults = []
        _rgResults = []
        _activeQuery = query

        const vault = _expandPath(vaultPath)

        fdProc._query = query
        fdProc.command = ["fd", "--type", "f", "--extension", "md",
                          "--absolute-path", "--color", "never", query, vault]
        fdProc.running = true

        rgProc._query = query
        rgProc.command = ["rg", "--type", "md", "-l",
                          "--color", "never", "--smart-case", query, vault]
        rgProc.running = true

        return currentResults
    }

    function init() {}
}
