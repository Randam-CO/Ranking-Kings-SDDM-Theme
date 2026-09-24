# Open Box Forest — SDDM theme

## 1. Drop in your assets
Copy your existing `assets/fonts/*.ttf`, `assets/icons/*.svg` and
`wallpaper.jpg` into this package's `assets/` folder, in the same
`fonts/` `icons/` layout you already had — nothing needs renaming,
`theme.conf` and the QML already point at those exact filenames.

## 2. Test it without installing
```
sddm-greeter --test-mode --theme /path/to/this/folder
```
(Package name for `sddm-greeter` varies by distro — it's usually in
the `sddm` package itself, sometimes a separate `sddm-*-qt5` dev
package.)

## 3. Install it for real
```
sudo cp -r /path/to/this/folder /usr/share/sddm/themes/open-box-forest
```
Then in `/etc/sddm.conf` (or a drop-in under `/etc/sddm.conf.d/`):
```
[Theme]
Current=open-box-forest
```

## What's wired to what
- **Session dropdown** reads your real installed sessions (SDDM's
  `sessionModel`), so "Open Box" only shows up if you actually have
  Openbox installed — it's not hardcoded.
- **User carousel** reads real system users (`userModel`); the small
  arrows page between them.
- **Password field** calls `sddm.login()` on Enter or the arrow button.
- **"WRONG PASSWORD!"** shows on `sddm`'s real `loginFailed` signal.
- **Power buttons** call the real `sddm.powerOff()/reboot()/suspend()`
  and grey themselves out if your system doesn't support that action.
- **"ES" indicator** reads SDDM's real keyboard-layout list and only
  shows up if you have more than one layout configured; click it to
  cycle.
- **Bottom "1 / 1" pager** and the settings modal's **Wallpaper**
  button both cycle through a `Backgrounds=` list in `theme.conf` —
  right now that list has just your one `wallpaper.jpg`, so it reads
  "1 / 1" exactly like your mockup. Add more comma-separated paths to
  `Backgrounds=` to make it a real slideshow.
- **Colors swatches** in the settings modal are live — clicking one
  re-tints the accent color for the rest of the session (resets on
  next login, since SDDM doesn't give greeters a way to write files
  back to disk).

## Two honest caveats
1. **Caps Lock warning**: stock SDDM (outside KDE Plasma's own
   greeter) doesn't expose the keyboard's *starting* Caps Lock state
   to QML at all — there's no API for it. What every community SDDM
   theme does instead, including this one, is notice the Caps Lock
   key being *pressed while the password field has focus* and flip a
   flag. It's genuinely the standard approach, but it means the
   warning won't appear if Caps Lock was already on before you
   clicked into the field.
2. **Wallpaper upload button**: the greeter runs as its own system
   user, which normally can't browse into your actual home folder, so
   a real "pick a file" dialog isn't reliable here. The upload icon
   instead advances through the `Backgrounds=` list above. If your
   setup does grant the greeter user read access to real image paths,
   you can swap it for a `QtQuick.Dialogs` `FileDialog` in
   `components/SettingsModal.qml`.

## Files
```
Main.qml                        greeter root, ties everything together
theme.conf                      all colors / fonts / formats (edit this first)
metadata.desktop                theme metadata SDDM reads on install
components/
  Clock.qml                     time (second.ttf) + date (main.ttf)
  UserCarousel.qml               avatar + name + paging arrows
  PasswordField.qml             key icon / password pill / eye / login arrow
  KeyboardLayoutIndicator.qml   the "ES" indicator, top-left
  SettingsModal.qml             Session / Colors / Wallpaper / power card
  PowerOption.qml               one shutdown/restart/sleep button
  WallpaperPager.qml            the bottom "‹ 1 / 1 ›" control
  RoundIconButton.qml           shared circular icon button
assets/
  fonts/   <- put main.ttf, second.ttf here
  icons/   <- put your 14 svg icons here
  wallpaper.jpg   <- put your background here
```

## Requirements
Qt5 build: `qt5-quickcontrols2`, `qt5-graphicaleffects` is **not**
required — this theme deliberately avoids it so it works on minimal
setups. Written against QtQuick 2.15 / Controls 2.15 imports; if your
SDDM ships Qt6 only, drop the version numbers from the `import`
statements at the top of each `.qml` file (e.g. `import QtQuick` instead
of `import QtQuick 2.15`) and it should run unchanged.
