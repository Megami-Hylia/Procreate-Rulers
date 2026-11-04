#include "../src/Geometry.h"
#include <assert.h>
#include <stdio.h>
static void near(double a,double b){assert(fabs(a-b)<.0001);}
int main(void) {
    PRGuide g=pr_default_guide((PRPoint){100,200});
    PRPoint p=pr_project((PRPoint){125,250},g);near(p.x,125);near(p.y,200);
    g.angle=M_PI/2;p=pr_project((PRPoint){125,250},g);near(p.x,100);near(p.y,250);
    g.angle=.7;PRPoint q={13,52};p=pr_local(pr_world(q,g),g);near(p.x,q.x);near(p.y,q.y);
    g.kind=PRFlexible;
    for(int shape=0;shape<4;shape++) {
        g.points[1]=(PRPoint){-.6,-.3*(shape+1)};g.points[2]=(PRPoint){.6,shape%2?.8:-.8};
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
    for(int i=0;i<4;i++){p=pr_handle(i,g);assert(p.x>=0 && p.x<=1024 && p.y>=0 && p.y<=768);}
    near(g.points[1].x,old.x);
    puts("Straight/flexible ruler projection and editable curve tests passed");
}
