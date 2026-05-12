package fr.neamar.kiss;

import android.app.ActivityOptions;
import android.content.Context;
import android.content.pm.LauncherActivityInfo;
import android.content.pm.LauncherApps;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.List;

/**
 * RecyclerView adapter for the App Drawer.
 * Supports three view types:
 *   - TYPE_APP      : single app icon + label
 *   - TYPE_WF_FOLDER : folder card for one secondary user (Work tab)
 *   - TYPE_UF_FOLDER : user-created folder (Personal tab)
 */
public class AppDrawerGridAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private static final int TYPE_APP = 0;
    private static final int TYPE_WF_FOLDER = 1;
    private static final int TYPE_UF_FOLDER = 2;

    private final Context context;
    private final List<Object> items;
    private final boolean isPersonal;

    public AppDrawerGridAdapter(Context context, List<Object> items, boolean isPersonal) {
        this.context = context;
        this.items = items;
        this.isPersonal = isPersonal;
    }

    @Override
    public int getItemViewType(int position) {
        Object item = items.get(position);
        if (item instanceof AppDrawerFragment.WorkFolderItem) return TYPE_WF_FOLDER;
        if (item instanceof AppDrawerFragment.UserFolderItem) return TYPE_UF_FOLDER;
        return TYPE_APP;
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(context);
        if (viewType == TYPE_WF_FOLDER || viewType == TYPE_UF_FOLDER) {
            View v = inflater.inflate(R.layout.item_app_drawer_folder, parent, false);
            return new FolderViewHolder(v);
        }
        View v = inflater.inflate(R.layout.item_app_drawer_icon, parent, false);
        return new AppViewHolder(v);
    }

    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        Object item = items.get(position);

        if (holder instanceof AppViewHolder && item instanceof LauncherActivityInfo) {
            bindApp((AppViewHolder) holder, (LauncherActivityInfo) item);
        } else if (holder instanceof FolderViewHolder
                && item instanceof AppDrawerFragment.WorkFolderItem) {
            bindWorkFolder((FolderViewHolder) holder, (AppDrawerFragment.WorkFolderItem) item);
        } else if (holder instanceof FolderViewHolder
                && item instanceof AppDrawerFragment.UserFolderItem) {
            bindUserFolder((FolderViewHolder) holder, (AppDrawerFragment.UserFolderItem) item);
        }
    }

    private void bindApp(AppViewHolder holder, LauncherActivityInfo info) {
        holder.label.setText(info.getLabel());
        holder.label.setContentDescription(info.getLabel());

        // Load icon asynchronously to avoid blocking UI thread
        holder.icon.setImageDrawable(null);
        new Thread(() -> {
            try {
                Drawable d = info.getIcon(context.getResources().getDisplayMetrics().densityDpi);
                holder.icon.post(() -> holder.icon.setImageDrawable(d));
            } catch (Exception ignored) {
            }
        }).start();

        holder.itemView.setOnClickListener(v -> {
            LauncherApps launcher = ContextCompat.getSystemService(context, LauncherApps.class);
            if (launcher == null) return;
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    ActivityOptions opts = ActivityOptions.makeClipRevealAnimation(
                            v, 0, 0, v.getMeasuredWidth(), v.getMeasuredHeight());
                    launcher.startMainActivity(
                            info.getComponentName(), info.getUser(), null, opts.toBundle());
                } else {
                    launcher.startMainActivity(info.getComponentName(), info.getUser(), null, null);
                }
            } catch (Exception ignored) {
            }
        });
    }

    private void bindWorkFolder(FolderViewHolder holder, AppDrawerFragment.WorkFolderItem folder) {
        holder.folderName.setText(folder.name);
        holder.appCount.setText(context.getResources()
                .getQuantityString(R.plurals.folder_app_count, folder.apps.size(), folder.apps.size()));

        // Show up to 4 preview icons
        List<ImageView> previews = new ArrayList<>();
        previews.add(holder.preview1);
        previews.add(holder.preview2);
        previews.add(holder.preview3);
        previews.add(holder.preview4);

        for (int i = 0; i < previews.size(); i++) {
            if (i < folder.apps.size()) {
                final LauncherActivityInfo info = folder.apps.get(i);
                previews.get(i).setVisibility(View.VISIBLE);
                previews.get(i).setImageDrawable(null);
                new Thread(() -> {
                    try {
                        Drawable d = info.getIcon(
                                context.getResources().getDisplayMetrics().densityDpi);
                        previews.get(0).post(() -> {
                            // Safe index capture already done via final vars
                        });
                        final int idx = folder.apps.indexOf(info);
                        if (idx >= 0 && idx < previews.size()) {
                            previews.get(idx).post(() -> previews.get(idx).setImageDrawable(d));
                        }
                    } catch (Exception ignored) {
                    }
                }).start();
            } else {
                previews.get(i).setVisibility(View.GONE);
            }
        }
    }

    private void bindUserFolder(FolderViewHolder holder, AppDrawerFragment.UserFolderItem folder) {
        holder.folderName.setText(folder.name);
        holder.appCount.setText(context.getResources()
                .getQuantityString(R.plurals.folder_app_count, folder.apps.size(), folder.apps.size()));
        holder.preview1.setVisibility(View.GONE);
        holder.preview2.setVisibility(View.GONE);
        holder.preview3.setVisibility(View.GONE);
        holder.preview4.setVisibility(View.GONE);
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    // -----------------------------------------------------------------------
    // ViewHolders
    // -----------------------------------------------------------------------

    static class AppViewHolder extends RecyclerView.ViewHolder {
        ImageView icon;
        TextView label;

        AppViewHolder(@NonNull View itemView) {
            super(itemView);
            icon = itemView.findViewById(R.id.app_icon);
            label = itemView.findViewById(R.id.app_label);
        }
    }

    static class FolderViewHolder extends RecyclerView.ViewHolder {
        TextView folderName;
        TextView appCount;
        ImageView preview1, preview2, preview3, preview4;

        FolderViewHolder(@NonNull View itemView) {
            super(itemView);
            folderName = itemView.findViewById(R.id.folder_name);
            appCount = itemView.findViewById(R.id.folder_app_count);
            preview1 = itemView.findViewById(R.id.folder_preview_1);
            preview2 = itemView.findViewById(R.id.folder_preview_2);
            preview3 = itemView.findViewById(R.id.folder_preview_3);
            preview4 = itemView.findViewById(R.id.folder_preview_4);
        }
    }
}
