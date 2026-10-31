#pragma once
#include <math.h>
typedef struct { double x, y; } PRPoint;
typedef enum { PRLine, PRSquare90, PRSquare45, PRCircle, PREllipse, PRCurve, PRProtractor } PRKind;
typedef struct { PRPoint center; double angle, radius, ratio; PRKind kind; } PRGuide;
static inline PRPoint pr_local(PRPoint p, PRGuide g) {
    double x=p.x-g.center.x, y=p.y-g.center.y, c=cos(g.angle), s=sin(g.angle);
    return (PRPoint){x*c+y*s, -x*s+y*c};
}
static inline PRPoint pr_world(PRPoint p, PRGuide g) {
    double c=cos(g.angle), s=sin(g.angle);
    return (PRPoint){g.center.x+p.x*c-p.y*s, g.center.y+p.x*s+p.y*c};
}
static inline double pr_distance2(PRPoint a, PRPoint b) {
    return (a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y);
}
static inline PRPoint pr_bezier(double t, double r) {
    return (PRPoint){r*(2*t-1), -2*r*t*(1-t)};
}
static inline PRPoint pr_project(PRPoint p, PRGuide g) {
    PRPoint q=pr_local(p,g), a={q.x,0};
    double r=fmax(1,g.radius), ratio=fmax(.1,g.ratio);
    if (g.kind==PRSquare90) {
        PRPoint b={0,q.y}; if(pr_distance2(q,b)<pr_distance2(q,a)) a=b;
    } else if(g.kind==PRSquare45) {
        PRPoint b={(q.x+q.y)/2,(q.x+q.y)/2};
        if(pr_distance2(q,b)<pr_distance2(q,a)) a=b;
    } else if(g.kind==PRCircle) {
        double t=atan2(q.y,q.x); a=(PRPoint){r*cos(t),r*sin(t)};
    } else if(g.kind==PREllipse || g.kind==PRCurve) {
        // Search globally before refining to avoid ellipse Newton local maxima.
        double best=INFINITY, bt=0, span=g.kind==PREllipse ? 2*M_PI : 1;
        for(int i=0;i<=128;i++) {
            double t=span*i/128;
            PRPoint b=g.kind==PREllipse ? (PRPoint){r*cos(t),r*ratio*sin(t)} : pr_bezier(t,r);
            double d=pr_distance2(q,b); if(d<best){best=d;bt=t;}
        }
        double lo=bt-span/128, hi=bt+span/128;
        if(g.kind==PRCurve){lo=fmax(0,lo);hi=fmin(1,hi);}
        for(int i=0;i<32;i++) {
            double t1=lo+(hi-lo)/3,t2=hi-(hi-lo)/3;
            PRPoint b1=g.kind==PREllipse ? (PRPoint){r*cos(t1),r*ratio*sin(t1)} : pr_bezier(t1,r);
            PRPoint b2=g.kind==PREllipse ? (PRPoint){r*cos(t2),r*ratio*sin(t2)} : pr_bezier(t2,r);
            if(pr_distance2(q,b1)<pr_distance2(q,b2)) hi=t2; else lo=t1;
        }
        double t=(lo+hi)/2;
        a=g.kind==PREllipse ? (PRPoint){r*cos(t),r*ratio*sin(t)} : pr_bezier(t,r);
    }
    return pr_world(a,g);
}
