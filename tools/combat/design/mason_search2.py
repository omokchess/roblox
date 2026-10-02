"""정 머리에 망치 면이 닿되 면 방향을 정 축에서 최대 35° 비스듬히 허용. 망치가 몸을 파고들지 않고,
손이 망치 머리의 오른쪽(몸 기준)에 있는 자연스러운 쥠만."""
import sys; sys.path.insert(0,'.')
import mason_search as S
from mason_gen import *

def run(bodies, lts, yds, OY=0.0, maxdev=35, top=25):
    res=[]
    for P0 in bodies:
        T0=T_of(P0)
        for lt in lts:
            for yd in yds:
                # lt = (아래로 숙인 각, 옆 기울기): 왼 어깨에서 팔 길이만큼 그 방향(몸통 공간)
                dn, sx = lt
                Q=dict(P0); Q["LArm"],e=reach(Q,"L",add(pivot(P0,"L"),scale(mv(T0.R,norm((sx,-math.tan(dn*D),-1))),ARM)),hint=(80,-10,0))
                if e>0.12: continue
                hl=hand(Q,"L"); ydw=mv(T0.R,yd)
                Q["O"]=aim_axis(Q,"O",ydw,sub(hl,scale(norm(ydw),OY)))
                cap=wpoint(Q,"O",CAP); d=norm(mv(weapon_cf(Q,"O").R,(0,1,0)))
                a=norm(cross(d,(0,1,0))); b=cross(d,a); pv=pivot(Q,"R")
                for dev in range(0,maxdev+1,7):
                    for k in range(0,360,90 if dev else 360):
                        u=add(scale(a,math.cos(k*D)),scale(b,math.sin(k*D)))
                        n=norm(add(scale(d,-1),scale(u,math.tan(dev*D))))
                        a2=norm(cross(n,(0,1,0))); b2=cross(n,a2)
                        for ch in (0.5,0.8):
                            for i in range(0,360,10):
                                hy=add(scale(a2,math.cos(i*D)),scale(b2,math.sin(i*D)))
                                hyt=mv(tr(T0.R),hy)
                                if hyt[0]>-0.4: continue  # 손이 머리 오른쪽(자루가 손에서 왼쪽으로)
                                R=frame(hy,n)
                                hp=sub(cap,mv(R,(0,2.2-ch,-0.8)))
                                er=abs(dist(hp,pv)-ARM)
                                if er>0.08: continue
                                Z=dict(Q); Z["RArm"],e2=reach(Z,"R",hp,hint=(80,30,0)); Z["W"]=aim(Z,"W",R,sub(hp,mv(R,(0,ch,0))))
                                if S.hits(Z)==0:
                                    T=T_of(Z)
                                    res.append((dev,round(er,3),Z["Root"][4],Z["Torso"][0],lt,yd,ch,k,i,[round(v,2) for v in hyt],[round(v,2) for v in T.inv().pt(hp)],[round(v,2) for v in T.inv().pt(cap)]))
    res.sort(key=lambda r:(r[0],r[1]))
    print(len(res))
    for r in res[:top]: print(r)
    return res

if __name__=="__main__":
    OY=float(sys.argv[1]) if len(sys.argv)>1 else 0.0
    bodies=[{"Root": (0, -0.25, 0, 0, ry, 0), "Torso": (-14, 0, 0), "Head": (-18, 14, 0), "RLeg": (-14, 0, 10), "LLeg": (22, 0, -10)} for ry in (-20,-40)]
    lts=[(20,0.3),(35,0.3),(35,0.6),(50,0.4)]
    yds=[(0,0.3,1),(0,0.8,1),(0.3,0.5,1),(0.3,1,0.5)]
    run(bodies,lts,yds,OY=OY)
