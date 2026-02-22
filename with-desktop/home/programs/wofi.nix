{ ... }:
{
  xdg.configFile."wofi/config".text = ''
    width=620
    height=420
    location=center
    show=drun
    prompt=Search...
    filter_rate=100
    allow_markup=true
    no_actions=true
    halign=fill
    orientation=vertical
    content_halign=fill
    insensitive=true
    allow_images=true
    image_size=36
    gtk_dark=true
    term=kitty
  '';

  xdg.configFile."wofi/style.css".text = ''
    /* ── Tokyo Night palette ─────────────────────────────────────────── */
    @define-color background  #1a1b26;
    @define-color surface     #24283b;
    @define-color overlay     #2a2b3d;
    @define-color muted       #595959;
    @define-color subtle      #414868;
    @define-color text        #a9b1d6;
    @define-color text-bright #c0caf5;
    @define-color accent-blue #33ccff;
    @define-color accent-green #00ff99;

    * {
      font-family: JetBrainsMono Nerd Font, JetBrains Mono, monospace;
      font-size: 14px;
      color: @text;
    }

    /* ── GTK window base — must be transparent for rounding to work ──── */
    window {
      background: transparent;
    }

    /* ── Main window ─────────────────────────────────────────────────── */
    #window {
      background-color: @background;
      border-radius: 12px;
      border: 2px solid @accent-blue;
      box-shadow: 0 8px 32px alpha(#000000, 0.6);
    }

    /* ── Outer container ─────────────────────────────────────────────── */
    #outer-box {
      background-color: transparent;
      padding: 12px;
      border-radius: 12px;
    }

    /* ── Search input ────────────────────────────────────────────────── */
    #input {
      background-color: @surface;
      color: @text-bright;
      border: 1px solid @subtle;
      border-radius: 8px;
      padding: 8px 12px;
      margin-bottom: 8px;
      caret-color: @accent-blue;
      outline: none;
    }

    #input:focus {
      border-color: @accent-blue;
      box-shadow: 0 0 0 1px alpha(@accent-blue, 0.4);
    }

    /* ── Scrollable list ─────────────────────────────────────────────── */
    #scroll {
      background-color: transparent;
      border: none;
      margin: 0;
      padding: 0;
    }

    #inner-box {
      background-color: transparent;
    }

    /* ── Individual entries ──────────────────────────────────────────── */
    #entry {
      background-color: transparent;
      border-radius: 8px;
      padding: 6px 10px;
      margin: 2px 0;
      transition: background-color 100ms ease;
    }

    #entry:hover {
      background-color: @overlay;
    }

    #entry:selected {
      background-color: @overlay;
      border-left: 2px solid @accent-blue;
    }

    #entry:selected #text {
      color: @text-bright;
    }

    /* ── App name text ───────────────────────────────────────────────── */
    #text {
      color: @text;
      margin-left: 6px;
    }

    /* ── App icon ────────────────────────────────────────────────────── */
    #img {
      margin-right: 4px;
      border-radius: 4px;
    }
  '';
}
