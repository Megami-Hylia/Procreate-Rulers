#include "../src/Geometry.h"
#include <assert.h>
#include <stdio.h>
static void near(double a,double b){assert(fabs(a-b)<.0001);}
int main(void) {
    PRGuide g={{100,200},0,80,.5,PRLine};
    PRPoint p=pr_project((PRPoint){125,250},g); near(p.x,125);near(p.y,200);
    g.angle=M_PI/2;p=pr_project((PRPoint){125,250},g);near(p.x,100);near(p.y,250);
    g.angle=0;g.kind=PRSquare90;p=pr_project((PRPoint){102,240},g);near(p.x,100);near(p.y,240);
    g.kind=PRSquare45;p=pr_project((PRPoint){120,221},g);near(p.x,120.5);near(p.y,220.5);
    g.kind=PRCircle;p=pr_project((PRPoint){110,210},g);near(hypot(p.x-100,p.y-200),80);
    g.kind=PREllipse;
    for(int i=0;i<1000;i++) {
        PRPoint source={i*.71-200,i*.39-100};p=pr_project(source,g);
        double x=(p.x-100)/80,y=(p.y-200)/40;near(x*x+y*y,1);
        PRPoint again=pr_project(p,g);assert(pr_distance2(p,again)<.0001);
    }
    g.kind=PRCurve;
    for(int i=0;i<=100;i++) {
        PRPoint q=pr_world(pr_bezier(i/100.,80),g);p=pr_project(q,g);assert(pr_distance2(q,p)<.0001);
    }
    g.angle=.7; PRPoint q={13,52};p=pr_local(pr_world(q,g),g);near(p.x,q.x);near(p.y,q.y);
    puts("Geometry tests passed");
}
