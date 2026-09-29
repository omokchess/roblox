#!/usr/bin/env bash
# Studio 자체 스크린샷(보기 > 스크린샷)으로 저장된 가장 새 파일 경로. 모니터가 꺼져 화면 캡처가 멈춰도 이건 된다.
ls -t "/c/Users/hhksh/OneDrive/사진/Roblox/"RobloxScreenShot*.png 2>/dev/null | head -1
