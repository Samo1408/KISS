#!/usr/bin/env bash
# apply-modifications.sh
# Can be run from ANY directory — it auto-detects its own location.
# Usage:
#   bash patches/apply-modifications.sh          # from KISS root
#   cd patches && bash apply-modifications.sh    # from patches dir
#   bash /absolute/path/patches/apply-modifications.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths — work correctly no matter where the script is called from
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR"
KISS_ROOT="$(dirname "$SCRIPT_DIR")"

# Verify we have the right KISS root by checking for gradlew
if [ ! -f "$KISS_ROOT/gradlew" ]; then
    echo "ERROR: Could not find gradlew at '$KISS_ROOT/gradlew'."
    echo "       Make sure 'patches/' is a direct child of the KISS source root."
    exit 1
fi

cd "$KISS_ROOT"

JAVA_SRC="app/src/main/java/fr/neamar/kiss"
RES_SRC="app/src/main/res"

echo "=== Applying KISS Modifications ==="
echo "Script dir : $SCRIPT_DIR"
echo "Patches dir: $PATCHES_DIR"
echo "KISS root  : $KISS_ROOT"
echo "Working dir: $(pwd)"

# ---------------------------------------------------------------------------
# 1. Copy new Java source files
# ---------------------------------------------------------------------------
echo ""
echo "[1/8] Copying new Java source files..."

cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/AppDrawerActivity.java"     "$JAVA_SRC/"
cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/AppDrawerFragment.java"      "$JAVA_SRC/"
cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/AppDrawerGridAdapter.java"   "$JAVA_SRC/"
cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/SelectionManager.java"       "$JAVA_SRC/"

echo "    OK"

# ---------------------------------------------------------------------------
# 2. Copy new XML layout files
# ---------------------------------------------------------------------------
echo "[2/8] Copying new layout/resource files..."

cp "$PATCHES_DIR/src/main/res/layout/activity_app_drawer.xml"   "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/fragment_app_drawer.xml"   "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/item_app_drawer_icon.xml"  "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/item_app_drawer_folder.xml" "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/dialog_create_folder.xml"  "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/xml/file_provider_paths.xml"      "$RES_SRC/xml/"

echo "    OK"

# ---------------------------------------------------------------------------
# 3. Merge new strings into strings.xml
# ---------------------------------------------------------------------------
echo "[3/8] Merging new strings into res/values/strings.xml..."

STRINGS_FILE="$RES_SRC/values/strings.xml"
STRINGS_ADDITIONS="$PATCHES_DIR/src/main/res/values/strings_additions.xml"

python3 - "$STRINGS_FILE" "$STRINGS_ADDITIONS" <<'PYEOF'
import sys, re

strings_path = sys.argv[1]
additions_path = sys.argv[2]

with open(strings_path, 'r', encoding='utf-8') as f:
    content = f.read()

with open(additions_path, 'r', encoding='utf-8') as f:
    additions = f.read().strip()

# Remove leading <?xml...?> line if present in additions
additions = re.sub(r'<\?xml[^?]*\?>\s*', '', additions)

# Insert the new strings before the closing </resources> tag
content = content.rstrip()
if content.endswith('</resources>'):
    content = content[:-len('</resources>')] + '\n' + additions + '\n</resources>\n'
else:
    content = content + '\n' + additions + '\n</resources>\n'

