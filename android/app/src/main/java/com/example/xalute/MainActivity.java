package com.example.xalute;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.android.gms.wearable.MessageClient;
import com.google.android.gms.wearable.Node;
import com.google.android.gms.wearable.Wearable;

import org.json.JSONObject;

import java.util.List;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.xalute/watch";
    private static final String START_APP_PATH = "/start-app";
    private String nodeId;
    private MessageClient messageClient;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        messageClient = Wearable.getMessageClient(this);
        getConnectedNode();

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
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
}
