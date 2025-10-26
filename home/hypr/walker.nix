{
  programs.walker.enable = true;
  programs.walker.runAsService = true;
  programs.walker.config = {
	selection_wrap = true;
	disable_mouse = true;
	keybinds.quick_activate = [ "F1" "F2" "F3" "F4" "F5" ];
	theme = "tokyo-night";
  };
  programs.walker.themes = {
    "tokyo-night" = {
      style = ''
@define-color window_bg_color #1a1b26;
@define-color accent_bg_color #414868;
@define-color theme_fg_color #7ff9e9;
@define-color border_color #33ccff;
@define-color error_bg_color #f7768e;
@define-color error_fg_color #1a1b26;
@define-color hint_color #e5eae9;

* {
  all: unset;
}

.normal-icons {
  -gtk-icon-size: 16px;
}

.large-icons {
  -gtk-icon-size: 32px;
}

scrollbar {
  opacity: 0;
}

.box-wrapper {
  box-shadow:
    0 19px 38px rgba(0, 0, 0, 0.3),
    0 15px 12px rgba(0, 0, 0, 0.22);
  background: alpha(@window_bg_color, 0.95);
  padding: 20px;
  border-radius: 20px;
  border: 2px solid darker(@border_color);
}

.preview-box,
.elephant-hint,
.placeholder {
  color: @theme_fg_color;
}

.box {
}

.search-container {
  border-radius: 10px;
}

.input placeholder {
  opacity: 0.5;
}

.input {
  caret-color: @theme_fg_color;
  background: lighter(@window_bg_color);
  padding: 10px;
  color: @theme_fg_color;
}

.input:focus,
.input:active {
}

.content-container {
}

.placeholder {
}

.scroll {
}

.list {
  color: @theme_fg_color;
}

child {
}

.item-box {
  border-radius: 10px;
  padding: 10px;
}

.item-quick-activation {
  background: alpha(@accent_bg_color, 0.25);
  border-radius: 5px;
  padding: 10px;
}

child:hover .item-box,
child:selected .item-box {
  background: alpha(@accent_bg_color, 0.25);
}

.item-text-box {
}

.item-subtext {
  font-size: 12px;
  opacity: 0.5;
}

.providerlist .item-subtext {
  font-size: unset;
  opacity: 0.75;
}

.item-image-text {
  font-size: 28px;
}

.preview {
  border: 1px solid alpha(@accent_bg_color, 0.25);
  padding: 10px;
  border-radius: 10px;
  color: @theme_fg_color;
}

.calc .item-text {
  font-size: 24px;
}

.calc .item-subtext {
}

.symbols .item-image {
  font-size: 24px;
}

.todo.done .item-text-box {
  opacity: 0.25;
}

.todo.urgent {
  font-size: 24px;
}

.todo.active {
  font-weight: bold;
}

.bluetooth.disconnected {
  opacity: 0.5;
}

.preview .large-icons {
  -gtk-icon-size: 64px;
}

.keybinds-wrapper {
  border-top: 1px solid lighter(@window_bg_color);
  font-size: 12px;
  opacity: 0.5;
  color: @theme_fg_color;
}

.keybinds {
}

.keybind {
}

.keybind-bind {
  color: lighter(@hint_color);
  font-weight: bold;
  text-transform: lowercase;
}

.keybind-label {
  color: lighter(@hint_color);
}

.error {
  padding: 10px;
  background: @error_bg_color;
  color: @error_fg_color;
}

:not(.calc).current {
  font-style: italic;
}
      '';
    };
  };
}
