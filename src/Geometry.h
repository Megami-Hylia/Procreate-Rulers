#pragma once
#include <math.h>
typedef struct { double x, y; } PRPoint;
typedef enum { PRLine, PRFlexible } PRKind;
typedef struct {
    PRPoint center;
    double angle, radius;
    PRKind kind;
    PRPoint points[3]; // Start, bend point on the curve, end; normalized by radius.
} PRGuide;
static inline PRGuide pr_default_guide(PRPoint center) {
    return (PRGuide){center,0,180,PRLine,{{-1,0},{0,.75},{1,0}}};
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
static inline PRPoint pr_curve_control(PRGuide g) {
    return (PRPoint){2*g.points[1].x-(g.points[0].x+g.points[2].x)/2,2*g.points[1].y-(g.points[0].y+g.points[2].y)/2};
}
static inline PRPoint pr_curve(double t,PRGuide g) {
    double u=1-t;PRPoint c=pr_curve_control(g);
    return (PRPoint){g.radius*(u*u*g.points[0].x+2*u*t*c.x+t*t*g.points[2].x),g.radius*(u*u*g.points[0].y+2*u*t*c.y+t*t*g.points[2].y)};
}
static inline PRPoint pr_handle(int index,PRGuide g) {
    if(index==4)return g.center;
    if(g.kind==PRLine)return pr_world((PRPoint){index==0?-g.radius:g.radius,0},g);
    return pr_world((PRPoint){g.points[index].x*g.radius,g.points[index].y*g.radius},g);
}
static inline void pr_move_handle(PRGuide *g,int index,PRPoint world) {
    if(index==4){g->center=world;return;}
    if(index<0 || index>2)return;
    if(g->kind==PRLine){
        PRPoint opposite=pr_handle(index==0?2:0,*g);
        PRPoint first=index==0?world:opposite,last=index==0?opposite:world;
        double length=hypot(last.x-first.x,last.y-first.y);if(length<2)return;
        g->center=(PRPoint){(first.x+last.x)/2,(first.y+last.y)/2};g->radius=length/2;g->angle=atan2(last.y-first.y,last.x-first.x);return;
    }
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
    double candidates[5]={0,.5,1,-1,-1};
    if(g.kind==PRFlexible){
        PRPoint a=pr_handle(0,unit),b=pr_handle(2,unit),c=pr_world(pr_curve_control(unit),unit);
        double dx=a.x-2*c.x+b.x,dy=a.y-2*c.y+b.y;
        if(fabs(dx)>1e-12)candidates[3]=(a.x-c.x)/dx;
        if(fabs(dy)>1e-12)candidates[4]=(a.y-c.y)/dy;
    }
    for(int i=0;i<5;i++){
        double t=candidates[i];if(t<0 || t>1)continue;
        PRPoint p=g.kind==PRLine?pr_world((PRPoint){2*t-1,0},unit):pr_world(pr_curve(t,unit),unit);
        minX=fmin(minX,p.x);maxX=fmax(maxX,p.x);minY=fmin(minY,p.y);maxY=fmax(maxY,p.y);
    }
    g.radius=fmin(width*.65/fmax(.1,maxX-minX),height*.45/fmax(.1,maxY-minY));
    g.radius=fmax(1,fmin(500,g.radius));
    g.center=(PRPoint){width/2-g.radius*(minX+maxX)/2,height*.6-g.radius*(minY+maxY)/2};
    return g;
}
