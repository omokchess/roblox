import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *
U = (0, 1, 0)
def up(name, P, wd=U, od=U):
    P["W"] = aim_axis(P, "W", wd); P["O"] = aim_axis(P, "O", od)
    keys = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W", "O"]
    print(f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in keys if k in P) + " }")
up("STUMBLE", {"Root": (0.2, -0.4, 0, 0, -30, -14), "Torso": (-20, 0, 10), "Head": (-2, 20, 10), "RArm": (80, 0, 60), "LArm": (80, 0, -60), "RLeg": (20, 0, 10), "LLeg": (-10, 0, -4)})
up("STUMBLE2", {"Root": (-0.2, -0.3, 0, 0, -30, 12), "Torso": (-14, 0, -8), "Head": (-2, 20, 10), "RArm": (90, 0, 50), "LArm": (90, 0, -70), "RLeg": (4, 0, 4), "LLeg": (-4, 0, -12)})
up("PEEK", {"Root": (0, -0.1, 0, 0, -40, 0), "Torso": (-8, 0, 0), "Head": (4, 26, 10), "RArm": (108, 6, 8), "LArm": (22, 0, -12), "RLeg": (8, 0, -2), "LLeg": (-6, 0, 2)})
up("HOP", {"Root": (0.4, 0.8, 1.6, 0, 120, 0), "Torso": (6, 0, 0), "Head": (20, -40, 0), "RArm": (150, 0, 60), "LArm": (150, 0, -60), "RLeg": (40, 0, 10), "LLeg": (-30, 0, -10)})
up("HOP2", {"Root": (0.6, -0.3, 1.9, 0, 30, 6), "Torso": (-16, 0, 6), "Head": (0, 20, 0), "RArm": (90, 0, 60), "LArm": (90, 0, -60), "RLeg": (10, 0, 6), "LLeg": (-10, 0, -6)})
up("HUDDLE", {"Root": (0, -0.45, 0.3, 0, 50, 0), "Torso": (-30, 0, 0), "Head": (-10, -60, 0), "RArm": (60, 50, 0), "LArm": (60, -50, 0), "RLeg": (20, 0, 6), "LLeg": (-10, 0, -6)})
up("SHUDDER", {"Root": (0, -0.5, 0.1, 0, -30, 0), "Torso": (-30, 0, 0), "Head": (-20, 20, 0), "RArm": (40, 20, 30), "LArm": (40, -20, -30), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6)})
up("BURST", {"Root": (0, 0, 0, 0, -30, 0), "Torso": (16, 0, 0), "Head": (26, 20, 0), "RArm": (120, -40, 60), "LArm": (120, 40, -60), "RLeg": (4, 0, 12), "LLeg": (-4, 0, -12)})
