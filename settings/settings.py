"""Helpers for capture-settings.sh and restore-settings.sh that are easier in
Python than in bash: reading JSON, SQLite and zipped plugin files, and
splitting a capture between the public repo and the private backup.

    python3 -I settings.py <command> <args>

Every command prints tab-separated lines and prints nothing (exit 0) when the
input is missing or unreadable, so the shell scripts can skip it quietly.
"""

import filecmp
import fnmatch
import glob
import json
import os
import plistlib
import re
import shutil
import sqlite3
import sys
import tempfile
import zipfile


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def query_copy(db, sql):
    """Runs sql on a copy of db, because browsers keep theirs locked."""
    if not os.path.isfile(db):
        return []
    with tempfile.TemporaryDirectory() as tmp:
        copy = os.path.join(tmp, "db")
        shutil.copy(db, copy)
        try:
            con = sqlite3.connect(copy)
            rows = con.execute(sql).fetchall()
            con.close()
            return rows
        except sqlite3.Error:
            return []


def clean(value):
    return str(value or "").replace("\t", " ").replace("\n", " ").strip()


def chromium_profiles(local_state):
    """<profile folder> <name> for each profile of a Chrome-like browser."""
    d = load_json(local_state) or {}
    cache = d.get("profile", {}).get("info_cache", {})
    for folder in sorted(cache):
        print(f"{folder}\t{clean(cache[folder].get('name'))}")


def extension_name(ext_dir):
    """The extension's name from the newest version's manifest, with __MSG_x__
    names looked up in its default locale."""
    versions = sorted(glob.glob(os.path.join(ext_dir, "*", "manifest.json")))
    if not versions:
        return ""
    manifest = load_json(versions[-1]) or {}
    name = manifest.get("name", "")
    m = re.fullmatch(r"__MSG_(\w+)__", name)
    if m:
        root = os.path.dirname(versions[-1])
        locale = manifest.get("default_locale", "en")
        messages = load_json(os.path.join(root, "_locales", locale, "messages.json")) or {}
        wanted = m.group(1).lower()
        for key, value in messages.items():
            if key.lower() == wanted:
                return value.get("message", name)
    return name


def chromium_extensions(profile):
    """<id> <name> for each extension installed in a Chrome-like profile."""
    root = os.path.join(profile, "Extensions")
    if not os.path.isdir(root):
        return
    for ext_id in sorted(os.listdir(root)):
        if ext_id.startswith(".") or ext_id == "Temp":
            continue
        print(f"{ext_id}\t{clean(extension_name(os.path.join(root, ext_id)))}")


def chromium_search_engines(web_data):
    """Search engines you added yourself: <keyword> <name> <url>. Chrome's
    own @bookmarks, @history, ... shortcuts are left out."""
    rows = query_copy(
        web_data,
        "SELECT keyword, short_name, url FROM keywords "
        "WHERE prepopulate_id = 0 AND keyword NOT LIKE '@%' ORDER BY keyword",
    )
    for keyword, name, url in rows:
        print(f"{clean(keyword)}\t{clean(name)}\t{clean(url)}")


def editor_extensions(extensions_json):
    """Extension ids from a VS Code-like extensions.json."""
    for ext in load_json(extensions_json) or []:
        ext_id = ext.get("identifier", {}).get("id")
        if ext_id:
            print(ext_id)


def firefox_addons(extensions_json):
    """<id> <name> for each add-on you installed in a Firefox profile."""
    d = load_json(extensions_json) or {}
    for addon in d.get("addons", []):
        if addon.get("location") != "app-profile":
            continue
        name = addon.get("defaultLocale", {}).get("name", "")
        print(f"{addon.get('id')}\t{clean(name)}")


def plugin_id(jar):
    try:
        with zipfile.ZipFile(jar) as z:
            xml = z.read("META-INF/plugin.xml").decode("utf-8", "replace")
    except (OSError, KeyError, zipfile.BadZipFile):
        return None
    m = re.search(r"<id>\s*([^<]+?)\s*</id>", xml)
    return m.group(1) if m else None


def jetbrains_plugins(plugins_dir):
    """<plugin id> <folder> for each plugin you installed in a JetBrains IDE.
    A plugin is either a folder with lib/*.jar or a single jar."""
    if not os.path.isdir(plugins_dir):
        return
    for entry in sorted(os.listdir(plugins_dir)):
        path = os.path.join(plugins_dir, entry)
        jars = [path] if entry.endswith(".jar") else sorted(glob.glob(os.path.join(path, "lib", "*.jar")))
        for jar in jars:
            found = plugin_id(jar)
            if found:
                print(f"{found}\t{entry}")
                break


