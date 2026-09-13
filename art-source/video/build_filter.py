#!/usr/bin/env python3
"""Construit le filter_complex : shake d'impact + bloom + aberration
chromatique + grain + vignette."""

IMPACTS = [20, 26, 33, 43, 58]
AMP     = [4.5, 5.0, 5.8, 6.8, 9.0]   # amplitude verticale en px
PAD = 40

def shake(axis):
    terms = []
    for fi, a in zip(IMPACTS, AMP):
        if axis == "y":
            t = (f"{a:.2f}*exp(-(n-{fi})/5.5)"
                 f"*cos(2*PI*(n-{fi})/4.2)")
        else:
            t = (f"{a*0.45:.2f}*exp(-(n-{fi})/5.0)"
                 f"*sin(2*PI*(n-{fi})/5.1)")
        terms.append(f"if(gte(n,{fi}),{t},0)")
    return "+".join(terms)

DX, DY = shake("x"), shake("y")

fc = f"""[0:v]format=rgb24,setsar=1[base];
[1:v]format=rgb24,setsar=1[dust];
[base][dust]blend=all_mode=screen[comp];
[comp]pad=w=iw+{2*PAD}:h=ih+{2*PAD}:x={PAD}:y={PAD}:color=black[pad];
[pad]crop=1920:1080:x='{PAD}+({DX})':y='{PAD}+({DY})'[shk];
[shk]split[a][b];
[b]gblur=sigma=18[blur];
[a][blur]blend=all_mode=screen:all_opacity=0.38[bloom];
[bloom]rgbashift=rh=-2:rv=1:bh=2:bv=-1[ca];
[ca]eq=contrast=1.07:brightness=-0.012:saturation=1.0[lvl];
[lvl]noise=alls=6:allf=t+u[grain];
[grain]vignette=angle=PI/5.2,format=yuv420p[out]"""

open("filter.txt", "w").write(fc)
print(fc)
