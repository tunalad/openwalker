package org.godotengine.plugin.backgroundkeepalive;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Arrays;
import java.util.List;

public class BackgroundKeepAlive extends GodotPlugin {
    private static final String TAG = "BackgroundKeepAlive";

    public BackgroundKeepAlive(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "BackgroundKeepAlive";
    }

    @Override
    public List<String> getPluginMethods() {
        return Arrays.asList("start", "stop", "isRunning", "getSteps",
                "isPermissionGranted", "requestPermission");
    }

    @UsedByGodot
    public void start(String title, String description) {
        Log.d(TAG, "start title=" + title + " desc=" + description);
        KeepAliveService.reset();
        Intent intent = new Intent(getActivity(), KeepAliveService.class);
        intent.putExtra("title", title);
        intent.putExtra("description", description);
        getActivity().startForegroundService(intent);
    }

    @UsedByGodot
    public void stop() {
        Log.d(TAG, "stop");
        Intent intent = new Intent(getActivity(), KeepAliveService.class);
        getActivity().stopService(intent);
    }

    @UsedByGodot
    public boolean isRunning() {
        return KeepAliveService.running;
    }

    @UsedByGodot
    public int getSteps() {
        return KeepAliveService.stepCount;
    }

    @UsedByGodot
    public boolean isPermissionGranted() {
        Activity a = getActivity();
        if (a == null) return false;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true;
        return a.checkSelfPermission(android.Manifest.permission.ACTIVITY_RECOGNITION)
                == android.content.pm.PackageManager.PERMISSION_GRANTED;
    }

    @UsedByGodot
    public void requestPermission() {
        Activity a = getActivity();
        if (a == null) return;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return;
        a.requestPermissions(
                new String[]{android.Manifest.permission.ACTIVITY_RECOGNITION},
                9002
        );
    }
}
