#!/usr/bin/env bash
# apply-modifications.sh
# Usage: bash apply-modifications.sh <patches_dir>
# Run from the root of the KISS Launcher source tree.

set -euo pipefail

PATCHES_DIR="$(pwd)"
JAVA_SRC="app/src/main/java/fr/neamar/kiss"
RES_SRC="app/src/main/res"

echo "=== Applying KISS Modifications ==="
echo "Patches dir: $PATCHES_DIR"
echo "Working dir: $(pwd)"

# ---------------------------------------------------------------------------
# 1. Copy new Java source files
# ---------------------------------------------------------------------------
echo "[1/6] Copying new Java source files..."

cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/AppDrawerActivity.java"     "$JAVA_SRC/"
cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/AppDrawerFragment.java"      "$JAVA_SRC/"
cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/AppDrawerGridAdapter.java"   "$JAVA_SRC/"
cp "$PATCHES_DIR/src/main/java/fr/neamar/kiss/SelectionManager.java"       "$JAVA_SRC/"

# ---------------------------------------------------------------------------
# 2. Copy new XML layout files
# ---------------------------------------------------------------------------
echo "[2/6] Copying new layout/resource files..."

cp "$PATCHES_DIR/src/main/res/layout/activity_app_drawer.xml"  "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/fragment_app_drawer.xml"  "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/item_app_drawer_icon.xml" "$RES_SRC/layout/"
cp "$PATCHES_DIR/src/main/res/layout/dialog_create_folder.xml" "$RES_SRC/layout/"

# ---------------------------------------------------------------------------
# 3. Merge new strings into strings.xml
# ---------------------------------------------------------------------------
echo "[3/6] Merging new strings into res/values/strings.xml..."

# Remove closing </resources> tag, append new strings, re-add closing tag
sed -i 's|</resources>||' "$RES_SRC/values/strings.xml"
cat "$PATCHES_DIR/src/main/res/values/strings_additions.xml" >> "$RES_SRC/values/strings.xml"
echo "</resources>" >> "$RES_SRC/values/strings.xml"

# ---------------------------------------------------------------------------
# 4. Patch AppResult.java — add new long-press menu items
# ---------------------------------------------------------------------------
echo "[4/6] Patching AppResult.java (long-press menu)..."

APPRESULT="$JAVA_SRC/result/AppResult.java"

# 4a. Add new imports after existing imports block
python3 - <<'PYEOF'
import re, sys

with open("app/src/main/java/fr/neamar/kiss/result/AppResult.java", "r") as f:
    src = f.read()

new_imports = """import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.AsyncTask;
import android.widget.ListView;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import fr.neamar.kiss.SelectionManager;
"""

# Insert after last existing import
src = re.sub(
    r'(import fr\.neamar\.kiss\.utils\.fuzzy\.FuzzyScore;)',
    r'\1\n' + new_imports,
    src
)

# 4b. Add new menu items to buildPopupMenu()
old_hibernate = """        // append root menu if available
        if (KissApplication.getApplication(context).getRootHandler().isRootActivated() && KissApplication.getApplication(context).getRootHandler().isRootAvailable()) {
            adapter.add(new ListPopup.Item(context, R.string.menu_app_hibernate));
        }"""

new_hibernate = """        // append root menu if available
        if (KissApplication.getApplication(context).getRootHandler().isRootActivated() && KissApplication.getApplication(context).getRootHandler().isRootAvailable()) {
            adapter.add(new ListPopup.Item(context, R.string.menu_app_hibernate));
            adapter.add(new ListPopup.Item(context, R.string.menu_advanced_permissions));
            adapter.add(new ListPopup.Item(context, R.string.menu_share_apk));
            adapter.add(new ListPopup.Item(context, R.string.menu_install_other_user));
            adapter.add(new ListPopup.Item(context, R.string.menu_show_data_dir));
            adapter.add(new ListPopup.Item(context, R.string.menu_show_app_dir));
            adapter.add(new ListPopup.Item(context, R.string.menu_select_app));
        }
        adapter.add(new ListPopup.Item(context, R.string.menu_double_tap_sleep));"""

src = src.replace(old_hibernate, new_hibernate)

# 4c. Add handler cases to popupMenuClickHandler()
old_super = """        return super.popupMenuClickHandler(context, parent, stringId, parentView);"""