def jetbrains_app(app):
    """<config folder name> <launcher path> for a JetBrains .app, from its
    product-info.json, e.g. WebStorm2026.1 and .../MacOS/webstorm."""
    info = load_json(os.path.join(app, "Contents", "Resources", "product-info.json"))
    if not info or not info.get("dataDirectoryName"):
        return
    launcher = (info.get("launch") or [{}])[0].get("launcherPath", "")
    path = os.path.normpath(os.path.join(app, "Contents", "Resources", launcher)) if launcher else ""
    print(f"{info['dataDirectoryName']}\t{path}")


def text_replacements(db):
    """Your keyboard text replacements: <shortcut> <phrase>."""
    rows = query_copy(
        db,
        "SELECT ZSHORTCUT, ZPHRASE FROM ZTEXTREPLACEMENTENTRY "
        "WHERE ZWASDELETED = 0 OR ZWASDELETED IS NULL ORDER BY ZSHORTCUT",
    )
    for shortcut, phrase in rows:
        print(f"{clean(shortcut)}\t{clean(phrase)}")


# Keys as System Settings → Keyboard → Modifier Keys saves them: HID usage page
# 7 (keyboard) or 0xFF (Apple vendor, for fn) in the high bits, usage below.
MODIFIER_KEYS = {
    0x700000039: "Caps Lock",
    0x7000000E0: "Control", 0x7000000E4: "Control",
    0x7000000E1: "Shift", 0x7000000E5: "Shift",
    0x7000000E2: "Option", 0x7000000E6: "Option",
    0x7000000E3: "Command", 0x7000000E7: "Command",
    0x700000029: "Escape",
    0xFF00000003: "fn (Globe)", 0xFF00000004: "fn (Globe)",
    0x700000000: "No Action", 0: "No Action",
}


def modifier_keys(plist):
    """Your modifier key changes, from the currentHost NSGlobalDomain plist:
    <vendor id> <product id> <hidutil property JSON> <what changed>, one line
    per keyboard. The built-in keyboard is 0 0. The JSON sets the property
    macOS itself sets from these preferences at login, so it can be applied
    now without being applied twice later."""
    try:
        with open(plist, "rb") as f:
            prefs = plistlib.load(f)
    except Exception:  # plistlib raises several kinds on odd plists
        return
    for key in sorted(prefs):
        m = re.fullmatch(r"com\.apple\.keyboard\.modifiermapping\.(\d+)-(\d+)-\d+", key)
        if not m or not isinstance(prefs[key], list):
            continue
        pairs = [
            (item["HIDKeyboardModifierMappingSrc"], item["HIDKeyboardModifierMappingDst"])
            for item in prefs[key]
            if isinstance(item, dict) and "HIDKeyboardModifierMappingSrc" in item and "HIDKeyboardModifierMappingDst" in item
        ]
        if not pairs:
            continue
        mapping = {"HIDKeyboardModifierMappingPairs": [{"HIDKeyboardModifierMappingSrc": s, "HIDKeyboardModifierMappingDst": d} for s, d in pairs]}
        changes = []
        for s, d in pairs:
            change = f"{MODIFIER_KEYS.get(s, hex(s))} → {MODIFIER_KEYS.get(d, hex(d))}"
            if change not in changes:
                changes.append(change)
        print(f"{m.group(1)}\t{m.group(2)}\t{json.dumps(mapping)}\t{', '.join(changes)}")


def excluded(name, patterns):
    return any(fnmatch.fnmatchcase(name, p) for p in patterns)


