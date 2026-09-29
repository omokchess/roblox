# 수신기(34999)가 받은 시트(dataURL)를 PNG 로. python tools/card_art/sheet_png.py 이름
import base64, os, sys
S = r"C:/Users/hhksh/AppData/Local/Temp/claude/C--claude/e0918b58-7b1f-4c91-a666-2b1281cb18c2/scratchpad"
name = sys.argv[1]
d = open(os.path.join(S, "recv", name + ".txt")).read().split(",", 1)[1]
open(os.path.join(S, name + ".png"), "wb").write(base64.b64decode(d))
print(os.path.join(S, name + ".png"))