with open(strings_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("    strings.xml merged OK")
PYEOF

# ---------------------------------------------------------------------------
# 4. Merge new arrays into arrays.xml
# ---------------------------------------------------------------------------
echo "[4/8] Merging new arrays into res/values/arrays.xml..."

ARRAYS_FILE="$RES_SRC/values/arrays.xml"
ARRAYS_ADDITIONS="$PATCHES_DIR/src/main/res/values/arrays_additions.xml"

python3 - "$ARRAYS_FILE" "$ARRAYS_ADDITIONS" <<'PYEOF'
import sys, re

arrays_path = sys.argv[1]
additions_path = sys.argv[2]

with open(arrays_path, 'r', encoding='utf-8') as f:
    content = f.read()

with open(additions_path, 'r', encoding='utf-8') as f:
    additions = f.read()

# Extract just the inner elements (between <resources> and </resources>)
inner = re.search(r'<resources[^>]*>(.*?)</resources>', additions, re.DOTALL)
if inner:
    new_entries = inner.group(1).strip()
    content = content.rstrip()
    if content.endswith('</resources>'):
        content = content[:-len('</resources>')] + '\n    ' + new_entries + '\n</resources>\n'
    else:
        content = content + '\n    ' + new_entries + '\n</resources>\n'

with open(arrays_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("    arrays.xml merged OK")
PYEOF

# ---------------------------------------------------------------------------
# 5. Patch AppResult.java — add new long-press menu items
# ---------------------------------------------------------------------------
echo "[5/8] Patching AppResult.java (long-press menu)..."

APPRESULT="$JAVA_SRC/result/AppResult.java"

python3 - "$APPRESULT" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

# ── New imports ──────────────────────────────────────────────────────────────
new_imports = (
    "import fr.neamar.kiss.SelectionManager;\n"
    "import java.io.BufferedReader;\n"
    "import java.io.InputStreamReader;\n"
    "import java.util.ArrayList;\n"
    "import java.util.List;\n"
)
src = src.replace(
    "import fr.neamar.kiss.utils.fuzzy.FuzzyScore;",
    "import fr.neamar.kiss.utils.fuzzy.FuzzyScore;\n" + new_imports
)

# ── Add new menu items to buildPopupMenu() ───────────────────────────────────
old_hibernate_block = (
    "        // append root menu if available\n"
    "        if (KissApplication.getApplication(context).getRootHandler().isRootActivated() && KissApplication.getApplication(context).getRootHandler().isRootAvailable()) {\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_app_hibernate));\n"
    "        }"
)
new_hibernate_block = (
    "        // append root menu if available\n"
    "        if (KissApplication.getApplication(context).getRootHandler().isRootActivated() && KissApplication.getApplication(context).getRootHandler().isRootAvailable()) {\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_app_hibernate));\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_advanced_permissions));\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_share_apk));\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_install_other_user));\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_show_data_dir));\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_show_app_dir));\n"
    "            adapter.add(new ListPopup.Item(context, R.string.menu_select_app));\n"
    "        }\n"
    "        adapter.add(new ListPopup.Item(context, R.string.menu_double_tap_sleep));"
)
if old_hibernate_block in src:
    src = src.replace(old_hibernate_block, new_hibernate_block)
else:
    print("    WARNING: hibernate block not found — menu items NOT added")

# ── Add click handlers to popupMenuClickHandler() ────────────────────────────
old_super = "        return super.popupMenuClickHandler(context, parent, stringId, parentView);"
new_cases = (
    "        } else if (stringId == R.string.menu_advanced_permissions) {\n"
    "            openAdvancedPermissions(context);\n"
    "            return true;\n"
    "        } else if (stringId == R.string.menu_share_apk) {\n"
    "            shareApk(context);\n"
    "            return true;\n"
    "        } else if (stringId == R.string.menu_install_other_user) {\n"
    "            installToOtherUser(context);\n"
    "            return true;\n"
    "        } else if (stringId == R.string.menu_show_data_dir) {\n"
    "            openDataDir(context);\n"
    "            return true;\n"
    "        } else if (stringId == R.string.menu_show_app_dir) {\n"
    "            openAppDir(context);\n"
    "            return true;\n"
    "        } else if (stringId == R.string.menu_select_app) {\n"
    "            SelectionManager.getInstance().toggleSelect(pojo, parent);\n"
    "            return true;\n"
    "        } else if (stringId == R.string.menu_double_tap_sleep) {\n"
    "            KissApplication.getApplication(context).getRootHandler().sleepScreen(context);\n"
    "            return true;\n"
    "        }\n"
    "        return super.popupMenuClickHandler(context, parent, stringId, parentView);"
)
if old_super in src:
    src = src.replace(old_super, new_cases)
else:
    print("    WARNING: super handler call not found — click cases NOT added")

# ── Append helper methods before last closing brace ───────────────────────────
helper_methods = r"""
    // -----------------------------------------------------------------------
    // Methods added by kiss-modifications patch
    // -----------------------------------------------------------------------

    private void openAdvancedPermissions(Context context) {
        String pkg = pojo.packageName;
        android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
        builder.setTitle(context.getString(R.string.menu_advanced_permissions));
        String[] items = {
            context.getString(R.string.perm_usage_stats),
            context.getString(R.string.perm_all_files),
            context.getString(R.string.perm_unknown_sources)
        };
        builder.setItems(items, (dialog, which) -> {
            android.content.Intent intent;
            switch (which) {
                case 0:
                    intent = new android.content.Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS);
                    break;
                case 1:
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        intent = new android.content.Intent(
                                android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                android.net.Uri.parse("package:" + pkg));
                    } else {
                        intent = new android.content.Intent(
                                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:" + pkg));
                    }
                    break;
                default:
                    intent = new android.content.Intent(
                            android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            android.net.Uri.parse("package:" + pkg));
                    break;
            }
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
            try {
                context.startActivity(intent);
            } catch (Exception e) {
                android.widget.Toast.makeText(context, R.string.error_open_settings,
                        android.widget.Toast.LENGTH_SHORT).show();
            }
        });
        builder.show();
    }

    private void shareApk(final Context context) {
        new android.os.AsyncTask<Void, Void, java.util.List<android.net.Uri>>() {
            @Override
            protected java.util.List<android.net.Uri> doInBackground(Void... v) {
                java.util.List<android.net.Uri> uris = new java.util.ArrayList<>();
                try {
                    android.content.pm.PackageInfo pi =
                            context.getPackageManager().getPackageInfo(pojo.packageName, 0);
                    String sourceDir = pi.applicationInfo.publicSourceDir;
                    if (sourceDir != null) {
                        uris.add(androidx.core.content.FileProvider.getUriForFile(
                                context,
                                context.getPackageName() + ".fileprovider",
                                new java.io.File(sourceDir)));
                    }
                    String[] splitDirs = pi.applicationInfo.splitPublicSourceDirs;
                    if (splitDirs != null) {
                        for (String split : splitDirs) {
                            uris.add(androidx.core.content.FileProvider.getUriForFile(
                                    context,
                                    context.getPackageName() + ".fileprovider",
                                    new java.io.File(split)));
                        }
                    }
                } catch (android.content.pm.PackageManager.NameNotFoundException e) {
                    Log.w(TAG, "Package not found for APK share", e);
                }
                return uris;
            }

            @Override
            protected void onPostExecute(java.util.List<android.net.Uri> uris) {
                if (uris.isEmpty()) {
                    android.widget.Toast.makeText(context, R.string.error_share_apk,
                            android.widget.Toast.LENGTH_SHORT).show();
                    return;
                }
                android.content.Intent shareIntent =
                        new android.content.Intent(android.content.Intent.ACTION_SEND_MULTIPLE);
                shareIntent.setType("application/vnd.android.package-archive");
                shareIntent.putParcelableArrayListExtra(
                        android.content.Intent.EXTRA_STREAM, new java.util.ArrayList<>(uris));
                shareIntent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION);
                context.startActivity(android.content.Intent.createChooser(
                        shareIntent, context.getString(R.string.menu_share_apk)));
            }
        }.execute();
    }

    private void installToOtherUser(Context context) {
        fr.neamar.kiss.RootHandler rootHandler =
                KissApplication.getApplication(context).getRootHandler();
        java.util.List<String> users = rootHandler.getInstalledUsers();
        if (users.isEmpty()) {
            android.widget.Toast.makeText(context, R.string.error_no_other_users,
                    android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        String[] userArr = users.toArray(new String[0]);
        android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
        builder.setTitle(R.string.menu_install_other_user);
        builder.setItems(userArr, (dialog, which) -> {
            String userEntry = userArr[which];
            String userId = userEntry.replaceAll("[^0-9]", "");
            boolean ok = rootHandler.installExistingToUser(pojo.packageName, userId);
            int msgRes = ok ? R.string.install_user_success : R.string.install_user_error;
            android.widget.Toast.makeText(context,
                    context.getString(msgRes, userEntry), android.widget.Toast.LENGTH_SHORT).show();
        });
        builder.setNegativeButton(android.R.string.cancel, null);
        builder.show();
    }

    private void openDataDir(Context context) {
        KissApplication.getApplication(context).getRootHandler()
                .openInRootExplorer(context, "/data/data/" + pojo.packageName);
    }

    private void openAppDir(Context context) {
        KissApplication.getApplication(context).getRootHandler()
                .openInRootExplorer(context, "/data/app/" + pojo.packageName);
    }
"""

last = src.rfind("}")
src = src[:last] + helper_methods + "\n}"

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("    AppResult.java patched OK")
PYEOF

# ---------------------------------------------------------------------------
# 6. Patch RootHandler.java — add new root operations
# ---------------------------------------------------------------------------
echo "[6/8] Patching RootHandler.java (new root operations)..."

ROOTHANDLER="$JAVA_SRC/RootHandler.java"

python3 - "$ROOTHANDLER" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

# Add new imports
src = src.replace(
    "import java.nio.charset.StandardCharsets;",
    "import java.io.BufferedReader;\n"
    "import java.io.InputStreamReader;\n"
    "import java.util.ArrayList;\n"
    "import java.util.List;\n"
    "import java.nio.charset.StandardCharsets;"
)

# Add context import if missing
if "import android.content.Context;" not in src:
    src = src.replace(
        "package fr.neamar.kiss;",
        "package fr.neamar.kiss;\n\nimport android.content.Context;"
    )

new_methods = r"""
    // -----------------------------------------------------------------------
    // Methods added by kiss-modifications patch
    // -----------------------------------------------------------------------

    /** Turn off the screen / lock the device using root */
    public void sleepScreen(Context context) {
        try {
            executeRootShell("input keyevent 26");
        } catch (Exception e) {
            Log.d(TAG, "sleepScreen failed", e);
        }
    }

    /**
     * Returns a list of non-owner user descriptions, e.g. ["User 10 (id:10)"].
     * Parses output of: pm list users
     */
    public List<String> getInstalledUsers() {
        List<String> users = new ArrayList<>();
        String output = executeRootShellAndGetOutput("pm list users");
        if (output == null) return users;
        for (String line : output.split("\n")) {
            line = line.trim();
            if (line.startsWith("UserInfo{")) {
                String inner = line.substring(9);
                int end = inner.indexOf('}');
                if (end > 0) inner = inner.substring(0, end);
                String[] parts = inner.split(":");
                if (parts.length >= 2) {
                    String uid = parts[0].trim();
                    String uname = parts[1].trim();
                    if (!"0".equals(uid)) {            // skip owner (id 0)
                        users.add(uname + " (id:" + uid + ")");
                    }
                }
            }
        }
        return users;
    }

    /** Run: pm install-existing --user <userId> <packageName> via root */
    public boolean installExistingToUser(String packageName, String userId) {
        try {
            return executeRootShell(
                    "pm install-existing --user " + userId + " " + packageName);
        } catch (Exception e) {
            Log.d(TAG, "installExistingToUser failed", e);
            return false;
        }
    }

    /**
     * Open the given path in a supported root file manager.
     * Tries (in order): MiXplorer, MiXplorer Silver, MT Manager Canary, MT Manager.
     */
    public void openInRootExplorer(Context context, String path) {
        String[] explorerPackages = {
            "com.mixplorer",
            "com.mixplorer.silver",
            "bin.mt.plus.canary",
            "bin.mt.plus"
        };
        android.content.pm.PackageManager pm = context.getPackageManager();
        for (String pkg : explorerPackages) {
            try {
                pm.getPackageInfo(pkg, 0);
                android.content.Intent intent = new android.content.Intent(
                        android.content.Intent.ACTION_VIEW);
                intent.setPackage(pkg);
                intent.setDataAndType(
                        android.net.Uri.parse("file://" + path), "resource/folder");
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                return;
            } catch (Exception ignored) {
                // not installed or can't open — try next
            }
        }
        // Fallback: open via root shell am command
        try {
            executeRootShell("am start -a android.intent.action.VIEW"
                    + " -d \"file://" + path + "\""
                    + " -t resource/folder");
        } catch (Exception e) {
            Log.d(TAG, "openInRootExplorer fallback failed", e);
        }
    }

    /** Execute a root shell command and return its stdout as a String */
    private String executeRootShellAndGetOutput(String command) {
        Process p = null;
        try {
            p = Runtime.getRuntime().exec("su");
            p.getOutputStream().write(
                    (command + "\n").getBytes(StandardCharsets.UTF_8));
            p.getOutputStream().write("exit\n".getBytes(StandardCharsets.UTF_8));
            p.getOutputStream().flush();
            p.getOutputStream().close();

            BufferedReader reader = new BufferedReader(
                    new InputStreamReader(p.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append("\n");
            }
            p.waitFor();
            return sb.toString();
        } catch (Exception e) {
            Log.d(TAG, "executeRootShellAndGetOutput failed", e);
            return null;
        } finally {
            if (p != null) p.destroy();
        }
    }
"""

last = src.rfind("}")
src = src[:last] + new_methods + "\n}"

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("    RootHandler.java patched OK")
PYEOF

# ---------------------------------------------------------------------------
# 7. Patch AndroidManifest.xml — permissions + AppDrawerActivity + FileProvider
# ---------------------------------------------------------------------------
echo "[7/8] Patching AndroidManifest.xml..."

MANIFEST="app/src/main/AndroidManifest.xml"

python3 - "$MANIFEST" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

# ── New permissions ─────────────────────────────────────────────────────────
new_perms = (
    "\n"
    "    <!-- Usage stats access for Advanced Permissions feature -->\n"
    "    <uses-permission android:name=\"android.permission.PACKAGE_USAGE_STATS\"\n"
    "        tools:ignore=\"ProtectedPermissions\" />\n"
    "    <!-- All-files access for Advanced Permissions feature -->\n"
    "    <uses-permission android:name=\"android.permission.MANAGE_EXTERNAL_STORAGE\"\n"
    "        tools:ignore=\"ScopedStorage\" />\n"
    "    <!-- For sharing APK files -->\n"
    "    <uses-permission android:name=\"android.permission.READ_EXTERNAL_STORAGE\"\n"
    "        android:maxSdkVersion=\"32\" />\n"
)
timer_comment = "    <!-- To set timers -->"
if timer_comment in src:
    src = src.replace(timer_comment, new_perms + timer_comment)

# ── AppDrawerActivity + FileProvider ────────────────────────────────────────
new_activity = (
    "\n"
    "        <activity\n"
    "            android:name=\".AppDrawerActivity\"\n"
    "            android:label=\"@string/app_drawer_title\"\n"
    "            android:excludeFromRecents=\"true\"\n"
    "            android:exported=\"false\"\n"
    "            android:theme=\"@style/AppTheme\"\n"
    "            android:windowSoftInputMode=\"stateAlwaysHidden|adjustResize\" />\n"
    "\n"
    "        <provider\n"
    "            android:name=\"androidx.core.content.FileProvider\"\n"
    "            android:authorities=\"${applicationId}.fileprovider\"\n"
    "            android:exported=\"false\"\n"
    "            android:grantUriPermissions=\"true\">\n"
    "            <meta-data\n"
    "                android:name=\"android.support.FILE_PROVIDER_PATHS\"\n"
    "                android:resource=\"@xml/file_provider_paths\" />\n"
    "        </provider>\n"
)
dummy_marker = '        <activity\n            android:name=".DummyActivity"'
if dummy_marker in src:
    src = src.replace(dummy_marker, new_activity + dummy_marker)

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("    AndroidManifest.xml patched OK")
PYEOF

# ---------------------------------------------------------------------------
# 8. Done
# ---------------------------------------------------------------------------
echo "[8/8] All done."
echo ""
echo "=== Modifications applied successfully ==="
echo ""
echo "Changes summary:"
echo "  + AppDrawerActivity.java      (Personal/Work tabbed app drawer)"
echo "  + AppDrawerFragment.java      (tab fragment: sort + create-folder)"
echo "  + AppDrawerGridAdapter.java   (grid/list adapter + folder cards)"
echo "  + SelectionManager.java       (multi-select singleton)"
echo "  ~ AppResult.java              (8 new long-press menu items)"
echo "  ~ RootHandler.java            (5 new root helper methods)"
echo "  ~ AndroidManifest.xml         (permissions + AppDrawerActivity)"
echo "  ~ strings.xml                 (+30 new string resources)"
echo "  ~ arrays.xml                  (scroll direction entries)"
echo "  + activity_app_drawer.xml"
echo "  + fragment_app_drawer.xml"
echo "  + item_app_drawer_icon.xml"
echo "  + item_app_drawer_folder.xml"
echo "  + dialog_create_folder.xml"
echo "  + file_provider_paths.xml"