new_cases = """        } else if (stringId == R.string.menu_advanced_permissions) {
            openAdvancedPermissions(context);
            return true;
        } else if (stringId == R.string.menu_share_apk) {
            shareApk(context);
            return true;
        } else if (stringId == R.string.menu_install_other_user) {
            installToOtherUser(context);
            return true;
        } else if (stringId == R.string.menu_show_data_dir) {
            openDataDir(context);
            return true;
        } else if (stringId == R.string.menu_show_app_dir) {
            openAppDir(context);
            return true;
        } else if (stringId == R.string.menu_select_app) {
            SelectionManager.getInstance().toggleSelect(pojo, parent);
            return true;
        } else if (stringId == R.string.menu_double_tap_sleep) {
            KissApplication.getApplication(context).getRootHandler().sleepScreen(context);
            return true;
        }
        return super.popupMenuClickHandler(context, parent, stringId, parentView);"""

src = src.replace(old_super, new_cases)

# 4d. Append new helper methods before the last closing brace
helper_methods = """
    // -----------------------------------------------------------------------
    // New helper methods added by kiss-modifications patch
    // -----------------------------------------------------------------------

    /** Open Android permission settings for usagestats, all-files-access, unknown sources */
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
                        intent = new android.content.Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                android.net.Uri.parse("package:" + pkg));
                    } else {
                        intent = new android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:" + pkg));
                    }
                    break;
                default:
                    intent = new android.content.Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            android.net.Uri.parse("package:" + pkg));
                    break;
            }
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
            try { context.startActivity(intent); } catch (Exception e) {
                android.widget.Toast.makeText(context, R.string.error_open_settings, android.widget.Toast.LENGTH_SHORT).show();
            }
        });
        builder.show();
    }

    /** Share the APK file(s) for this app */
    private void shareApk(Context context) {
        new android.os.AsyncTask<Void, Void, java.util.List<android.net.Uri>>() {
            @Override
            protected java.util.List<android.net.Uri> doInBackground(Void... v) {
                java.util.List<android.net.Uri> uris = new java.util.ArrayList<>();
                try {
                    android.content.pm.PackageInfo pi = context.getPackageManager()
                            .getPackageInfo(pojo.packageName, 0);
                    String sourceDir = pi.applicationInfo.publicSourceDir;
                    if (sourceDir != null) {
                        java.io.File apk = new java.io.File(sourceDir);
                        android.net.Uri uri = androidx.core.content.FileProvider.getUriForFile(
                                context,
                                context.getPackageName() + ".fileprovider",
                                apk);
                        uris.add(uri);
                    }
                    // Also add split APKs if present
                    String[] splitDirs = pi.applicationInfo.splitPublicSourceDirs;
                    if (splitDirs != null) {
                        for (String split : splitDirs) {
                            java.io.File splitApk = new java.io.File(split);
                            android.net.Uri splitUri = androidx.core.content.FileProvider.getUriForFile(
                                    context,
                                    context.getPackageName() + ".fileprovider",
                                    splitApk);
                            uris.add(splitUri);
                        }
                    }
                } catch (android.content.pm.PackageManager.NameNotFoundException e) {
                    fr.neamar.kiss.utils.Log.w("AppResult", "Package not found for share", e);
                }
                return uris;
            }

            @Override
            protected void onPostExecute(java.util.List<android.net.Uri> uris) {
                if (uris.isEmpty()) {
                    android.widget.Toast.makeText(context, R.string.error_share_apk, android.widget.Toast.LENGTH_SHORT).show();
                    return;
                }
                android.content.Intent shareIntent = new android.content.Intent(android.content.Intent.ACTION_SEND_MULTIPLE);
                shareIntent.setType("application/vnd.android.package-archive");
                shareIntent.putParcelableArrayListExtra(android.content.Intent.EXTRA_STREAM, new java.util.ArrayList<>(uris));
                shareIntent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION);
                context.startActivity(android.content.Intent.createChooser(shareIntent, context.getString(R.string.menu_share_apk)));
            }
        }.execute();
    }

    /** Install this app to another user via root (pm install-existing --user <id> <pkg>) */
    private void installToOtherUser(Context context) {
        RootHandler rootHandler = KissApplication.getApplication(context).getRootHandler();
        java.util.List<String> users = rootHandler.getInstalledUsers();
        if (users.isEmpty()) {
            android.widget.Toast.makeText(context, R.string.error_no_other_users, android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
        builder.setTitle(R.string.menu_install_other_user);
        String[] userArr = users.toArray(new String[0]);
        builder.setItems(userArr, (dialog, which) -> {
            String userEntry = userArr[which];
            String userId = userEntry.replaceAll("[^0-9]", "");
            boolean ok = rootHandler.installExistingToUser(pojo.packageName, userId);
            int msg = ok ? R.string.install_user_success : R.string.install_user_error;
            android.widget.Toast.makeText(context, context.getString(msg, userEntry), android.widget.Toast.LENGTH_SHORT).show();
        });
        builder.setNegativeButton(android.R.string.cancel, null);
        builder.show();
    }

    /** Open /data/data/<pkg> in a supported root file manager */
    private void openDataDir(Context context) {
        KissApplication.getApplication(context).getRootHandler()
                .openInRootExplorer(context, "/data/data/" + pojo.packageName);
    }

    /** Open /data/app/<pkg> in a supported root file manager */
    private void openAppDir(Context context) {
        KissApplication.getApplication(context).getRootHandler()
                .openInRootExplorer(context, "/data/app/" + pojo.packageName);
    }
"""

