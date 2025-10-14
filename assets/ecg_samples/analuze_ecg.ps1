$ServerUrl = "http://34.69.44.173:7001/predict_single_lead"
$Threshold = 0.31
$Files = Get-ChildItem -Path . -Filter "ecg_2025-10-14T*_normal_raw.txt"

foreach ($file in $Files) {
    Write-Host "🚀 Uploading $($file.Name)..."
    
    # curl.exe로 강제 지정
    $response = & curl.exe -s -X POST $ServerUrl -F "file=@$($file.FullName)" 

    if ($response) {
        try {
            $json = $response | ConvertFrom-Json
            $distances = $json.result.distance_from_median
            $hasAbnormal = $false

            foreach ($val in $distances) {
                if ($val -gt $Threshold) {
                    $hasAbnormal = $true
                    break
                }
            }

            # 파일명 처리
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $newBaseName = $baseName
            if ($hasAbnormal) {
                $newBaseName = $baseName -replace "normal", "abnormal"
            }

            $jsonFileName = "$newBaseName.json"
            $jsonFilePath = Join-Path $file.DirectoryName $jsonFileName

            # Compact JSON으로 저장 (한 줄 JSON)
            $compactJson = ($json | ConvertTo-Json -Depth 10 -Compress)
            Set-Content -Path $jsonFilePath -Value $compactJson -Encoding UTF8

            # 원본 txt 파일도 abnormal로 이름 변경
            if ($hasAbnormal) {
                $newTxtName = $file.Name -replace "normal", "abnormal"
                $newTxtPath = Join-Path $file.DirectoryName $newTxtName
                Rename-Item $file.FullName $newTxtPath -Force
                Write-Host "⚠️ Abnormal detected → renamed to $newTxtName and JSON saved as $jsonFileName"
            } else {
                Write-Host "✅ Normal result → JSON saved as $jsonFileName"
            }

        } catch {
            Write-Host "❌ JSON parsing failed for $($file.Name)"
        }
    } else {
        Write-Host "❌ No response from server for $($file.Name)"
    }
}
