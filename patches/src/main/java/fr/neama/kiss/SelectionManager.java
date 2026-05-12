package fr.neamar.kiss;

import java.util.ArrayList;
import java.util.List;

import fr.neamar.kiss.adapter.RecordAdapter;
import fr.neamar.kiss.pojo.AppPojo;

/**
 * Singleton that tracks selected apps for batch operations:
 * merge into folder, multi-uninstall, or multi-share — per user.
 */
public class SelectionManager {

    private static SelectionManager instance;

    private final List<AppPojo> selectedApps = new ArrayList<>();
    private SelectionListener listener;

    private SelectionManager() {
    }

    public static SelectionManager getInstance() {
        if (instance == null) {
            instance = new SelectionManager();
        }
        return instance;
    }

    // -----------------------------------------------------------------------
    // Selection state
    // -----------------------------------------------------------------------

    public void toggleSelect(AppPojo pojo, RecordAdapter parent) {
        if (selectedApps.contains(pojo)) {
            selectedApps.remove(pojo);
        } else {
            selectedApps.add(pojo);
        }
        if (listener != null) listener.onSelectionChanged(selectedApps);
    }

    public boolean isSelected(AppPojo pojo) {
        return selectedApps.contains(pojo);
    }

    public List<AppPojo> getSelectedApps() {
        return new ArrayList<>(selectedApps);
    }

    public int getSelectionCount() {
        return selectedApps.size();
    }

    public void clearSelection() {
        selectedApps.clear();
        if (listener != null) listener.onSelectionChanged(selectedApps);
    }

    // -----------------------------------------------------------------------
    // Listener
    // -----------------------------------------------------------------------

    public void setListener(SelectionListener listener) {
        this.listener = listener;
    }

    public interface SelectionListener {
        void onSelectionChanged(List<AppPojo> selected);
    }
}
