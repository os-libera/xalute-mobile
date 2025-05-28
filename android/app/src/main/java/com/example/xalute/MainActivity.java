package com.example.xalute;

import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.Task;
import com.google.android.gms.wearable.Asset;
import com.google.android.gms.wearable.DataClient;
import com.google.android.gms.wearable.DataEvent;
import com.google.android.gms.wearable.DataEventBuffer;
import com.google.android.gms.wearable.DataMapItem;
import com.google.android.gms.wearable.MessageClient;
import com.google.android.gms.wearable.Wearable;
import com.google.android.gms.wearable.PutDataRequest;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.stream.Collectors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity implements DataClient.OnDataChangedListener {
    private static final String CHANNEL = "com.example.xalute/watch";
    private static final String START_APP_PATH = "/start-app";
    private MethodChannel methodChannel;
    private MessageClient messageClient;
    private String nodeId;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);

        messageClient = Wearable.getMessageClient(this);
        getConnectedNode();

        methodChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("isWatchConnected")) {
                result.success(nodeId != null);
            } else if (call.method.equals("launchWatchApp")) {
                if (nodeId == null) {
                    result.error("NO_NODE", "워치가 연결되지 않았습니다", null);
                    return;
                }

                try {
                    JSONObject json = new JSONObject();
                    json.put("name", "");
                    json.put("birthDate", "20250501");
                    json.put("action", "launch_app");
                    String payload = json.toString();

                    messageClient.sendMessage(nodeId, START_APP_PATH, payload.getBytes())
                            .addOnSuccessListener(unused -> result.success(true))
                            .addOnFailureListener(e -> result.error("SEND_FAILED", "전송 실패", e));
                } catch (Exception e) {
                    result.error("JSON_ERROR", "JSON 생성 실패", e);
                }
            } else {
                result.notImplemented();
            }
        });
    }

    private void getConnectedNode() {
        Wearable.getNodeClient(this).getConnectedNodes()
                .addOnCompleteListener(task -> {
                    if (task.isSuccessful() && task.getResult() != null && !task.getResult().isEmpty()) {
                        nodeId = task.getResult().get(0).getId();
                    } else {
                        nodeId = null;
                    }
                });
    }

    @Override
    protected void onResume() {
        super.onResume();
        Wearable.getDataClient(this).addListener(this);
    }

    @Override
    protected void onPause() {
        super.onPause();
        Wearable.getDataClient(this).removeListener(this);
    }

    @Override
    public void onDataChanged(@NonNull DataEventBuffer dataEvents) {
        for (DataEvent event : dataEvents) {
            if (event.getType() == DataEvent.TYPE_CHANGED &&
                    event.getDataItem().getUri().getPath().equals("/ecg_file")) {

                DataMapItem dataMapItem = DataMapItem.fromDataItem(event.getDataItem());
                Asset asset = dataMapItem.getDataMap().getAsset("ecg_data");
                String result = dataMapItem.getDataMap().getString("result");
                long timestamp = dataMapItem.getDataMap().getLong("timestamp");

                readAsset(asset, result, timestamp);
            }
        }
    }

    private void readAsset(Asset asset, String result, long timestamp) {
        Wearable.getDataClient(this).getFdForAsset(asset).addOnSuccessListener(assetFd -> {
            try (InputStream inputStream = assetFd.getInputStream()) {
                if (inputStream != null) {
                    String content = new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8))
                            .lines().collect(Collectors.joining("\n"));

                    JSONObject data = new JSONObject();
                    data.put("fileContent", content);
                    data.put("result", result);
                    data.put("timestamp", timestamp);

                    methodChannel.invokeMethod("onEcgFileReceived", data.toString());
                    Log.d("MainActivity", "📥 Flutter로 ECG 파일 및 결과 전달 완료");
                }
            } catch (Exception e) {
                Log.e("MainActivity", "❌ 파일 읽기 실패", e);
            }
        }).addOnFailureListener(e -> Log.e("MainActivity", "❌ Asset 가져오기 실패", e));
    }
}