def copy(args):
    """copy <source> <dest> [--undo <folder>] [--exclude <name>]... [--keep-existing]

    Copies a file, or a folder's contents, onto dest. Files and folders named
    in --exclude (a name or a pattern like undo-*) are skipped wherever they
    are. Files that differ at dest are
    replaced, after being saved under the undo folder, or left alone with
    --keep-existing. Prints how many files it copied."""
    src, dest, rest = args[0], args[1], args[2:]
    undo, exclude, keep = None, set(), False
    while rest:
        flag = rest.pop(0)
        if flag == "--undo":
            undo = rest.pop(0)
        elif flag == "--exclude":
            exclude.add(rest.pop(0))
        elif flag == "--keep-existing":
            keep = True
        else:
            sys.exit("copy: unknown option " + flag)

    if os.path.isfile(src):
        pairs = [("", src, dest)]
    else:
        pairs = []
        for root, dirs, files in os.walk(src):
            dirs[:] = sorted(d for d in dirs if not excluded(d, exclude))
            for name in sorted(files):
                if excluded(name, exclude):
                    continue
                rel = os.path.relpath(os.path.join(root, name), src)
                pairs.append((rel, os.path.join(root, name), os.path.join(dest, rel)))

    copied = 0
    for rel, s, d in pairs:
        if os.path.lexists(d):
            if keep or (os.path.isfile(d) and filecmp.cmp(s, d, shallow=False)):
                continue
            if undo:
                saved = os.path.join(undo, rel or os.path.basename(d))
                os.makedirs(os.path.dirname(saved), exist_ok=True)
                shutil.move(d, saved)
            else:
                os.remove(d)
        os.makedirs(os.path.dirname(d) or ".", exist_ok=True)
        shutil.copy2(s, d)
        copied += 1
    print(copied)


# ---------------------------------------------------------------------------
# Splitting a capture: what has no secrets goes in the repo, which is public,
# and the rest goes to the private backup.

# Settings that may go in the repo, as paths inside the capture. * matches
# within one folder and ** across folders.
JETBRAINS_PUBLIC = [
    "options/**", "keymaps/**", "codestyles/**", "colors/**", "templates/**", "fileTemplates/**",
    "inspection/**", "quicklists/**", "tools/**", "plugins.tsv", "disabled_plugins.txt", "*.vmoptions",
]
PUBLIC = [
    "system/defaults/*.plist",
    "system/currentHost/*.plist",
    "system/Services/**",
    "system/info.txt",
    "dotfiles/**",
    "apps/iterm2/**",
    "apps/editors/**",
    "browsers/*/profiles.tsv",
    "browsers/*/*/extensions.tsv",
    "browsers/*/*/search-engines.tsv",
    "browsers/Firefox/*/user.js",
    "browsers/Firefox/*/chrome/**",
] + [f"apps/{app}/*/{path}" for app in ("webstorm", "jetbrains") for path in JETBRAINS_PUBLIC]

# Exceptions that stay private: credentials-adjacent dotfiles, and JetBrains
# options files that hold accounts, tokens, recent projects or usage data
# rather than settings.
# known_hosts is the one file in ~/.ssh that may go in the repo: it holds
# servers' public host keys, nothing of yours.
SSH_PUBLIC = {"dotfiles/.ssh/known_hosts"}
PRIVATE = [
    "dotfiles/.ssh/**",
    "dotfiles/.aws/**",
    "dotfiles/.npmrc",
]
JETBRAINS_STATE = re.compile(
    r"recent|trusted-paths|statistic|usage|updates|summary|eventlog|feedback|survey|promo|quota"
    r"|termsofservice|settingssync|licen[cs]e|github|gitlab|copilot|openrouter|account|security"
    r"|oauth|token|passw|proxy|window\.state|pluginfreezes|\.local\.xml$",
    re.I,
)

# Plist keys dropped before a plist goes in the repo. SECRET_KEY always;
# HISTORY_KEY when it holds a list, text or data (recent folders, recent apps)
# rather than an on/off setting like show-recents.
SECRET_KEY = re.compile(r"token|secret|passw|credential|cookie|licen[cs]e|serial|auth(?!or)|api.?key", re.I)
HISTORY_KEY = re.compile(r"recent|history|lastrootdirectory|bookmark$", re.I)

