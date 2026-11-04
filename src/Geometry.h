#pragma once
#include <math.h>
typedef struct { double x, y; } PRPoint;
typedef enum { PRLine, PRFlexible } PRKind;
typedef struct {
    PRPoint center;
    double angle, radius;
    PRKind kind;
    PRPoint points[4]; // Cubic endpoints/control handles, normalized by radius.
} PRGuide;
static inline PRGuide pr_default_guide(PRPoint center) {
    return (PRGuide){center,0,180,PRLine,{{-1,0},{-.4,-.8},{.4,-.8},{1,0}}};
}
static inline PRPoint pr_local(PRPoint p, PRGuide g) {
    double x=p.x-g.center.x,y=p.y-g.center.y,c=cos(g.angle),s=sin(g.angle);
    return (PRPoint){x*c+y*s,-x*s+y*c};
}
static inline PRPoint pr_world(PRPoint p, PRGuide g) {
    double c=cos(g.angle),s=sin(g.angle);
    return (PRPoint){g.center.x+p.x*c-p.y*s,g.center.y+p.x*s+p.y*c};
}
static inline double pr_distance2(PRPoint a,PRPoint b) {
    return (a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y);
}
static inline PRPoint pr_curve(double t,PRGuide g) {
    double u=1-t,w[4]={u*u*u,3*u*u*t,3*u*t*t,t*t*t};
    PRPoint p={0,0};
    for(int i=0;i<4;i++){p.x+=w[i]*g.points[i].x*g.radius;p.y+=w[i]*g.points[i].y*g.radius;}
    return p;
}
static inline PRPoint pr_handle(int index,PRGuide g) {
    if(index==4)return g.center;
    return pr_world((PRPoint){g.points[index].x*g.radius,g.points[index].y*g.radius},g);
}
static inline void pr_move_handle(PRGuide *g,int index,PRPoint world) {
    if(index==4){g->center=world;return;}
    if(index<0 || index>3)return;
    PRPoint local=pr_local(world,*g);double radius=fmax(1,g->radius);
    g->points[index]=(PRPoint){local.x/radius,local.y/radius};
}
static inline PRPoint pr_project(PRPoint world,PRGuide g) {
    PRPoint q=pr_local(world,g);
    if(g.kind==PRLine)return pr_world((PRPoint){q.x,0},g);
    double best=INFINITY,bt=0;
    for(int i=0;i<=128;i++) {
        double t=i/128.,d=pr_distance2(q,pr_curve(t,g));
        if(d<best){best=d;bt=t;}
    }
    double lo=fmax(0,bt-1/128.),hi=fmin(1,bt+1/128.);
    for(int i=0;i<32;i++) {
        double t1=lo+(hi-lo)/3,t2=hi-(hi-lo)/3;
        if(pr_distance2(q,pr_curve(t1,g))<pr_distance2(q,pr_curve(t2,g)))hi=t2;else lo=t1;
    }
    PRPoint p=pr_curve((lo+hi)/2,g);
    for(int i=0;i<2;i++){PRPoint end=pr_curve(i,g);if(pr_distance2(q,end)<pr_distance2(q,p))p=end;}
    return pr_world(p,g);
}
static inline double pr_snap_angle(double angle) {
    double cardinal=round(angle/(M_PI/2))*(M_PI/2);
    return fabs(angle-cardinal)<3*M_PI/180 ? cardinal : angle;
}
static inline PRGuide pr_fit_guide(PRGuide g,double width,double height) {
    PRGuide unit=g;unit.center=(PRPoint){0,0};unit.radius=1;
    double minX=INFINITY,minY=INFINITY,maxX=-INFINITY,maxY=-INFINITY;
    for(int i=0;i<4;i++) {
        PRPoint p=pr_handle(i,unit);minX=fmin(minX,p.x);maxX=fmax(maxX,p.x);minY=fmin(minY,p.y);maxY=fmax(maxY,p.y);
    }
    g.radius=fmin(width*.65/fmax(.1,maxX-minX),height*.45/fmax(.1,maxY-minY));
    g.radius=fmax(1,fmin(500,g.radius));
    g.center=(PRPoint){width/2-g.radius*(minX+maxX)/2,height*.6-g.radius*(minY+maxY)/2};
    return g;
}
