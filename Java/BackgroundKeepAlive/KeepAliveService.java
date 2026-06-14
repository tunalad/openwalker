package org.godotengine.plugin.backgroundkeepalive;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.IBinder;
import android.os.PowerManager;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;

public class KeepAliveService extends Service implements SensorEventListener {
    private static final String CHANNEL_ID = "keepalive_default";
    private static final String CHANNEL_NAME = "Background";
    private static final int NOTIF_ID = 1;
    private static final String STEP_FILE = "step_count";
    private static final long FILE_WRITE_INTERVAL = 3000;

    public static volatile boolean running;
    public static volatile int stepCount;
    public static volatile boolean resetRequested;

    private SensorManager sensorManager;
    private Sensor stepSensor;
    private PowerManager.WakeLock wakeLock;
    private long baselineSteps;
    private boolean hasBaseline;
    private long persistedSteps;
    private long lastFileWrite;

    @Override
    public void onCreate() {
        super.onCreate();
        running = true;
        persistedSteps = readStepCount();
        applyResetIfRequested();

        sensorManager = getSystemService(SensorManager.class);
        if (sensorManager != null) {
            stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
            if (stepSensor != null) {
                sensorManager.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_NORMAL);
            }
        }

        PowerManager pm = getSystemService(PowerManager.class);
        if (pm != null) {
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "KeepAlive:StepLock");
            wakeLock.acquire(10 * 60 * 1000L);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        applyResetIfRequested();

        NotificationManager nm = getSystemService(NotificationManager.class);
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            NotificationChannel c = new NotificationChannel(
                    CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_MIN
            );
            c.enableVibration(false);
            nm.createNotificationChannel(c);
        }

        int iconId = getApplicationInfo().icon;
        if (iconId == 0) iconId = android.R.drawable.ic_dialog_info;

        String title = intent != null ? intent.getStringExtra("title") : null;
        String desc = intent != null ? intent.getStringExtra("description") : null;

        if (title == null || title.isEmpty()) {
            title = getApplicationInfo().loadLabel(getPackageManager()).toString();
        }
        if (desc == null) desc = "";

        Notification.Builder nb = new Notification.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setSmallIcon(iconId)
                .setOngoing(true);
        if (!desc.isEmpty()) nb.setContentText(desc);
        Notification notif = nb.build();

        startForeground(NOTIF_ID, notif);
        return START_STICKY;
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() != Sensor.TYPE_STEP_COUNTER) return;
        long v = (long) event.values[0];
        if (!hasBaseline) {
            baselineSteps = v;
            hasBaseline = true;
        }
        long sessionSteps = v - baselineSteps;
        int total = (int) (persistedSteps + sessionSteps);
        stepCount = total;

        long now = System.currentTimeMillis();
        if (now - lastFileWrite > FILE_WRITE_INTERVAL) {
            lastFileWrite = now;
            writeStepCount(total);
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    public static void reset() {
        stepCount = 0;
        resetRequested = true;
    }

    private void applyResetIfRequested() {
        if (resetRequested) {
            resetRequested = false;
            persistedSteps = 0;
            hasBaseline = false;
            writeStepCount(0);
        }
    }

    @Override
    public void onDestroy() {
        running = false;
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
        writeStepCount(stepCount);
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private int readStepCount() {
        try {
            File f = new File(getFilesDir(), STEP_FILE);
            if (!f.exists()) return 0;
            BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f)));
            String line = r.readLine();
            r.close();
            return line != null ? Integer.parseInt(line.trim()) : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private void writeStepCount(int val) {
        try {
            FileOutputStream fos = new FileOutputStream(new File(getFilesDir(), STEP_FILE));
            fos.write(String.valueOf(val).getBytes());
            fos.close();
        } catch (Exception ignored) {
        }
    }
}
