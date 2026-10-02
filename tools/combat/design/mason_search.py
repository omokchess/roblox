"""망치 면-정 머리 닿는 자세 훑기: 망치 머리가 몸통·머리·왼팔을 파고들지 않는 것만"""
import sys; sys.path.insert(0,'.')
from mason_gen import *

def inside(P, part, pts, half):
    cf = solve(P)[part]; n=0
    for p in pts:
        q = cf.inv().pt(p)
        if all(abs(q[i]) < half[i] for i in range(3)): n += 1
    return n

def hammer_pts(P):
    return [wpoint(P,"W",(x,2.2+y,z)) for x in (-0.28,0.28) for y in (-0.28,0.28) for z in (-0.8,-0.3,0.3,0.9,1.15)] + [wpoint(P,"W",(0,y,0)) for y in (-0.4,0.3,1.0,1.6)]

def hits(P):
    pts=hammer_pts(P)
    # 왼팔은 뺀다: 정 머리가 주먹 바로 위라 망치 면이 R6 팔 상자 모서리에 걸치는 건 피할 수 없다(실제 주먹은 작음)
    return inside(P,"Torso",pts,(1,1,0.5))+inside(P,"Head",pts,(0.6,0.6,0.6))

if __name__ == "__main__":
    res=[]
    for ry_ in [-20,-35]:
      for tor in [-14,-26]:
        P0 = {"Root": (0, -0.25, 0, 0, ry_, 0), "Torso": (tor, 0, 0), "Head": (-18, 14, 0), "RLeg": (-14, 0, 10), "LLeg": (22, 0, -10)}
        for lt in [(-0.3,-0.5,-1.3),(-0.1,-0.8,-1.1),(-0.4,-0.2,-1.45),(0.0,-0.4,-1.4),(-0.6,-0.6,-1.2)]:
          for yd in [(0,1,0.15),(0,1,0.45),(0.25,1,0.3),(-0.2,1,0.3),(0.4,1,0.6)]:
            Q=dict(P0); e=chisel(Q,lt,yd)
            if e>0.12: continue
            cap=wpoint(Q,"O",CAP); d=norm(mv(weapon_cf(Q,"O").R,(0,1,0)))
            a=norm(cross(d,(0,1,0))); b=cross(d,a); pv=pivot(Q,"R")
            for ch in [0.5,0.8]:
              for i in range(0,360,10):
                hy=add(scale(a,math.cos(i*D)),scale(b,math.sin(i*D)))
                R=frame(hy,scale(d,-1))
                hp=sub(cap,mv(R,(0,2.2-ch,-0.8)))
                er=abs(dist(hp,pv)-ARM)
                if er>0.08: continue
                Z=dict(Q); Z["RArm"],e2=reach(Z,"R",hp,hint=(80,30,0)); Z["W"]=aim(Z,"W",R,sub(hp,mv(R,(0,ch,0))))
                if hits(Z)==0:
                    T=T_of(Z)
                    res.append((round(er,3),ry_,tor,lt,yd,ch,i,[round(v,2) for v in mv(tr(T.R),hy)],[round(v,2) for v in T.inv().pt(hp)],round(wpoint(Z,"O",BIT)[1],2)))
    print(len(res))
    for r in sorted(res,key=lambda r:abs(r[7][1]))[:30]: print(r)
