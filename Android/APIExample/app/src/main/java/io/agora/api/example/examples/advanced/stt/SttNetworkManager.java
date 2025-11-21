package io.agora.api.example.examples.advanced.stt;

import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * Network manager for STT API requests using OkHttpClient
 */
public class SttNetworkManager {
    private static final String TAG = "SttNetworkManager";
//    private static final String BASE_URL = "https://staging-toolbox-convoai-cn.bj2.agoralab.co";
    private static final String BASE_URL = "https://dev-toolbox-convoai-cn.bj2.agoralab.co";
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");
    
    private final OkHttpClient client;

    /**
     * Constructor for SttNetworkManager
     * Initializes HTTP client with timeout configurations
     */
    public SttNetworkManager() {
        client = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build();
    }

    /**
     * Callback interface for handling network responses
     */
    public interface ResponseCallback {
        /**
         * Called when the request succeeds
         * @param response The response body as string
         */
        void onSuccess(String response);
        
        /**
         * Called when the request fails
         * @param error The error message
         */
        void onFailure(String error);
    }

    /**
     * Start STT transcript
     * @param appId Agora App ID
     * @param channelName Channel name
     * @param remoteUid Remote user ID (bot UID) - must be string format
     * @param languages Source languages array (e.g., ["en-US"])
     * @param enableTranslation Whether to enable translation
     * @param translationTargetLangs Translation target languages array (e.g., ["zh-CN", "ja-JP"])
     * @param callback Response callback
     */
    public void startTranscript(
            String appId,
            String channelName,
            String remoteUid,
            String[] languages,
            boolean enableTranslation,
            String[] translationTargetLangs,
            ResponseCallback callback) {
        
        try {
            String path = "/stt/v1/start";
            String urlString = BASE_URL + path;
            
            // Build request body
            JSONObject requestBody = new JSONObject();
            requestBody.put("app_id", appId);
            
            // Build stt_body
            JSONObject sttBody = new JSONObject();
            
            // Add languages
            JSONArray languagesArray = new JSONArray();
            for (String lang : languages) {
                languagesArray.put(lang);
            }
            sttBody.put("languages", languagesArray);
            sttBody.put("name", channelName);
            sttBody.put("maxIdleTime", 50);
            
            // Add rtcConfig
            JSONObject rtcConfig = new JSONObject();
            rtcConfig.put("channelName", channelName);
            rtcConfig.put("pubBotUid", remoteUid);
            sttBody.put("rtcConfig", rtcConfig);
            
            // Add translateConfig if enabled
            if (enableTranslation && translationTargetLangs != null && translationTargetLangs.length > 0) {
                JSONObject translateConfig = new JSONObject();
                JSONArray translateLanguages = new JSONArray();
                
                for (String sourceLang : languages) {
                    JSONObject langPair = new JSONObject();
                    langPair.put("source", sourceLang);
                    
                    // Add all target languages
                    JSONArray targetArray = new JSONArray();
                    for (String targetLang : translationTargetLangs) {
                        targetArray.put(targetLang);
                    }
                    langPair.put("target", targetArray);
                    
                    translateLanguages.put(langPair);
                }
                
                translateConfig.put("languages", translateLanguages);
                sttBody.put("translateConfig", translateConfig);
            }
            
            requestBody.put("stt_body", sttBody);
            
            // Make POST request
            postRequest(urlString, requestBody.toString(), callback);
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to start transcript", e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }

    /**
     * Stop STT transcript
     * @param appId Agora App ID
     * @param agentId Agent ID returned from start request
     * @param callback Response callback
     */
    public void stopTranscript(String appId, String agentId, ResponseCallback callback) {
        try {
            String path = "/stt/v1/stop";
            String urlString = BASE_URL + path;
            
            // Build request body
            JSONObject requestBody = new JSONObject();
            requestBody.put("app_id", appId);
            requestBody.put("agent_id", agentId);
            
            // Make POST request
            postRequest(urlString, requestBody.toString(), callback);
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to stop transcript", e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }

    /**
     * Generate curl command for debugging
     * @param urlString URL
     * @param jsonBody JSON body as string
     * @return curl command string
     */
    private String generateCurlCommand(String urlString, String jsonBody) {
        StringBuilder curl = new StringBuilder();
        curl.append("curl -X POST '").append(urlString).append("'");
        curl.append(" \\\n  -H 'Content-Type: application/json'");
        curl.append(" \\\n  -H 'Accept: application/json'");
        curl.append(" \\\n  -d '").append(jsonBody.replace("'", "\\'")).append("'");
        return curl.toString();
    }

    /**
     * Make a POST request using OkHttp
     * @param urlString URL
     * @param jsonBody JSON body as string
     * @param callback Response callback
     */
    private void postRequest(String urlString, String jsonBody, ResponseCallback callback) {
        // Print curl command for debugging
        String curlCommand = generateCurlCommand(urlString, jsonBody);
        Log.d(TAG, "=== CURL Command ===\n" + curlCommand);
        Log.d(TAG, "=== Request Body ===\n" + jsonBody);
        
        RequestBody body = RequestBody.create(jsonBody, JSON);
        Request request = new Request.Builder()
                .url(urlString)
                .post(body)
                .addHeader("Content-Type", "application/json")
                .addHeader("Accept", "application/json")
                .build();
        
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                Log.e(TAG, "Request failed: " + urlString, e);
                if (callback != null) {
                    callback.onFailure(e.getMessage());
                }
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                try {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    
                    if (response.isSuccessful()) {
                        Log.d(TAG, "=== Response SUCCESS ===\nCode: " + response.code() + "\nBody: " + responseBody);
                        if (callback != null) {
                            callback.onSuccess(responseBody);
                        }
                    } else {
                        Log.e(TAG, "=== Response ERROR ===\nCode: " + response.code() + "\nBody: " + responseBody);
                        Log.e(TAG, "Headers: " + response.headers());
                        if (callback != null) {
                            callback.onFailure("HTTP error: " + response.code() + ", body: " + responseBody);
                        }
                    }
                } finally {
                    response.close();
                }
            }
        });
    }
}

