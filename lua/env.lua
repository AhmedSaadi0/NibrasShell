local home = os.getenv("HOME")

-- XDG & Wayland Session Identity
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- Multi-GPU Priority (Hybrid: Intel iGPU primary for battery/smoothness, NVIDIA secondary for external HDMI/DP)
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card")
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card")
-- Multi-GPU Priority (colon-free symlinks pointing to by-path)
-- hl.env("AQ_DRM_DEVICES", home .. "/.config/hypr/intel-card:" .. home .. "/.config/hypr/nvidia-card")
hl.env("AQ_DRM_DEVICES", home .. "/.config/hypr/nvidia-card:" .. home .. "/.config/hypr/intel-card")

-- Qt & Quickshell
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_WAYLAND_RECONNECT", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QSG_RHI_BACKEND", "opengl")

-- GTK
hl.env("GDK_BACKEND", "wayland,x11,*")

-- extra screen
-- hl.env("AQ_FORCE_LINEAR_BLIT", "0")
-- hl.env("AQ_MGPU_NO_EXPLICIT", "1")

-- When gpu is used as Discrete-only from bios
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
