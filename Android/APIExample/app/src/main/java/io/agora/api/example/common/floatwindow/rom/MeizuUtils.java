/*
 * Copyright (C) 2016 Facishare Technology Co., Ltd. All Rights Reserved.
 */
package io.agora.api.example.common.floatwindow.rom;

import android.app.AppOpsManager;
import android.content.Context;
import android.content.Intent;
import android.os.Binder;
import android.util.Log;

import java.lang.reflect.Method;

/**
 * The type Meizu utils.
 */
public final class MeizuUtils {
    private static final String TAG = "MeizuUtils";

    private MeizuUtils() {

    }

    /**
     * 检测 meizu 悬浮窗权限
     *
     * @param context the context
     * @return the boolean
     */
    public static boolean checkFloatWindowPermission(Context context) {
        return checkOp(context, 24); //OP_SYSTEM_ALERT_WINDOW = 24;
    }

    /**
     * 去魅族权限申请页面
     *
     * @param context    the context
     * @param errHandler the err handler
     */
    public static void applyPermission(Context context, Runnable errHandler) {
        try {
            Intent intent = new Intent("com.meizu.safe.security.SHOW_APPSEC");
//            intent.setClassName("com.meizu.safe", "com.meizu.safe.security.AppSecActivity");//remove this line code for fix flyme6.3
            intent.putExtra("packageName", context.getPackageName());
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            try {
                Log.e(TAG, "获取悬浮窗权限, 打开AppSecActivity失败, " + Log.getStackTraceString(e));
                // 最新的魅族flyme 6.2.5 用上述方法获取权限失败, 不过又可以用下述方法获取权限了
                // FloatWindowManager.commonROMPermissionApplyInternal(context);
                if (errHandler != null) {
                    errHandler.run();
                }

            } catch (Exception eFinal) {
                Log.e(TAG, "获取悬浮窗权限失败, 通用获取方法失败, " + Log.getStackTraceString(eFinal));
            }
        }

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
}
