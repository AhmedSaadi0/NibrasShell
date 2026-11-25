// themes/modules/WallpaperController.qml
import QtQuick
import Quickshell.Io
import "root:/utils" as Utils
import "root:/themes" as Theme
import "root:/config"

Item {
    id: root

    // =========================================================
    // 1. Public API & Properties
    // =========================================================
    property string currentWallpaperPath: ""

    // Dynamic Wallpaper Settings
    property bool dynamicEnabled: false
    property string dynamicPath: ""
    property int interval: 60000
    property bool isLoading: false

    // Data Models
    property var localWallpapersList: []
    property var downloadedWallpapersList: []
    property var wallhavenWallpapersList: []

    // Internal State
    property var _dynamicPlaylist: []
    property int _currentIndex: 0

    // =========================================================
    // 2. Signals
    // =========================================================
    // General
    signal wallpaperReady(string path)

    // Wallhaven
    signal fetchingWallhavenWallpapersStarted
    signal wallhavenWallpapersFetched(var response)
    signal wallhavenWallpapersError(string errorDetails)

    // Downloads
    signal wallpaperDownloadStarted(string filePath)
    signal wallpaperDownloadFinished(string filePath)
    signal wallpaperDownloadError(string errorDetails)

    // =========================================================
    // 3. Lifecycle & Initialization
    // =========================================================
    Component.onCompleted: {
        refreshAllWallpaperLists();
    }

    // =========================================================
    // 4. Public Functions (Controller Logic)
    // =========================================================

    // -- Configuration --
    function configure(settings) {
        // Reset state
        timerDynamicWallpaper.stop();
        procGetDynamicList.running = false;

        root.dynamicEnabled = settings.enableDynamicWallpapers;
        root.dynamicPath = settings.dynamicWallpapersPath;
        root.interval = settings.dynamicWallpapersInterval || 60000;
        root._dynamicPlaylist = [];

        let initialWall = settings.wallpaper || "";
        let resolvedPath = _resolvePath(initialWall);

        if (root.dynamicEnabled) {
            root.isLoading = true;
            root._currentIndex = settings.selectedWallpaperIndex || 0;

            // Set immediately to prevent flickering before list loads
            root.currentWallpaperPath = resolvedPath;

            // Fetch playlist
            procGetDynamicList.command = Utils.Helper.getWallpapersList(root.dynamicPath);
            procGetDynamicList.running = true;
        } else {
            // Static Mode
            root.isLoading = false;
            root.currentWallpaperPath = resolvedPath;
            if (resolvedPath !== "") {
                console.info("[WallpaperController] Static wallpaper ready ->", resolvedPath);
                wallpaperReady(resolvedPath);
            }
        }
    }

    // -- List Management --
    function refreshLocalWallpapers() {
        procLocalWallpapers.command = App.scripts.python.scanWallpapersCommand;
        procLocalWallpapers.running = true;
    }

    function refreshDownloadedWallpapers() {
        procDownloadedWallpapers.command = Utils.Helper.getWallpapersList(App.downloadedWallpapersPath);
        procDownloadedWallpapers.running = true;
    }

    function refreshAllWallpaperLists() {
        refreshLocalWallpapers();
        refreshDownloadedWallpapers();
    }

    // -- Wallhaven Actions --
    function searchWallhaven(url) {
        fetchingWallhavenWallpapersStarted();
        procWallhavenSearch.command = ["curl", "-s", url];
        procWallhavenSearch.running = true;
    }

    function downloadWallhaven(id, fileType, url) {
        const filename = id + "." + fileType.split('/')[1];
        const filePath = App.downloadedWallpapersPath + "/" + filename;

        wallpaperDownloadStarted(filePath);

        // Dynamic process creation for concurrent downloads
        const proc = compDownloadFactory.createObject(root, {
            "targetPath": filePath,
            "command": App.scripts.bash.downloadWallpaperCommand(filePath, url)
        });

        if (proc) {
            proc.running = true;
        } else {
            console.error("[WallpaperController] Failed to create download process");
            wallpaperDownloadError("Internal Error: Could not create process");
        }
    }

    // -- Navigation (Dynamic Mode) --
    function nextWallpaper() {
        if (!root.dynamicEnabled || root._dynamicPlaylist.length === 0)
            return;
        root._currentIndex++;
        _updateIndexAndApply();
    }

    function previousWallpaper() {
        if (!root.dynamicEnabled || root._dynamicPlaylist.length === 0)
            return;
        root._currentIndex--;
        _updateIndexAndApply();
    }

    // =========================================================
    // 5. Private Helpers
    // =========================================================
    function _updateIndexAndApply() {
        // Loop logic
        if (root._currentIndex >= root._dynamicPlaylist.length) {
            root._currentIndex = 0;
        }
        if (root._currentIndex < 0) {
            root._currentIndex = root._dynamicPlaylist.length - 1; // Fix: length - 1
        }

        let path = root._dynamicPlaylist[root._currentIndex];
        root.currentWallpaperPath = path;

        wallpaperReady(path);

        // Persist state without reapplying the theme: wallpaperReady already started M3.
        Theme.ThemeManager.updateThemePropertyOnly({
            "_selectedWallpaperIndex": root._currentIndex
        }, true);
    }

    function _resolvePath(path) {
        if (!path || path === "")
            return "";
        // If no slash, assume it's an asset key
        if (path.indexOf("/") === -1) {
            return App.assets.getWallpaperPath(path);
        }
        return path;
    }

    // =========================================================
    // 6. Processes & Timers
    // =========================================================

    Timer {
        id: timerDynamicWallpaper
        repeat: true
        onTriggered: root.nextWallpaper()
    }

    // Fetch Dynamic Playlist
    Process {
        id: procGetDynamicList
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text);
                    if (list.length === 0) {
                        console.warn("[WallpaperController] Empty list.");
                        root.isLoading = false;
                        root.wallpaperReady(root.currentWallpaperPath);
                        return;
                    }
                    root._dynamicPlaylist = list;

                    // Validation
                    if (root._currentIndex >= list.length)
                        root._currentIndex = 0;

                    let firstPath = list[root._currentIndex];
                    root.currentWallpaperPath = firstPath;

                    console.info("[WallpaperController] Dynamic wallpaper ready ->", firstPath);
                    root.wallpaperReady(firstPath);

                    timerDynamicWallpaper.interval = root.interval;
                    timerDynamicWallpaper.start();
                    root.isLoading = false;
                } catch (e) {
                    console.error("[WallpaperController] Error:", e);
                    root.isLoading = false;
                }
            }
        }
    }

    // Fetch Local Wallpapers
    Process {
        id: procLocalWallpapers
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.localWallpapersList = JSON.parse(this.text) || [];
                } catch (e) {
                    console.error("[WallpaperController] Failed to parse local wallpapers", e);
                    root.localWallpapersList = [];
                }
            }
        }
    }

    // Fetch Downloaded Wallpapers
    Process {
        id: procDownloadedWallpapers
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.downloadedWallpapersList = JSON.parse(this.text) || [];
                } catch (e) {
                    console.error("[WallpaperController] Failed to parse downloaded wallpapers", e);
                    root.downloadedWallpapersList = [];
                }
            }
        }
    }

    // Wallhaven API Search
    Process {
        id: procWallhavenSearch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text);
                    root.wallhavenWallpapersFetched(response);
                } catch (e) {
                    console.error("[WallpaperController] Failed to parse Wallhaven response", e);
                    root.wallhavenWallpapersError("Failed to parse response: " + e);
                }
            }
        }
    }

    // Dynamic Download Factory
    Component {
        id: compDownloadFactory

        Process {
            property string targetPath: ""

            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0 && targetPath !== "") {
                    // Update UI list
                    var newList = root.downloadedWallpapersList.slice();
                    newList.push(targetPath);
                    root.downloadedWallpapersList = newList;

                    root.wallpaperDownloadFinished(targetPath);
                } else {
                    console.error("[WallpaperController] Download failed code:", exitCode);
                    root.wallpaperDownloadError("Download failed with code " + exitCode);
                }

                // Cleanup memory
                destroy();
            }
        }
    }
}