# Insert helper methods just before last closing brace
last_brace_idx = src.rfind("}")
src = src[:last_brace_idx] + helper_methods + "\n}"

with open("app/src/main/java/fr/neamar/kiss/result/AppResult.java", "w") as f:
    f.write(src)

print("AppResult.java patched OK")
PYEOF

# ---------------------------------------------------------------------------
# 5. Patch RootHandler.java — add new root operations
# ---------------------------------------------------------------------------
echo "[5/6] Patching RootHandler.java (new root operations)..."

python3 - <<'PYEOF'
with open("app/src/main/java/fr/neamar/kiss/RootHandler.java", "r") as f:
    src = f.read()

new_imports = """import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
"""

# Add imports after existing package line
src = src.replace(
    "import android.content.Context;\nimport android.content.SharedPreferences;",
    "import android.content.Context;\nimport android.content.Intent;\nimport android.content.SharedPreferences;"
)

new_methods = """
    // -----------------------------------------------------------------------
    // New methods added by kiss-modifications patch
    // -----------------------------------------------------------------------

    /** Sleep / turn off the screen using root */
    public void sleepScreen(Context context) {
        try {
            executeRootShell("input keyevent 26");
        } catch (Exception e) {
            Log.w(TAG, "sleepScreen failed", e);
        }
    }

    /**
     * List installed user IDs (non-owner).
     * Returns list of strings like "User 10 (id:10)".
     */
    public List<String> getInstalledUsers() {
        List<String> users = new ArrayList<>();
        try {
            String output = executeRootShellAndGetOutput("pm list users");
            if (output == null) return users;
            for (String line : output.split("\\n")) {
                line = line.trim();
                // Format: UserInfo{10:user 10:...}
                if (line.startsWith("UserInfo{")) {
                    String inner = line.substring(9, line.indexOf('}'));
                    String[] parts = inner.split(":");
                    if (parts.length >= 2) {
                        String uid = parts[0];
                        String uname = parts[1];
                        users.add(uname.trim() + " (id:" + uid.trim() + ")");
                    }
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "getInstalledUsers failed", e);
        }
        return users;
    }

    /** Run: pm install-existing --user <userId> <packageName> */
    public boolean installExistingToUser(String packageName, String userId) {
        try {
            return executeRootShell("pm install-existing --user " + userId + " " + packageName);
        } catch (Exception e) {
            Log.w(TAG, "installExistingToUser failed", e);
            return false;
        }
    }

    /**
     * Open the given path in a supported root file manager app.
     * Tries MiXplorer, MiXplorer Silver, MT Manager (canary), MT Manager in order.
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
                Intent intent = new Intent(Intent.ACTION_VIEW);
                intent.setPackage(pkg);
                intent.setDataAndType(android.net.Uri.parse("file://" + path), "resource/folder");
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                context.startActivity(intent);
                return;
            } catch (android.content.pm.PackageManager.NameNotFoundException e) {
                // Not installed, try next
            } catch (android.content.ActivityNotFoundException e) {
                // Can't open, try next
            }
        }

        // Fallback: open with root shell using am
        try {
            executeRootShell("am start -a android.intent.action.VIEW -d \\"file://" + path + "\\" -t resource/folder");
        } catch (Exception e) {
            Log.w(TAG, "openInRootExplorer fallback failed", e);
        }
    }

    /** Execute a root shell command and return its stdout output */
    private String executeRootShellAndGetOutput(String command) {
        Process p = null;
        try {
            p = Runtime.getRuntime().exec("su");
            p.getOutputStream().write((command + "\\n").getBytes(java.nio.charset.StandardCharsets.UTF_8));
            p.getOutputStream().write("exit\\n".getBytes(java.nio.charset.StandardCharsets.UTF_8));
            p.getOutputStream().flush();
            p.getOutputStream().close();

            BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append("\\n");
            }
            p.waitFor();
            return sb.toString();
        } catch (Exception e) {
            Log.w(TAG, "executeRootShellAndGetOutput failed", e);
            return null;
        } finally {
            if (p != null) p.destroy();
        }
    }
"""