# Text that means a file holds a secret, so it stays out of the repo.
SECRET_TEXT = [
    re.compile(p)
    for p in [
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
        r"\bAKIA[0-9A-Z]{16}\b",  # AWS access key
        r"\bgh[pousr]_[A-Za-z0-9]{30,}",  # GitHub token
        r"\bgithub_pat_\w{20,}",
        r"\bsk-[A-Za-z0-9_-]{20,}",  # OpenAI / Anthropic key
        r"\bxox[abprs]-[\w-]{10,}",  # Slack token
        r"\bAIza[\w-]{35}",  # Google API key
        r"\bnpm_[A-Za-z0-9]{36}\b",
        r"\beyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]{10,}",  # JWT
        r"://[^/\s:@'\"<>]+:[^/\s@'\"<>]+@",  # password in a URL
        r"(?i)_authToken\s*=",
        # NAME=value or "name": "value" where the name says it's a secret and
        # the value isn't a number, true/false or a $VARIABLE.
        r"(?i)[\w.-]*(?:token|secret|passw(?:or)?d|api[_-]?key|access[_-]?key|private[_-]?key|auth)[\w.-]*"
        r"[\"']?\s*[:=]\s*[\"']?(?![\d.]+\b|true\b|false\b|null\b|\$)[^\s\"',;<>{}\[\]]{8,}",
        # <option name="token" value="..."/> in JetBrains files
        r"(?i)name=\"[^\"]*(?:token|secret|passw|api[_-]?key)[^\"]*\"\s+value=\"[^\"]{8,}\"",
        # <key>...token...</key><string> in plists
        r"(?i)<key>[^<]*(?:token|secret|passw|api[_-]?key)[^<]*</key>\s*<(?:string|data)>",
    ]
]


def glob_regex(pattern):
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


PUBLIC_RE = [glob_regex(p) for p in PUBLIC]
PRIVATE_RE = [glob_regex(p) for p in PRIVATE]


def is_public(rel):
    if rel in SSH_PUBLIC:
        return True
    if any(r.match(rel) for r in PRIVATE_RE):
        return False
    if re.match(r"apps/(webstorm|jetbrains)/[^/]+/options/", rel) and JETBRAINS_STATE.search(os.path.basename(rel)):
        return False
    return any(r.match(rel) for r in PUBLIC_RE)


def clean_plist(value):
    """The plist without secret keys, recent files and file bookmarks."""
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if SECRET_KEY.search(key):
                continue
            if HISTORY_KEY.search(key) and isinstance(item, (list, dict, str, bytes)):
                continue
            if isinstance(item, bytes) and item[:4] in (b"book", b"alis"):
                continue
            out[key] = clean_plist(item)
        return out
    if isinstance(value, list):
        return [clean_plist(item) for item in value if not (isinstance(item, bytes) and item[:4] in (b"book", b"alis"))]
    return value


def public_bytes(path):
    """The file as it goes in the repo: plists cleaned and saved as XML so
    they diff well. None if a plist can't be read."""
    with open(path, "rb") as f:
        data = f.read()
    if not path.endswith(".plist"):
        return data
    try:
        return plistlib.dumps(clean_plist(plistlib.loads(data)), fmt=plistlib.FMT_XML)
    except Exception:  # plistlib raises several kinds on odd plists
        return None


def secret_in(data):
    """Where the first secret-looking text is, as "line N", or None."""
    text = data.decode("utf-8", "ignore")
    for pattern in SECRET_TEXT:
        m = pattern.search(text)
        if m:
            return "line %d" % (text.count("\n", 0, m.start()) + 1)
    return None


# Where the repo keeps each app's settings: a folder in the capture and its
# appsettings/<app>/saved folder. JetBrains IDEs other than WebStorm get one
# folder each, named after the product (apps/jetbrains/PyCharm2026.1 goes to
# appsettings/pycharm/saved/PyCharm2026.1). Everything else, the system
# settings and dotfiles, goes to settings/saved.
APP_DIRS = [
    ("apps/webstorm", "webstorm"),
    ("apps/iterm2", "iterm2"),
    ("apps/editors/Code", "vscode"),
    ("apps/editors/Cursor", "cursor"),
    ("apps/editors/Antigravity", "antigravity"),
    ("browsers/Chrome", "chrome"),
    ("browsers/Brave", "brave"),
    ("browsers/Edge", "edge"),
    ("browsers/Firefox", "firefox"),
    ("browsers/Safari", "safari"),
]


def repo_path(rel):
    """Where a file of the capture goes in the repo, relative to its root."""
    for folder, app in APP_DIRS:
        if rel.startswith(folder + "/"):
            return os.path.join("appsettings", app, "saved", rel[len(folder) + 1 :])
    m = re.match(r"apps/jetbrains/(([A-Za-z]+)[^/]*)/(.*)", rel)
    if m:
        return os.path.join("appsettings", m.group(2).lower(), "saved", m.group(1), m.group(3))
    return os.path.join("settings", "saved", rel)


