/*
 * Copyright (C) 2016 Facishare Technology Co., Ltd. All Rights Reserved.
 */
package io.agora.api.example.common.floatwindow.rom;

import android.app.AppOpsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Binder;
import android.util.Log;

import java.lang.reflect.Method;

/**
 * The type Qiku utils.
 */
public final class QikuUtils {
    private static final String TAG = "QikuUtils";

    private QikuUtils() {

    }

    /**
     * 检测 360 悬浮窗权限
     *
     * @param context the context
     * @return the boolean
     */
    public static boolean checkFloatWindowPermission(Context context) {
        return checkOp(context, 24); //OP_SYSTEM_ALERT_WINDOW = 24;
    }

    private static boolean checkOp(Context context, int op) {
        AppOpsManager manager = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
        try {
            Class clazz = AppOpsManager.class;
            Method method = clazz.getDeclaredMethod("checkOp", int.class, int.class, String.class);
            return AppOpsManager.MODE_ALLOWED == (int) method.invoke(manager, op, Binder.getCallingUid(), context.getPackageName());
        } catch (Exception e) {
            Log.e(TAG, Log.getStackTraceString(e));
        }
        return false;
    }

    /**
     * 去360权限申请页面
     *
     * @param context the context
     */
    public static void applyPermission(Context context) {
        Intent intent = new Intent();
        intent.setClassName("com.android.settings", "com.android.settings.Settings$OverlaySettingsActivity");
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (isIntentAvailable(intent, context)) {
            context.startActivity(intent);
        } else {
            intent.setClassName("com.qihoo360.mobilesafe", "com.qihoo360.mobilesafe.ui.index.AppEnterActivity");
            if (isIntentAvailable(intent, context)) {
                context.startActivity(intent);
            } else {
                Log.e(TAG, "can't open permission page with particular name, please use "
                        + "\"adb shell dumpsys activity\" command and tell me the name of the float window permission page");
            }
        }
    }

    private static boolean isIntentAvailable(Intent intent, Context context) {
        if (intent == null) {
            return false;
        }
        return context.getPackageManager().queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).size() > 0;
    }
}