# Add imports for BufferedReader etc. after existing import block
src = src.replace(
    "import java.nio.charset.StandardCharsets;",
    """import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.nio.charset.StandardCharsets;"""
)

# Insert new methods before the last closing brace
last_brace = src.rfind("}")
src = src[:last_brace] + new_methods + "\n}"

with open("app/src/main/java/fr/neamar/kiss/RootHandler.java", "w") as f:
    f.write(src)

print("RootHandler.java patched OK")
PYEOF

# ---------------------------------------------------------------------------
# 6. Patch AndroidManifest.xml — add new permissions + AppDrawerActivity
# ---------------------------------------------------------------------------
echo "[6/6] Patching AndroidManifest.xml..."

python3 - <<'PYEOF'
with open("app/src/main/AndroidManifest.xml", "r") as f:
    src = f.read()

new_perms = """
    <!-- For usage stats access (Advanced Permissions feature) -->
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions" />
    <!-- To manage files (Advanced Permissions feature - All Files Access) -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
        tools:ignore="ScopedStorage" />
    <!-- For sharing APK files -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
"""

src = src.replace(
    '    <!-- To set timers -->',
    new_perms + '    <!-- To set timers -->'
)

new_activity = """
        <activity
            android:name=".AppDrawerActivity"
            android:label="@string/app_drawer_title"
            android:excludeFromRecents="true"
            android:exported="false"
            android:theme="@style/AppTheme"
            android:windowSoftInputMode="stateAlwaysHidden|adjustResize" />

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_provider_paths" />
        </provider>
"""

src = src.replace(
    '        <activity\n            android:name=".DummyActivity"',
    new_activity + '        <activity\n            android:name=".DummyActivity"'
)

with open("app/src/main/AndroidManifest.xml", "w") as f:
    f.write(src)

print("AndroidManifest.xml patched OK")
PYEOF


# ---------------------------------------------------------------------------
# 7. Merge arrays into res/values/arrays.xml
# ---------------------------------------------------------------------------
echo "[7/8] Merging new arrays into res/values/arrays.xml..."

sed -i 's|</resources>||' "$RES_SRC/values/arrays.xml"
# Append new array entries (stripping the xml header + <resources> wrapper)
python3 - <<'PYEOF'
with open("app/src/main/res/values/arrays.xml", "r") as f:
    content = f.read()
with open("../kiss-patches/patches/src/main/res/values/arrays_additions.xml", "r") as f:
    additions = f.read()
import re
# Extract just the array elements (strip xml declaration and root element)
inner = re.search(r'<resources>(.*?)</resources>', additions, re.DOTALL)
if inner:
    content = content.rstrip() + "\n" + inner.group(1).strip() + "\n</resources>\n"
with open("app/src/main/res/values/arrays.xml", "w") as f:
    f.write(content)
print("arrays.xml merged OK")
PYEOF

# ---------------------------------------------------------------------------
# 8. Copy FileProvider paths XML
# ---------------------------------------------------------------------------
echo "[8/8] Copying file_provider_paths.xml..."
cp "$PATCHES_DIR/src/main/res/xml/file_provider_paths.xml" "$RES_SRC/xml/"

echo ""
echo "=== All modifications applied successfully ==="
echo ""
echo "Summary of changes:"
echo "  + AppDrawerActivity.java    (new: Personal/Work tabbed app drawer)"
echo "  + AppDrawerFragment.java    (new: tab fragment with sort + create-folder)"
echo "  + AppDrawerGridAdapter.java (new: grid adapter with folder cards)"
echo "  + SelectionManager.java     (new: multi-select singleton)"
echo "  ~ AppResult.java            (modified: 8 new long-press menu items)"
echo "  ~ RootHandler.java          (modified: 5 new root operations)"
echo "  ~ AndroidManifest.xml       (modified: permissions + AppDrawerActivity)"
echo "  ~ strings.xml               (modified: +30 new string resources)"
echo "  ~ arrays.xml                (modified: scroll direction entries)"
echo "  + 5 new layout XML files"
echo "  + file_provider_paths.xml"