def capture_path(repo_rel):
    """The reverse of repo_path: where a saved file of the repo belongs in a
    capture. None if it isn't a saved setting."""
    parts = repo_rel.split("/")
    if parts[:2] == ["settings", "saved"] and len(parts) > 2:
        return "/".join(parts[2:])
    if parts[0] != "appsettings" or len(parts) < 4 or parts[2] != "saved":
        return None
    rest = "/".join(parts[3:])
    for folder, app in APP_DIRS:
        if parts[1] == app:
            return folder + "/" + rest
    return "apps/jetbrains/" + rest


def saved_files(root):
    """Every saved setting in the repo at root, as paths relative to it."""
    for top in [os.path.join(root, "settings", "saved")] + sorted(glob.glob(os.path.join(root, "appsettings", "*", "saved"))):
        for folder, dirs, files in os.walk(top):
            dirs.sort()
            for name in sorted(files):
                yield os.path.relpath(os.path.join(folder, name), root)


def gather(args):
    """gather <repo> <dest>

    Copies the settings saved in the repo (settings/saved and every
    appsettings/<app>/saved) into dest, laid out like a capture."""
    root, dest = args
    for rel in saved_files(root):
        target = capture_path(rel)
        if target:
            os.makedirs(os.path.dirname(os.path.join(dest, target)), exist_ok=True)
            shutil.copy2(os.path.join(root, rel), os.path.join(dest, target))


def clear(args):
    """clear <repo> [<capture folder>]

    Removes the settings saved in the repo, or only those that came from one
    folder of a capture (like apps/webstorm), before a new capture."""
    root, prefix = args[0], (args[1] if len(args) > 1 else "")
    for rel in list(saved_files(root)):
        target = capture_path(rel)
        if target and (not prefix or target.startswith(prefix.rstrip("/") + "/")):
            os.remove(os.path.join(root, rel))
    for top in [os.path.join(root, "settings", "saved")] + glob.glob(os.path.join(root, "appsettings", "*", "saved")):
        for folder, dirs, files in sorted(os.walk(top), reverse=True):
            if not os.listdir(folder):
                os.rmdir(folder)


def split(args):
    """split <capture> <repo> <private>

    Puts each file of the capture in the repo when it's on the PUBLIC list and
    nothing in it looks like a secret, and in the private folder otherwise.
    In the repo, each app's settings go to appsettings/<app>/saved and the rest
    to settings/saved (see repo_path). Prints what went where, and which files
    were kept out of the repo because they look like they hold a secret (never
    the secret itself)."""
    src, public, private = args
    n_public = n_private = 0
    held = []
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, src)
            data = None
            if is_public(rel):
                data = public_bytes(path)
                reason = secret_in(data) if data is not None else "unreadable plist"
                if reason:
                    held.append(f"{rel} ({reason})")
                    data = None
            dest = os.path.join(public, repo_path(rel)) if data is not None else os.path.join(private, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            if data is None:
                shutil.copy2(path, dest)
                n_private += 1
            else:
                with open(dest, "wb") as f:
                    f.write(data)
                n_public += 1
    print(f"  {n_public} files without secrets in the repo, in settings/saved and appsettings/*/saved")
    print(f"  {n_private} personal files in {private}")
    if held:
        print("  Kept out of the repo because they look like they hold a secret:")
        for item in held:
            print("    " + item)


COMMANDS = {
    "chromium-profiles": chromium_profiles,
    "chromium-extensions": chromium_extensions,
    "chromium-search-engines": chromium_search_engines,
    "editor-extensions": editor_extensions,
    "firefox-addons": firefox_addons,
    "jetbrains-plugins": jetbrains_plugins,
    "jetbrains-app": jetbrains_app,
    "text-replacements": text_replacements,
    "modifier-keys": modifier_keys,
}

if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "copy":
        copy(sys.argv[2:])
    elif len(sys.argv) == 5 and sys.argv[1] == "split":
        split(sys.argv[2:])
    elif len(sys.argv) == 4 and sys.argv[1] == "gather":
        gather(sys.argv[2:])
    elif len(sys.argv) in (3, 4) and sys.argv[1] == "clear":
        clear(sys.argv[2:])
    elif len(sys.argv) == 4 and sys.argv[1] == "repo-path":
        print(os.path.join(sys.argv[2], repo_path(sys.argv[3])))
    elif len(sys.argv) == 3 and sys.argv[1] in COMMANDS:
        COMMANDS[sys.argv[1]](sys.argv[2])
    else:
        sys.exit("usage: settings.py {copy,split,gather,clear,repo-path," + ",".join(COMMANDS) + "} <path> ...")
