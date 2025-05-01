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

public class MainActivity extends AppCompatActivity {

    private static final String TAG = "MainActivity";
    private static final String START_APP_PATH = "/start-app";
    private String nodeId;
    private MessageClient messageClient;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Log.d(TAG, "✅ MainActivity 실행됨!");

        messageClient = Wearable.getMessageClient(this);
        getConnectedNode();

        sendMessageToWatch();
    }

    private void getConnectedNode() {
        Wearable.getNodeClient(this).getConnectedNodes()
                .addOnCompleteListener(new OnCompleteListener<List<Node>>() {
                    @Override
                    public void onComplete(@NonNull Task<List<Node>> task) {
                        if (task.isSuccessful() && task.getResult() != null && !task.getResult().isEmpty()) {
                            nodeId = task.getResult().get(0).getId();
                            Log.d(TAG, "✅ 연결된 노드 ID: " + nodeId);
                        } else {
                            Log.e(TAG, "❌ 노드 연결 실패");
                        }
                    }
                });
    }

    private void sendMessageToWatch() {
        if (nodeId == null) {
            Log.w(TAG, "⏳ 노드 ID가 아직 준비되지 않음");
            return;
        }

        try {
            JSONObject json = new JSONObject();
            json.put("name", "");
            json.put("birthDate", "20250501");
            json.put("action", "launch_app");
            String payload = json.toString();

            Log.d(TAG, "📤 워치에 전송할 메시지: " + payload);
            messageClient.sendMessage(nodeId, START_APP_PATH, payload.getBytes())
                    .addOnSuccessListener(unused -> Log.d(TAG, "✅ 워치 메시지 전송 성공"))
                    .addOnFailureListener(e -> Log.e(TAG, "❌ 메시지 전송 실패", e));

        } catch (Exception e) {
            Log.e(TAG, "❌ JSON 생성 오류", e);
        }
    }
}
