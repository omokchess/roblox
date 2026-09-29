#!/bin/bash
# 시트 요청 후 PNG 로: tools/card_art/snap.sh <직업> — 브라우저가 sheet.html?cls=..&send=sheet_<직업> 을 연 뒤 부른다
python "C:/PROJECT-EDIT(by roblox)/tools/card_art/sheet_png.py" "sheet_$1"
