#pragma once
#include "Geometry.h"
#include <stddef.h>
#include <stdint.h>
#include <float.h>

// Procreate 5.4.8/57066: renderInstances reads origin at 0x10, variance at 0x78,
// and plotCurve allocates/copies each dab with stride 0x150. Other fields stay opaque.
typedef struct {
    uint8_t prefix[0x10];
    float origin[2];
    uint8_t middle[0x78-0x18];
    float variance[2];
    uint8_t suffix[0x150-0x80];
} PRNativeDab;
_Static_assert(sizeof(PRNativeDab)==0x150,"Native dab stride");
_Static_assert(offsetof(PRNativeDab,origin)==0x10,"Native dab origin");
_Static_assert(offsetof(PRNativeDab,variance)==0x78,"Native dab variance");

static inline void pr_constrain_dabs(PRNativeDab *dabs,size_t count,PRGuide guide) {
    for(size_t i=0;i<count;i++){
        PRNativeDab *dab=dabs+i;
        PRPoint original={dab->origin[0],dab->origin[1]};
        PRPoint jittered={original.x+dab->variance[0],original.y+dab->variance[1]};
        if(!isfinite(original.x) || !isfinite(original.y) || !isfinite(jittered.x) || !isfinite(jittered.y))continue;
        PRPoint p=pr_project(original,guide),q=pr_project(jittered,guide);
        if(!isfinite(p.x) || !isfinite(p.y) || !isfinite(q.x) || !isfinite(q.y) || fabs(p.x)>FLT_MAX || fabs(p.y)>FLT_MAX || fabs(q.x-p.x)>FLT_MAX || fabs(q.y-p.y)>FLT_MAX)continue;
        dab->origin[0]=(float)p.x;dab->origin[1]=(float)p.y;
        dab->variance[0]=(float)(q.x-p.x);dab->variance[1]=(float)(q.y-p.y);
    }
}
