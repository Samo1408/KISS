package fr.neamar.kiss;

import android.os.Bundle;
import android.view.View;
import android.widget.ImageButton;
import android.widget.PopupMenu;

import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.viewpager2.adapter.FragmentStateAdapter;
import androidx.viewpager2.widget.ViewPager2;

import com.google.android.material.tabs.TabLayout;
import com.google.android.material.tabs.TabLayoutMediator;

/**
 * Full-screen App Drawer with two tabs: Personal and Work.
 * Personal tab: all primary-user apps (grid or horizontal scroll based on settings).
 * Work tab: secondary/work profile apps grouped into folders per user.
 */
public class AppDrawerActivity extends AppCompatActivity {

    public static final int TAB_PERSONAL = 0;
    public static final int TAB_WORK = 1;

    private ViewPager2 viewPager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_app_drawer);

        viewPager = findViewById(R.id.app_drawer_viewpager);
        TabLayout tabLayout = findViewById(R.id.app_drawer_tabs);
        ImageButton sortButton = findViewById(R.id.btn_sort);
        ImageButton addFolderButton = findViewById(R.id.btn_add_folder);
        ImageButton closeButton = findViewById(R.id.btn_close);

        AppDrawerPagerAdapter adapter = new AppDrawerPagerAdapter(this);
        viewPager.setAdapter(adapter);

        new TabLayoutMediator(tabLayout, viewPager, (tab, position) -> {
            if (position == TAB_PERSONAL) {
                tab.setText(R.string.tab_personal);
            } else {
                tab.setText(R.string.tab_work);
            }
        }).attach();

        sortButton.setOnClickListener(this::showSortMenu);

        addFolderButton.setOnClickListener(v -> showCreateFolderDialog());

        closeButton.setOnClickListener(v -> finish());
    }

    private void showSortMenu(View anchor) {
        PopupMenu popup = new PopupMenu(this, anchor);
        popup.getMenu().add(0, AppDrawerFragment.SORT_NAME, 0, R.string.sort_by_name);
        popup.getMenu().add(0, AppDrawerFragment.SORT_INSTALL_TIME, 0, R.string.sort_by_install_time);
        popup.setOnMenuItemClickListener(item -> {
            int currentTab = viewPager.getCurrentItem();
            Fragment f = getSupportFragmentManager().findFragmentByTag("f" + currentTab);
            if (f instanceof AppDrawerFragment) {
                ((AppDrawerFragment) f).sortApps(item.getItemId());
            }
            return true;
        });
        popup.show();
    }

    private void showCreateFolderDialog() {
        int currentTab = viewPager.getCurrentItem();
        Fragment f = getSupportFragmentManager().findFragmentByTag("f" + currentTab);
        if (f instanceof AppDrawerFragment) {
            ((AppDrawerFragment) f).showCreateFolderDialog();
        }
    }

    // -----------------------------------------------------------------------
    // ViewPager2 adapter
    // -----------------------------------------------------------------------

    static class AppDrawerPagerAdapter extends FragmentStateAdapter {

        AppDrawerPagerAdapter(FragmentActivity fa) {
            super(fa);
        }

        @Override
        public Fragment createFragment(int position) {
            return AppDrawerFragment.newInstance(position == TAB_PERSONAL);
        }

        @Override
        public int getItemCount() {
            return 2;
        }
    }
}
