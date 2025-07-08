package io.agora.api.example;

import android.app.Application;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.annotation.Annotation;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import io.agora.api.example.annotation.Example;
import io.agora.api.example.common.model.Examples;
import io.agora.api.example.common.model.GlobalSettings;
import io.agora.api.example.utils.ClassUtils;

/**
 * The type Main application.
 */
public class MainApplication extends Application {

    private GlobalSettings globalSettings;

    private static final String TAG = "MainApplication";

    @Override
    public void onCreate() {
        super.onCreate();
        initExamples();
        try {
            extractResourceToCache("common_resource.zip");
        } catch (Exception e) {
            Log.e(TAG, "Failed to init files", e);
        }
    }

    private void initExamples() {
        try {
            Set<String> packageName = ClassUtils.getFileNameByPackageName(this, "io.agora.api.example.examples");
            for (String name : packageName) {
                Class<?> aClass = Class.forName(name);
                Annotation[] declaredAnnotations = aClass.getAnnotations();
                for (Annotation annotation : declaredAnnotations) {
                    if (annotation instanceof Example) {
                        Example example = (Example) annotation;
                        Examples.addItem(example);
                    }
                }
            }
            Examples.sortItem();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Gets global settings.
     *
     * @return the global settings
     */
    public GlobalSettings getGlobalSettings() {
        if (globalSettings == null) {
            globalSettings = new GlobalSettings();
        }
        return globalSettings;
    }


    private void extractResourceToCache(String zipFileName) throws IOException {
        String dirName = zipFileName.substring(0, zipFileName.lastIndexOf(".zip"));
        File resourceDir = new File(getCacheDir(), dirName);

        if (resourceDir.exists()) {
            Log.d(TAG, "Resources already exist at: " + resourceDir.getAbsolutePath());
            return;
        }

        File zipFile = new File(getCacheDir(), zipFileName);
        // Copy asset to cache
        try (InputStream input = getAssets().open(zipFileName);
             FileOutputStream output = new FileOutputStream(zipFile)) {
            byte[] buffer = new byte[4096];
            int len;
            while ((len = input.read(buffer)) > 0) {
                output.write(buffer, 0, len);
            }
        }

        // Unzip
        try (ZipInputStream zipIn = new ZipInputStream(new FileInputStream(zipFile))) {
            ZipEntry entry;
            byte[] buffer = new byte[4096];
            while ((entry = zipIn.getNextEntry()) != null) {
                File newFile = new File(getCacheDir(), entry.getName());

                if (entry.isDirectory()) {
                    newFile.mkdirs();
                    continue;
                }

                File parent = newFile.getParentFile();
                if (parent != null) {
                    parent.mkdirs();
                }

                try (FileOutputStream fos = new FileOutputStream(newFile)) {
                    int len;
                    while ((len = zipIn.read(buffer)) > 0) {
                        fos.write(buffer, 0, len);
                    }
                }
                long lastModified = entry.getTime();
                newFile.setLastModified(lastModified);
            }
        }
        zipFile.delete();
        Log.d(TAG, "Extracted resources to: " + resourceDir.getAbsolutePath());
    }
}
