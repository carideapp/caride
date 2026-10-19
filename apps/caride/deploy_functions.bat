@echo off
title CaRide - TransactPay Production Functions Deployment
color 0A
cd /d "%~dp0"

echo =====================================================================
echo           CaRide - Production Firebase Functions Deployment
echo   Deploying TransactPay Virtual Accounts & Production Webhook
echo =====================================================================
echo.
echo Working Directory: %CD%
echo Project: caride-app
echo Target: functions (TransactPay Dedicated Accounts & Live Webhook)
echo.
echo [1/2] Compiling TypeScript backend...
cd functions && call npm run build && cd ..
if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo [ERROR] TypeScript compilation failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/2] Deploying functions to Firebase...
call firebase deploy --only functions

echo.
echo =====================================================================
echo   Deployment command completed with exit code %ERRORLEVEL%.
echo =====================================================================
pause
