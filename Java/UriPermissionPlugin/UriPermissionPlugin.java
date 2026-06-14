package org.godotengine.plugin.uripermission;

import android.content.ContentResolver;
import android.net.Uri;
import android.app.Activity;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class UriPermissionPlugin extends GodotPlugin {

    public UriPermissionPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "UriPermissionPlugin";
    }

    @UsedByGodot
    public void takePersistablePermission(String uriString) {
        try {
            Uri uri = Uri.parse(uriString);
            if (uri.getScheme() != null && uri.getScheme().equals("content")) {
                int flags = 3;
                Activity activity = getActivity();
                if (activity != null) {
                    ContentResolver cr = activity.getContentResolver();
                    cr.takePersistableUriPermission(uri, flags);
                }
            }
        } catch (Exception ignored) {
        }
    }

    @UsedByGodot
    public byte[] readUri(String path) {
        try {
            if (getActivity() == null) {
                return new byte[0];
            }

            Uri uri = Uri.parse(path);

            if (uri.getScheme() != null && uri.getScheme().equals("content")) {
                ContentResolver cr = getActivity().getContentResolver();
                InputStream is = cr.openInputStream(uri);
                if (is == null) {
                    return new byte[0];
                }
                ByteArrayOutputStream baos = new ByteArrayOutputStream();
                byte[] buffer = new byte[16384];
                int read;
                while ((read = is.read(buffer, 0, buffer.length)) != -1) {
                    baos.write(buffer, 0, read);
                }
                is.close();
                return baos.toByteArray();
            } else {
                File file = new File(path);
                if (!file.exists() || !file.isFile()) {
                    return new byte[0];
                }
                FileInputStream fis = new FileInputStream(file);
                ByteArrayOutputStream baos = new ByteArrayOutputStream();
                byte[] buffer = new byte[16384];
                int read;
                while ((read = fis.read(buffer, 0, buffer.length)) != -1) {
                    baos.write(buffer, 0, read);
                }
                fis.close();
                return baos.toByteArray();
            }
        } catch (Exception e) {
            return new byte[0];
        }
    }

    @UsedByGodot
    public void writeUri(String path, byte[] data) {
        try {
            if (getActivity() == null) {
                return;
            }

            Uri uri = Uri.parse(path);

            if (uri.getScheme() != null && uri.getScheme().equals("content")) {
                ContentResolver cr = getActivity().getContentResolver();
                OutputStream os = cr.openOutputStream(uri, "w");
                if (os == null) {
                    return;
                }
                os.write(data);
                os.close();
            } else {
                File file = new File(path);
                FileOutputStream fos = new FileOutputStream(file);
                fos.write(data);
                fos.close();
            }
        } catch (Exception ignored) {
        }
    }
}
