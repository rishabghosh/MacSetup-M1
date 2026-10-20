"""Helpers for capture-settings.sh and restore-settings.sh that are easier in
Python than in bash: reading JSON, SQLite and zipped plugin files.

    python3 -I settings.py <command> <args>

Every command prints tab-separated lines and prints nothing (exit 0) when the
input is missing or unreadable, so the shell scripts can skip it quietly.
"""

import filecmp
import glob
import json
import os
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


def copy(args):
    """copy <source> <dest> [--undo <folder>] [--exclude <name>]... [--keep-existing]

    Copies a file, or a folder's contents, onto dest. Files and folders named
    in --exclude are skipped wherever they are. Files that differ at dest are
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
            dirs[:] = sorted(d for d in dirs if d not in exclude)
            for name in sorted(files):
                if name in exclude:
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


COMMANDS = {
    "chromium-profiles": chromium_profiles,
    "chromium-extensions": chromium_extensions,
    "chromium-search-engines": chromium_search_engines,
    "editor-extensions": editor_extensions,
    "firefox-addons": firefox_addons,
    "jetbrains-plugins": jetbrains_plugins,
    "jetbrains-app": jetbrains_app,
    "text-replacements": text_replacements,
}

if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "copy":
        copy(sys.argv[2:])
    elif len(sys.argv) == 3 and sys.argv[1] in COMMANDS:
        COMMANDS[sys.argv[1]](sys.argv[2])
    else:
        sys.exit("usage: settings.py {copy," + ",".join(COMMANDS) + "} <path> ...")
