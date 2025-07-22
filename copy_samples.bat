@echo off
setlocal enabledelayedexpansion

:: 경로 설정 (필요시 절대경로로 수정)
set "SRC_DIR=assets\ecg_samples"
set "SRC_FILE=ecg_2025-07-21T20-18-52_abnormal_raw"

:: 1~31일 반복
for /L %%D in (1,1,31) do (
    set "DAY=%%D"
    if %%D LSS 10 set "DAY=0%%D"
    
    :: 결과 종류 결정
    set /A MOD=%%D %% 2
    if !MOD! EQU 0 (
        set "RESULT=normal"
    ) else (
        set "RESULT=abnormal"
    )

    set "DATE=2025-07-!DAY!T09-00-00"
    set "NEWNAME=ecg_!DATE!_!RESULT!_raw"

    copy "%SRC_DIR%\%SRC_FILE%.txt" "%SRC_DIR%\!NEWNAME!.txt" > nul
    copy "%SRC_DIR%\%SRC_FILE%.json" "%SRC_DIR%\!NEWNAME!.json" > nul

    echo 복사 완료: !NEWNAME!.{txt,json}
)

echo 모든 복사 완료.
pause
