package fr.neamar.kiss;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.LauncherActivityInfo;
import android.content.pm.LauncherApps;
import android.os.Bundle;
import android.text.InputType;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.Fragment;
import androidx.preference.PreferenceManager;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * One tab in the App Drawer (either Personal or Work).
 *
 * Personal: shows all primary-user apps as a grid/horizontal list.
 * Work: shows secondary users' apps grouped into folder cards named "User <id>".
 */
public class AppDrawerFragment extends Fragment {

    public static final int SORT_NAME = 0;
    public static final int SORT_INSTALL_TIME = 1;

    private static final String ARG_IS_PERSONAL = "is_personal";

    private boolean isPersonal;
    private AppDrawerGridAdapter adapter;
    private final List<Object> items = new ArrayList<>();

    public static AppDrawerFragment newInstance(boolean isPersonal) {
        AppDrawerFragment fragment = new AppDrawerFragment();
        Bundle args = new Bundle();
        args.putBoolean(ARG_IS_PERSONAL, isPersonal);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (getArguments() != null) {
            isPersonal = getArguments().getBoolean(ARG_IS_PERSONAL, true);
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View root = inflater.inflate(R.layout.fragment_app_drawer, container, false);
        RecyclerView recyclerView = root.findViewById(R.id.app_drawer_recycler);

        SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(requireContext());
        String scrollPref = prefs.getString("app_drawer_scroll", "vertical");

        if ("horizontal".equals(scrollPref)) {
            recyclerView.setLayoutManager(
                    new LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false));
        } else {
            recyclerView.setLayoutManager(new GridLayoutManager(requireContext(), 4));
        }

        adapter = new AppDrawerGridAdapter(requireContext(), items, isPersonal);
        recyclerView.setAdapter(adapter);

        loadApps();
        return root;
    }

    // -----------------------------------------------------------------------
    // App loading
    // -----------------------------------------------------------------------

    private void loadApps() {
        items.clear();
        Context ctx = requireContext();

        android.os.UserManager manager =
                ContextCompat.getSystemService(ctx, android.os.UserManager.class);
        LauncherApps launcherApps =
                ContextCompat.getSystemService(ctx, LauncherApps.class);

        if (manager == null || launcherApps == null) return;

        if (isPersonal) {
            android.os.UserHandle ownerProfile = android.os.Process.myUserHandle();
            List<LauncherActivityInfo> ownerApps =
                    launcherApps.getActivityList(null, ownerProfile);
            items.addAll(ownerApps);
        } else {
            // Work tab: group each secondary user's apps into a WorkFolderItem
            for (android.os.UserHandle profile : manager.getUserProfiles()) {
                if (profile.equals(android.os.Process.myUserHandle())) continue;

                long serial = manager.getSerialNumberForUser(profile);
                String userName = "User " + serial;

                List<LauncherActivityInfo> userApps =
                        launcherApps.getActivityList(null, profile);
                if (!userApps.isEmpty()) {
                    items.add(new WorkFolderItem(userName, userApps, profile));
                }
            }
        }

        if (adapter != null) adapter.notifyDataSetChanged();
    }

    // -----------------------------------------------------------------------
    // Sorting
    // -----------------------------------------------------------------------

    public void sortApps(int sortType) {
        if (sortType == SORT_NAME) {
            Collections.sort(items, (a, b) -> {
                String nameA = getItemLabel(a);
                String nameB = getItemLabel(b);
                return nameA.compareToIgnoreCase(nameB);
            });
        } else {
            Collections.sort(items, (a, b) -> {
                long timeA = getItemInstallTime(a);
                long timeB = getItemInstallTime(b);
                return Long.compare(timeB, timeA);
            });
        }
        if (adapter != null) adapter.notifyDataSetChanged();
    }

    private String getItemLabel(Object item) {
        if (item instanceof LauncherActivityInfo) {
            return ((LauncherActivityInfo) item).getLabel().toString();
        } else if (item instanceof WorkFolderItem) {
            return ((WorkFolderItem) item).name;
        }
        return "";
    }

    private long getItemInstallTime(Object item) {
        if (item instanceof LauncherActivityInfo) {
            return ((LauncherActivityInfo) item).getFirstInstallTime();
        }
        return 0L;
    }

    // -----------------------------------------------------------------------
    // Folder creation
    // -----------------------------------------------------------------------

    public void showCreateFolderDialog() {
        if (getContext() == null) return;
        AlertDialog.Builder builder = new AlertDialog.Builder(requireContext());
        builder.setTitle(R.string.create_folder_title);

        final EditText nameInput = new EditText(requireContext());
        nameInput.setInputType(InputType.TYPE_CLASS_TEXT);
        nameInput.setHint(R.string.create_folder_hint);
        builder.setView(nameInput);

        builder.setPositiveButton(R.string.create_folder_ok, (dialog, which) -> {
            String folderName = nameInput.getText().toString().trim();
            if (!folderName.isEmpty()) {
                createFolder(folderName);
            }
        });
        builder.setNegativeButton(android.R.string.cancel, null);
        builder.show();
    }

    private void createFolder(String name) {
        // Insert a FolderItem placeholder at the top of the current list
        items.add(0, new UserFolderItem(name, new ArrayList<>()));
        if (adapter != null) adapter.notifyItemInserted(0);
    }

    // -----------------------------------------------------------------------
    // Data models
    // -----------------------------------------------------------------------

    /** Represents a folder card for one secondary user in the Work tab. */
    public static class WorkFolderItem {
        public final String name;
        public final List<LauncherActivityInfo> apps;
        public final android.os.UserHandle userHandle;

        public WorkFolderItem(String name,
                              List<LauncherActivityInfo> apps,
                              android.os.UserHandle userHandle) {
            this.name = name;
            this.apps = apps;
            this.userHandle = userHandle;
        }
    }

    /** Represents a user-created folder in the Personal tab. */
    public static class UserFolderItem {
        public String name;
        public final List<LauncherActivityInfo> apps;

        public UserFolderItem(String name, List<LauncherActivityInfo> apps) {
            this.name = name;
            this.apps = apps;
        }
    }
}
