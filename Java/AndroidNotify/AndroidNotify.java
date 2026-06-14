package org.godotengine.plugin.androidnotify;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.InputStream;
import java.util.Arrays;
import java.util.List;

public class AndroidNotify extends GodotPlugin {
    private static final String TAG = "AndroidNotify";
    private static final String CHANNEL_PREFIX = "android_notify_";
    private static final int ONGOING_ID = 0;

    private int notificationId;
    private long lastOngoingNotifyTime;
    private String customIconPath;

    public AndroidNotify(Godot godot) {
        super(godot);
        notificationId = 1;
    }

    @Override
    public String getPluginName() {
        return "AndroidNotify";
    }

    @Override
    public List<String> getPluginMethods() {
        return Arrays.asList("send", "sendOngoing", "stopOngoing",
                "setNotificationIcon",
                "isPermissionGranted", "requestPermission");
    }

    @UsedByGodot
    public boolean isPermissionGranted() {
        Activity a = getActivity();
        if (a == null) return false;
        return a.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                == android.content.pm.PackageManager.PERMISSION_GRANTED;
    }

    @UsedByGodot
    public void requestPermission() {
        Activity a = getActivity();
        if (a == null) return;
        a.requestPermissions(
                new String[]{android.Manifest.permission.POST_NOTIFICATIONS},
                9001
        );
    }

    @UsedByGodot
    public void send(String title, String description, String imagePath, String urgency) {
        Log.d(TAG, "send: title=" + title + " desc=" + description
                + " image=" + imagePath + " urgency=" + urgency);
        notifyInternal(title, description, imagePath, urgency, false);
    }

    @UsedByGodot
    public void sendOngoing(String title, String description, String imagePath, String urgency) {
        Log.d(TAG, "sendOngoing: title=" + title + " desc=" + description
                + " image=" + imagePath + " urgency=" + urgency);
        notifyInternal(title, description, imagePath, urgency, true);
    }

    @UsedByGodot
    public void stopOngoing() {
        Log.d(TAG, "stopOngoing");
        Activity a = getActivity();
        if (a == null) return;
        NotificationManager nm = a.getSystemService(NotificationManager.class);
        if (nm != null) nm.cancel(ONGOING_ID);
    }

    @UsedByGodot
    public void setNotificationIcon(String path) {
        Log.d(TAG, "setNotificationIcon: " + path);
        customIconPath = path;
    }

    private void notifyInternal(String title, String description,
                                String imagePath, String urgency, boolean ongoing) {
        Activity a = getActivity();
        if (a == null) {
            Log.e(TAG, "activity is null");
            return;
        }

        if (title == null) title = "";
        if (description == null) description = "";
        if (imagePath == null) imagePath = "";
        if (urgency == null) urgency = "normal";

        NotificationManager nm = a.getSystemService(NotificationManager.class);
        if (nm == null) {
            Log.e(TAG, "notificationManager is null");
            return;
        }

        int importance = urgencyToImportance(urgency);
        String channelId = CHANNEL_PREFIX + urgency;

        if (nm.getNotificationChannel(channelId) == null) {
            String displayName = urgency.substring(0, 1).toUpperCase() + urgency.substring(1);
            NotificationChannel channel = new NotificationChannel(
                    channelId, displayName, importance
            );
            nm.createNotificationChannel(channel);
            Log.d(TAG, "created channel: " + channelId + " importance=" + importance);
        }

        Notification.Builder builder = new Notification.Builder(a, channelId)
                .setContentTitle(title)
                .setOngoing(ongoing);

        if (customIconPath != null && !customIconPath.isEmpty()) {
            Bitmap iconBitmap = decodeImage(customIconPath, a);
            if (iconBitmap != null) {
                builder.setSmallIcon(Icon.createWithBitmap(iconBitmap));
                Log.d(TAG, "using custom icon: " + customIconPath);
            } else {
                int iconId = a.getApplicationInfo().icon;
                if (iconId == 0) iconId = android.R.drawable.ic_dialog_info;
                builder.setSmallIcon(iconId);
            }
        } else {
            int iconId = a.getApplicationInfo().icon;
            if (iconId == 0) iconId = android.R.drawable.ic_dialog_info;
            builder.setSmallIcon(iconId);
        }

        if (!ongoing) {
            builder.setAutoCancel(true);
        }

        if (description != null && !description.isEmpty()) {
            builder.setContentText(description);
        }

        Bitmap bitmap = decodeImage(imagePath, a);
        if (bitmap != null) {
            Notification.BigPictureStyle bigStyle = new Notification.BigPictureStyle()
                    .bigPicture(bitmap)
                    .setBigContentTitle(title);
            if (description != null && !description.isEmpty()) {
                bigStyle.setSummaryText(description);
            }
            builder.setStyle(bigStyle);
        }

        int id = ongoing ? ONGOING_ID : notificationId++;
        if (ongoing) {
            long now = System.currentTimeMillis();
            if (now - lastOngoingNotifyTime < 1000) {
                Log.d(TAG, "throttled (only 1s between updates)");
                return;
            }
            lastOngoingNotifyTime = now;
        }
        nm.notify(id, builder.build());
        Log.d(TAG, "notify " + (ongoing ? "ongoing" : "once") + " id=" + id);
    }

    private Bitmap decodeImage(String path, Activity a) {
        if (path == null || path.isEmpty()) return null;
        try {
            if (path.startsWith("res://")) {
                String assetPath = path.substring(6);
                InputStream is = a.getAssets().open(assetPath);
                Bitmap bm = BitmapFactory.decodeStream(is);
                is.close();
                if (bm != null) Log.d(TAG, "loaded from assets: " + assetPath);
                else Log.w(TAG, "assets decode returned null: " + assetPath);
                return bm;
            }
            if (path.startsWith("user://")) {
                String fileName = path.substring(7);
                File f = new File(a.getFilesDir(), fileName);
                if (f.exists()) {
                    Bitmap bm = BitmapFactory.decodeFile(f.getAbsolutePath());
                    Log.d(TAG, "loaded from user://: " + f.getAbsolutePath());
                    return bm;
                }
                Log.w(TAG, "user:// file not found: " + f.getAbsolutePath());
                return null;
            }
            Bitmap bm = BitmapFactory.decodeFile(path);
            if (bm != null) Log.d(TAG, "loaded from absolute: " + path);
            else Log.w(TAG, "decodeFile returned null: " + path);
            return bm;
        } catch (Exception e) {
            Log.w(TAG, "image decode failed for " + path + ": " + e.getMessage());
            return null;
        }
    }

    private int urgencyToImportance(String urgency) {
        switch (urgency) {
            case "urgent":
            case "high":
                return NotificationManager.IMPORTANCE_HIGH;
            case "low":
                return NotificationManager.IMPORTANCE_LOW;
            case "min":
                return NotificationManager.IMPORTANCE_MIN;
            default:
                return NotificationManager.IMPORTANCE_DEFAULT;
        }
    }
}
