#include "../src/Geometry.h"
#include "../src/NativePlot.h"
#include <string.h>
#include <assert.h>
#include <stdio.h>
static void near(double a,double b){assert(fabs(a-b)<.0001);}
int main(void) {
    PRGuide g=pr_default_guide((PRPoint){100,200});
    PRPoint p=pr_project((PRPoint){125,250},g);near(p.x,125);near(p.y,200);
    g.angle=M_PI/2;p=pr_project((PRPoint){125,250},g);near(p.x,100);near(p.y,250);
    g.angle=.7;PRPoint q={13,52};p=pr_local(pr_world(q,g),g);near(p.x,q.x);near(p.y,q.y);
    // Moving a straight endpoint changes orientation while keeping the other endpoint fixed.
    g.angle=0;PRPoint end=pr_handle(2,g);pr_move_handle(&g,0,(PRPoint){40,80});p=pr_handle(2,g);near(p.x,end.x);near(p.y,end.y);
    g.kind=PRFlexible;
    for(int shape=0;shape<4;shape++) {
        g.points[1]=(PRPoint){.1*(shape-1),shape%2?.8:-.8};
        p=pr_curve(.5,g);near(p.x,g.points[1].x*g.radius);near(p.y,g.points[1].y*g.radius);
        g.angle=shape*.6;g.radius=80+shape*60;
        for(int i=0;i<=200;i++) {
            q=pr_world(pr_curve(i/200.,g),g);p=pr_project(q,g);assert(pr_distance2(q,p)<.0001);
        }
        for(int i=0;i<100;i++) {
            q=(PRPoint){i*7-200,i*3-100};p=pr_project(q,g);
            double brute=INFINITY;
            for(int j=0;j<=10000;j++)brute=fmin(brute,pr_distance2(q,pr_world(pr_curve(j/10000.,g),g)));
            assert(pr_distance2(q,p)<=brute+.01);
            assert(pr_distance2(p,pr_project(p,g))<.0001);
        }
    }
    q=(PRPoint){-25,360};pr_move_handle(&g,1,q);p=pr_handle(1,g);near(p.x,q.x);near(p.y,q.y);
    PRPoint old=g.points[1];pr_move_handle(&g,4,(PRPoint){20,30});near(g.points[1].x,old.x);near(g.center.x,20);
    near(pr_snap_angle(M_PI/180),0);near(pr_snap_angle(M_PI/2+.01),M_PI/2);near(pr_snap_angle(.2),.2);
    g.angle=.6;g.radius=700;g=pr_fit_guide(g,1024,768);
    for(int i=0;i<3;i++){p=pr_handle(i,g);assert(p.x>=0 && p.x<=1024 && p.y>=0 && p.y<=768);}
    for(int i=0;i<=1000;i++){p=pr_world(pr_curve(i/1000.,g),g);assert(p.x>=0 && p.x<=1024 && p.y>=0 && p.y<=768);}
    near(g.points[1].x,old.x);
    // Model the downstream renderer pulling a complete sweep into the curve's interior.
    g=pr_default_guide((PRPoint){200,200});g.kind=PRFlexible;g.angle=.6;
    PRNativeDab dabs[65],before[65];memset(dabs,0x6d,sizeof(dabs));
    PRPoint first=pr_handle(0,g),last=pr_handle(2,g);
    for(int i=0;i<65;i++){
        dabs[i].origin[0]=first.x+(last.x-first.x)*i/64.;dabs[i].origin[1]=first.y+(last.y-first.y)*i/64.;
        dabs[i].variance[0]=7;dabs[i].variance[1]=13;
    }
    memcpy(before,dabs,sizeof(dabs));pr_constrain_dabs(dabs,65,g);
    for(int i=0;i<65;i++){
        PRPoint origin={dabs[i].origin[0],dabs[i].origin[1]},jittered={origin.x+dabs[i].variance[0],origin.y+dabs[i].variance[1]};
        assert(pr_distance2(origin,pr_project(origin,g))<.00001);assert(pr_distance2(jittered,pr_project(jittered,g))<.00001);
        assert(!memcmp(dabs[i].prefix,before[i].prefix,sizeof(dabs[i].prefix)));
        assert(!memcmp(dabs[i].middle,before[i].middle,sizeof(dabs[i].middle)));
        assert(!memcmp(dabs[i].suffix,before[i].suffix,sizeof(dabs[i].suffix)));
    }
    dabs[0].origin[0]=NAN;PRNativeDab invalid=dabs[0];pr_constrain_dabs(dabs,1,g);assert(!memcmp(&invalid,dabs,sizeof(invalid)));
    puts("Geometry and post-smoothing native dab projection tests passed");
}
