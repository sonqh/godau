# Gõ Dấu

Gõ Dấu is a Vietnamese input app for macOS. You type Telex, and the app changes the keys into Vietnamese letters as you type, with no underline under the word.

It is for people who type Vietnamese on a Mac with the ABC or U.S. keyboard. It needs macOS 13 or later and runs on Apple Silicon and Intel.

Gõ Dấu is a pre-release (version 0.1.0). The author uses it every day, and it is tested in a small set of apps. Read [Limits](#limits) before you rely on it.

## Install

### With the install script

No release is published yet. When one is, this command installs it:

```sh
curl -fsSL https://github.com/sonqh/vietmac/releases/latest/download/install.sh | sh
```

The script downloads the app, checks its SHA-256 and its code signature, puts `GoDau.app` in `/Applications`, and opens it. It does not use `sudo`. If you cannot write to `/Applications`, it uses `~/Applications`.

### From source

You need the Xcode Command Line Tools with Swift 6 or later.

```sh
git clone https://github.com/sonqh/vietmac.git
cd vietmac
make install
```

`make install` builds the app, puts it in `/Applications/GoDau.app`, and opens it.

## Type your first word

1. Open Gõ Dấu. A setup screen asks for two permissions: Input Monitoring and Accessibility. Grant both.
2. Find `EN` in the menu bar. Click it and choose `Vietnamese`. The title changes to `VI`.
3. Click in a text field and type `tieengs Vieetj`.

The field shows `tiếng Việt`.

## What it does

- Telex input with precomposed Unicode letters. The text you get is the same in every app.
- No underline and no pop-up while you type. Gõ Dấu sends the changed letters as ordinary key events.
- Works in every app you have not turned it off in. [Limits](#limits) lists the apps that are tested.
- A menu bar item shows `VI` or `EN` and holds every action.
- `Turn Off Vietnamese in <App>` in the menu stops Gõ Dấu in one app.
- An optional shortcut switches between Vietnamese and English. You set it in Settings.
- Gõ Dấu can open at login. You turn this on in Settings.
- The interface is in Vietnamese and English.

### Telex keys

Type the letter, then the tone key.

| Keys | Result |
| --- | --- |
| `s` `f` `r` `x` `j` | acute, grave, hook, tilde, dot |
| `aa` `aw` `ee` `oo` `ow` `uw` `dd` | â ă ê ô ơ ư đ |
| `z` | removes the tone |
| a tone key typed twice | removes the tone and keeps the letter |

## Limits

- Gõ Dấu supports Telex only. It has no VNI, no macros, and no other output encodings.
- It works only with the ABC or U.S. input source. With another source it pauses and does not switch the source for you.
- It does not change text in password fields, or while an app has secure input on.
- It changes only the letters that it saw you type in the current field. When it is not sure, it leaves the word as typed. This happens when you click inside existing text, press Delete, or when an address bar shows a suggestion. Type a space and then the word again.
- A field that does not report its caret position gets less checking. Gõ Dấu then follows your keys alone. If the caret moves in a way that Gõ Dấu cannot see, the next change may remove a wrong letter.
- Some apps draw their own text and do not report a text field. Gõ Dấu leaves your keys as typed there.

Tested, as of 2026-11-17:

| App | Where | How it was tested |
| --- | --- | --- |
| Chrome, Dia, Safari | Text fields on web pages | Scripted key events |
| Chrome, Dia, Safari | Address bar | Typing by hand |
| VS Code | Editor and Quick Open | Typing by hand |
| TextEdit | Document | Typing by hand |

Apple Notes and VS Code Find are not yet accepted. Other apps are not tested. Gõ Dấu still runs in them, and you can turn it off for one app from the menu.

Not yet verified: an install on a second Mac with the script, and the Intel build on Intel hardware.

## Permissions and privacy

Gõ Dấu needs two permissions.

- Input Monitoring lets Gõ Dấu receive the keys you press.
- Accessibility lets Gõ Dấu check the caret position and the kind of field. It also lets Gõ Dấu send the changed letters.

Gõ Dấu does not read text in other apps. It does not store or send what you type. It does not use the network.

The app has no Developer ID signature and is not notarized. After an update, macOS may ask you to grant Accessibility again.

## Remove it

1. Choose `Quit Gõ Dấu` from its menu.
2. Move `GoDau.app` from `/Applications` or `~/Applications` to the Trash.
3. Open System Settings, then Privacy & Security. Remove Gõ Dấu from Accessibility and Input Monitoring.

## For developers

- [Build, install, and package](docs/development.md#build-install-and-package): the `make` commands and the project layout.
- [Project status](docs/project-status.md): what is delivered, what is pending, and the active changes.
- [Architecture](docs/architecture.md) and [performance policy](docs/performance.md).
- [Provenance](docs/provenance.md): where the requirements and the research come from.

## Later work

VNI, macros, more layouts, and per-app modes may come later, when usage justifies them.

## Help and license

Report a problem in the [issue tracker](https://github.com/sonqh/vietmac/issues). The menu item `Save Diagnostic Report…` (hold Option) writes a report with no typed text. You can attach that report.

Gõ Dấu uses the [MIT license](LICENSE).
