#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>
#include <stdint.h>
#import "Geometry.h"
#import "NativePlot.h"

@interface PRLayer : UIView <UIGestureRecognizerDelegate>
@property(nonatomic) PRGuide guide;
@property(nonatomic) BOOL snap, selecting;
@property(nonatomic,weak) UIView *canvas;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic) NSInteger dragIndex;
@property(nonatomic) PRPoint dragStart;
@property(nonatomic) CGFloat rotationStart;
@property(nonatomic,strong) UIButton *rulerButton, *symmetryButton;
@property(nonatomic,weak) UIView *transformButton;
@property(nonatomic,weak) UIViewController *documentController;
@property(nonatomic) BOOL guideVisible, rulerLocked;
@property(nonatomic) NSUInteger nativeSamples;
@property(nonatomic,strong) UIButton *lockButton;
@property(nonatomic,strong) UIView *symmetryPanel;
@property(nonatomic,strong) UISegmentedControl *symmetryModes;
@property(nonatomic,strong) UILabel *symmetryStatus;
- (void)resetRuler;
- (void)fitRuler;

- (void)refreshPlacement;
@end
static __weak PRLayer *activeLayer;
static BOOL nativeHookReady;
static BOOL nativePlotHookReady;

// Getter calls are restricted to documented-by-metadata object-returning methods.
static id nativeObject(id object, NSString *name) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[object methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=2 || signature.methodReturnType[0]!='@')return nil;
    return ((id (*)(id,SEL))[object methodForSelector:selector])(object,selector);
}
static BOOL nativeVoid(id object, NSString *name) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[object methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=2 || signature.methodReturnType[0]!='v')return NO;
    ((void (*)(id,SEL))[object methodForSelector:selector])(object,selector);return YES;
}
static BOOL nativeInteger(id object, NSString *name, NSInteger value) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[object methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=3 || signature.methodReturnType[0]!='v')return NO;
    const char *type=[signature getArgumentTypeAtIndex:2];
    if(type[0]!='Q' && type[0]!='q')return NO;
    ((void (*)(id,SEL,NSInteger))[object methodForSelector:selector])(object,selector,value);return YES;
}
static BOOL nativeBool(id object, NSString *name, BOOL value) {
    SEL selector=NSSelectorFromString(name);
    NSMethodSignature *signature=[object methodSignatureForSelector:selector];
    if(!signature || signature.numberOfArguments!=3 || signature.methodReturnType[0]!='v')return NO;
    const char *type=[signature getArgumentTypeAtIndex:2];
    if(type[0]!='B' && type[0]!='c')return NO;
    ((void (*)(id,SEL,BOOL))[object methodForSelector:selector])(object,selector,value);return YES;
}
static UIViewController *findDocument(UIViewController *controller) {
    if(!controller)return nil;
    Class documentClass=NSClassFromString(@"DocumentViewController");
    if(documentClass && [controller isKindOfClass:documentClass] && controller.isViewLoaded && controller.view.window)return controller;
    UIViewController *found=findDocument(controller.presentedViewController);if(found)return found;
    for(UIViewController *child in controller.childViewControllers){found=findDocument(child);if(found)return found;}
    return nil;
}
static UIView *findTransform(UIView *view, PRLayer *exclude) {
    if(view==exclude || view.hidden || view.alpha<.01)return nil;
    if([view.accessibilityIdentifier isEqualToString:@"document-transform-button"])return view;
    for(UIView *child in view.subviews){UIView *found=findTransform(child,exclude);if(found)return found;}
    return nil;
}

// Native paint batches, after Procreate's constraints. No global UITouch hooks.
static id (*originalConstrainedPoints)(id,SEL,id,CGPoint);
static BOOL pointConverter(id object,SEL selector) {
    NSMethodSignature *s=[object methodSignatureForSelector:selector];
    return s && s.numberOfArguments==3 && strcmp(s.methodReturnType,@encode(CGPoint))==0 && strcmp([s getArgumentTypeAtIndex:2],@encode(CGPoint))==0;
}
static char guideSnapshotKey;
static NSData *snapshotForEngine(id engine) {
    PRLayer *layer=activeLayer;
    if(!NSThread.isMainThread || !layer.snap || !layer.guideVisible || !layer.window)return nil;
    if(engine!=nativeObject(nativeObject(layer.documentController,@"modelController"),@"valkyrieController"))return nil;
    UIView *render=nativeObject(engine,@"valkyrieView");
    if(![render isKindOfClass:UIView.class] || render.window!=layer.window)return nil;
    UIView *source=render.superview;
    SEL selector=NSSelectorFromString(@"valkyriePointFromViewPoint:");
    if(!source || !pointConverter(engine,selector))return nil;
    CGPoint (*convert)(id,SEL,CGPoint)=(void *)[engine methodForSelector:selector];
    PRGuide screen=layer.guide,document=screen;
    document.center=(PRPoint){0,0};document.angle=0;document.radius=1;
    PRPoint p[3];
    for(int i=0;i<3;i++){
        PRPoint world=screen.kind==PRLine?pr_world((PRPoint){(i-1)*screen.radius,0},screen):pr_handle(i,screen);
        CGPoint view=[layer convertPoint:CGPointMake(world.x,world.y) toView:source];
        CGPoint value=convert(engine,selector,view);
        if(!isfinite(value.x) || !isfinite(value.y))return nil;
        p[i]=(PRPoint){value.x,value.y};document.points[i]=p[i];
    }
    if(screen.kind==PRLine){document.center=p[1];document.angle=atan2(p[2].y-p[0].y,p[2].x-p[0].x);}
    return [NSData dataWithBytes:&document length:sizeof(document)];
}
static BOOL (*originalPaintBegan)(id,SEL,id,id);
static void (*originalPaintRestart)(id,SEL,id,id);
typedef id (*PRCopyOptionsIMP)(id,SEL,NSZone *) __attribute__((ns_returns_retained));
static PRCopyOptionsIMP originalCopyStrokeOptions;
static id (*originalSecondaryOptions)(id,SEL);
// The native ABI contains fourteen arrays of four floats, passed by value.
typedef struct {float values[14][4];} PRNativeCurve;
static void (*originalPlotCurve)(id,SEL,PRNativeCurve,id,float);
static id optionsForStroke(id engine,id options) {
    NSData *snapshot=snapshotForEngine(engine);
    if(!snapshot || ![options isKindOfClass:NSClassFromString(@"ValkyrieStrokeOptions")])return options;
    // Each stroke owns its snapshot; never tag the reusable brush settings object.
    id copy=[options copy];if(!copy)return options;objc_setAssociatedObject(copy,&guideSnapshotKey,snapshot,OBJC_ASSOCIATION_RETAIN);return copy;
}
static BOOL paintBegan(id engine,SEL selector,id points,id options) {
    return originalPaintBegan(engine,selector,points,optionsForStroke(engine,options));
}
static void paintRestart(id engine,SEL selector,id points,id options) {
    originalPaintRestart(engine,selector,points,optionsForStroke(engine,options));
}
// The replacement IMP must preserve copyWithZone's +1 ownership convention.
static id copyStrokeOptions(id options,SEL selector,NSZone *zone) NS_RETURNS_RETAINED;
static id copyStrokeOptions(id options,SEL selector,NSZone *zone) {
    id copy=originalCopyStrokeOptions(options,selector,zone);
    if(copy)objc_setAssociatedObject(copy,&guideSnapshotKey,objc_getAssociatedObject(options,&guideSnapshotKey),OBJC_ASSOCIATION_RETAIN);return copy;
}
static id secondaryStrokeOptions(id options,SEL selector) {
    id secondary=originalSecondaryOptions(options,selector);
    if(secondary)objc_setAssociatedObject(secondary,&guideSnapshotKey,objc_getAssociatedObject(options,&guideSnapshotKey),OBJC_ASSOCIATION_RETAIN);return secondary;
}
static void plotCurve(id plot,SEL selector,PRNativeCurve curve,id previous,float angle) {
    originalPlotCurve(plot,selector,curve,previous,angle);
    NSData *snapshot=objc_getAssociatedObject(nativeObject(plot,@"options"),&guideSnapshotKey);
    if(snapshot.length!=sizeof(PRGuide))return;
    PRGuide guide;[snapshot getBytes:&guide length:sizeof(guide)];
    SEL points=NSSelectorFromString(@"points"),count=NSSelectorFromString(@"plotCount");
    PRNativeDab *(*buffer)(id,SEL)=(void *)[plot methodForSelector:points];
    NSUInteger (*size)(id,SEL)=(void *)[plot methodForSelector:count];
    PRNativeDab *dabs=buffer(plot,points);NSUInteger n=size(plot,count);
    if(dabs && n && n<=65536)pr_constrain_dabs(dabs,n,guide);
}
static void installNativePlotHook(void) {
    if(nativePlotHookReady)return;
    Class engine=NSClassFromString(@"DocumentValkyrieController"),options=NSClassFromString(@"ValkyrieStrokeOptions"),plot=NSClassFromString(@"ValkyrieStrokePlot");
    Method begin=class_getInstanceMethod(engine,NSSelectorFromString(@"paintBegan:options:")),copy=class_getInstanceMethod(options,@selector(copyWithZone:)),draw=class_getInstanceMethod(plot,NSSelectorFromString(@"plotCurve:previousPlot:initialAngle:"));
    if(!begin || !copy || !draw)return;
    NSMethodSignature *a=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(begin)],*b=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(copy)],*c=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(draw)];
    if(a.numberOfArguments!=4 || strcmp(a.methodReturnType,@encode(BOOL)) || [a getArgumentTypeAtIndex:2][0]!='@' || [a getArgumentTypeAtIndex:3][0]!='@' || b.numberOfArguments!=3 || b.methodReturnType[0]!='@' || [b getArgumentTypeAtIndex:2][0]!='^')return;
    if(c.numberOfArguments!=5 || strcmp(c.methodReturnType,"v") || [c getArgumentTypeAtIndex:2][0]!='{' || [c getArgumentTypeAtIndex:3][0]!='@' || strcmp([c getArgumentTypeAtIndex:4],"f"))return;
    NSUInteger bytes=0;NSGetSizeAndAlignment([c getArgumentTypeAtIndex:2],&bytes,NULL);if(bytes!=sizeof(PRNativeCurve))return;
    Ivar data=class_getInstanceVariable(plot,"_points"),length=class_getInstanceVariable(plot,"_plotCount");
    if(!data || !length || ivar_getOffset(data)!=0x308 || ivar_getOffset(length)!=0x310)return;
    NSMethodSignature *p=[plot instanceMethodSignatureForSelector:NSSelectorFromString(@"points")],*n=[plot instanceMethodSignatureForSelector:NSSelectorFromString(@"plotCount")];
    if(!p || p.numberOfArguments!=2 || p.methodReturnType[0]!='^' || !n || n.numberOfArguments!=2 || strcmp(n.methodReturnType,@encode(NSUInteger)))return;
    originalPaintBegan=(void *)method_setImplementation(begin,(IMP)paintBegan);
    Method restart=class_getInstanceMethod(engine,NSSelectorFromString(@"paintRestart:options:"));
    if(restart){NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(restart)];if(s.numberOfArguments==4 && !strcmp(s.methodReturnType,"v") && [s getArgumentTypeAtIndex:2][0]=='@' && [s getArgumentTypeAtIndex:3][0]=='@')originalPaintRestart=(void *)method_setImplementation(restart,(IMP)paintRestart);}
    originalCopyStrokeOptions=(void *)method_setImplementation(copy,(IMP)copyStrokeOptions);
    Method secondary=class_getInstanceMethod(options,NSSelectorFromString(@"secondaryOptions"));
    if(secondary){NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(secondary)];if(s.numberOfArguments==2 && s.methodReturnType[0]=='@')originalSecondaryOptions=(void *)method_setImplementation(secondary,(IMP)secondaryStrokeOptions);}
    originalPlotCurve=(void *)method_setImplementation(draw,(IMP)plotCurve);nativePlotHookReady=YES;
}
// Fixed subdivision preserves contiguous, repeatable IDs in overlapping native batches.
enum { PRCurveSteps=16 };
static id projectNativePoints(id receiver,id points) {
    PRLayer *layer=activeLayer;
    if(!NSThread.isMainThread || !layer.guideVisible || !layer.snap || !layer.window || ![points isKindOfClass:NSArray.class] || ![points count])return points;
    id engine=nativeObject(receiver,@"valkyrieController");
    id expected=nativeObject(nativeObject(layer.documentController,@"modelController"),@"valkyrieController");
    if(!engine || engine!=expected)return points;
    id renderView=nativeObject(engine,@"valkyrieView");
    if(![renderView isKindOfClass:UIView.class])return points;
    // The shipped conversion methods use valkyrieView.superview coordinates.
    UIView *source=((UIView *)renderView).superview;
    if(!source || source.window!=layer.window)return points;
    SEL toView=NSSelectorFromString(@"viewPointFromValkyriePoint:"),toDocument=NSSelectorFromString(@"valkyriePointFromViewPoint:");
    if(!pointConverter(engine,toView) || !pointConverter(engine,toDocument))return points;
    Class pointClass=NSClassFromString(@"ValkyrieStrokeSegmentPoint");
    if(!pointClass)return points;
    NSMethodSignature *get=[pointClass instanceMethodSignatureForSelector:@selector(location)];
    NSMethodSignature *set=[pointClass instanceMethodSignatureForSelector:@selector(setLocation:)];
    if(!get || get.numberOfArguments!=2 || strcmp(get.methodReturnType,@encode(CGPoint)) || !set || set.numberOfArguments!=3 || strcmp(set.methodReturnType,"v") || strcmp([set getArgumentTypeAtIndex:2],@encode(CGPoint)))return points;
    CGPoint (*viewPoint)(id,SEL,CGPoint)=(void *)[engine methodForSelector:toView];
    CGPoint (*documentPoint)(id,SEL,CGPoint)=(void *)[engine methodForSelector:toDocument];
    CGPoint (*location)(id,SEL)=(void *)[pointClass instanceMethodForSelector:@selector(location)];
    void (*setLocation)(id,SEL,CGPoint)=(void *)[pointClass instanceMethodForSelector:@selector(setLocation:)];
    SEL indexSelector=NSSelectorFromString(@"index"),setIndexSelector=NSSelectorFromString(@"setIndex:");
    unsigned int (*indexOf)(id,SEL)=NULL;void (*setIndex)(id,SEL,unsigned int)=NULL;
    PRGuide guide=layer.guide;
    if(guide.kind==PRFlexible){
        NSMethodSignature *a=[pointClass instanceMethodSignatureForSelector:indexSelector],*b=[pointClass instanceMethodSignatureForSelector:setIndexSelector];
        if(!a || a.numberOfArguments!=2 || strcmp(a.methodReturnType,@encode(unsigned int)) || !b || b.numberOfArguments!=3 || strcmp(b.methodReturnType,"v") || strcmp([b getArgumentTypeAtIndex:2],@encode(unsigned int)))return points;
        indexOf=(void *)[pointClass instanceMethodForSelector:indexSelector];setIndex=(void *)[pointClass instanceMethodForSelector:setIndexSelector];
        unsigned int previous=0;BOOL first=YES;
        for(id sample in points){
            if(![sample isKindOfClass:pointClass])return points;
            unsigned int index=indexOf(sample,indexSelector);
            if(index>UINT32_MAX/PRCurveSteps || (!first && index!=previous+1))return points;
            previous=index;first=NO;
        }
    }
    // Synthetic points interpolate brush dynamics; the original endpoint is copied intact.
    NSString *fields[] = {@"pressure",@"altitude",@"azimuth",@"timeInterval",@"size",@"opacity",@"absoluteRollAngle",@"relativeRollAngle"};
    SEL getters[8],setters[8];double (*read[8])(id,SEL);void (*write[8])(id,SEL,double);
    for(int i=0;i<8;i++){
        getters[i]=NSSelectorFromString(fields[i]);NSString *name=fields[i];
        setters[i]=NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",[[name substringToIndex:1] uppercaseString],[name substringFromIndex:1]]);
        NSMethodSignature *a=[pointClass instanceMethodSignatureForSelector:getters[i]],*b=[pointClass instanceMethodSignatureForSelector:setters[i]];
        BOOL valid=a && a.numberOfArguments==2 && !strcmp(a.methodReturnType,"d") && b && b.numberOfArguments==3 && !strcmp(b.methodReturnType,"v") && !strcmp([b getArgumentTypeAtIndex:2],"d");
        read[i]=valid?(void *)[pointClass instanceMethodForSelector:getters[i]]:NULL;write[i]=valid?(void *)[pointClass instanceMethodForSelector:setters[i]]:NULL;
    }
    NSMutableArray *projected=[NSMutableArray arrayWithCapacity:[points count]];
    NSUInteger changed=0;id previousSample=nil;double previousT=0;
    for(id sample in points){
        if(![sample isKindOfClass:pointClass]){[projected addObject:sample];continue;}
        CGPoint point=viewPoint(engine,toView,location(sample,@selector(location)));
        point=[source convertPoint:point toView:layer];
        if(!isfinite(point.x) || !isfinite(point.y))return points;
        double t=guide.kind==PRFlexible?pr_curve_parameter((PRPoint){point.x,point.y},guide):0;
        int steps=guide.kind==PRFlexible && previousSample?PRCurveSteps:1;
        double before[8]={0},after[8]={0};
        if(steps>1)for(int i=0;i<8;i++)if(read[i]){before[i]=read[i](previousSample,getters[i]);after[i]=read[i](sample,getters[i]);}
        for(int j=1;j<=steps;j++){
            double f=j/(double)steps;
            PRPoint constrained=guide.kind==PRFlexible?pr_world(pr_curve(previousSample?previousT+(t-previousT)*f:t,guide),guide):pr_project((PRPoint){point.x,point.y},guide);
            CGPoint value=[layer convertPoint:CGPointMake(constrained.x,constrained.y) toView:source];value=documentPoint(engine,toDocument,value);
            if(!isfinite(value.x) || !isfinite(value.y))return points;
            id copy=[sample copy];setLocation(copy,@selector(setLocation:),value);
            if(guide.kind==PRFlexible){
                unsigned int index=indexOf(sample,indexSelector)*PRCurveSteps;
                setIndex(copy,setIndexSelector,index-(steps-j));
                if(j<steps)for(int i=0;i<8;i++)if(write[i])write[i](copy,setters[i],before[i]+(after[i]-before[i])*f);
            }
            [projected addObject:copy];
        }
        previousSample=sample;previousT=t;changed++;
    }
    layer.nativeSamples+=changed;return projected;
}
static id constrainedPoints(id receiver,SEL selector,id points,CGPoint initial) {
    return projectNativePoints(receiver,originalConstrainedPoints(receiver,selector,points,initial));
}
static void installNativeInputHook(void) {
    installNativePlotHook();
    if(nativeHookReady)return;
    Class target=NSClassFromString(@"DocumentValkyrieViewController");SEL selector=NSSelectorFromString(@"constrainedControlPoints:initialLocationInView:");
    Method method=class_getInstanceMethod(target,selector);if(!method)return;
    NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if(s.numberOfArguments!=4 || s.methodReturnType[0]!='@' || [s getArgumentTypeAtIndex:2][0]!='@' || strcmp([s getArgumentTypeAtIndex:3],@encode(CGPoint)))return;
    originalConstrainedPoints=(void *)method_setImplementation(method,(IMP)constrainedPoints);nativeHookReady=YES;
}

@implementation PRLayer
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    b.accessibilityLabel=title; return b;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if(!(self=[super initWithFrame:frame]))return nil;
    self.backgroundColor=UIColor.clearColor;self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _guide=pr_default_guide((PRPoint){frame.size.width/2,frame.size.height/2});
    UIImageSymbolConfiguration *symbols=[UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightRegular];
    _rulerButton=[self button:@"" action:@selector(toggleRuler:)];
    [_rulerButton setImage:[UIImage systemImageNamed:@"ruler" withConfiguration:symbols] forState:UIControlStateNormal];
    _rulerButton.accessibilityLabel=@"Righello";_rulerButton.accessibilityIdentifier=@"procreate-rulers-ruler";
    _rulerButton.tintColor=[UIColor colorWithWhite:.76 alpha:1];[self addSubview:_rulerButton];
    _symmetryButton=[self button:@"" action:@selector(openSymmetry:)];
    [_symmetryButton setImage:[UIImage systemImageNamed:@"square.split.2x1" withConfiguration:symbols] forState:UIControlStateNormal];
    _symmetryButton.accessibilityLabel=@"Simmetria";_symmetryButton.accessibilityIdentifier=@"procreate-rulers-symmetry";
    _symmetryButton.tintColor=[UIColor colorWithWhite:.76 alpha:1];[self addSubview:_symmetryButton];
    _panel=[UIView new];_panel.backgroundColor=[UIColor colorWithWhite:.09 alpha:.95];_panel.layer.cornerRadius=12;
    _panel.frame=CGRectMake(12,65,330,100);_panel.hidden=YES;[self addSubview:_panel];
    UIStackView *stack=[[UIStackView alloc]initWithFrame:CGRectMake(10,7,310,86)];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=4;[_panel addSubview:stack];
    UISegmentedControl *kinds=[[UISegmentedControl alloc]initWithItems:@[@"Dritto",@"Flessibile"]];
    kinds.accessibilityIdentifier=@"procreate-rulers-kind";kinds.selectedSegmentIndex=0;kinds.backgroundColor=UIColor.systemGrayColor;[kinds addTarget:self action:@selector(kind:) forControlEvents:UIControlEventValueChanged];[stack addArrangedSubview:kinds];
    UIStackView *row=[UIStackView new];row.distribution=UIStackViewDistributionFillEqually;
    [row addArrangedSubview:[self button:@"Ripristina" action:@selector(resetRuler)]];
    [row addArrangedSubview:[self button:@"Adatta" action:@selector(fitRuler)]];
    _lockButton=[self button:@"Blocca" action:@selector(toggleLock:)];[row addArrangedSubview:_lockButton];[stack addArrangedSubview:row];
    _status=[UILabel new];_status.font=[UIFont systemFontOfSize:11];_status.textColor=UIColor.whiteColor;_status.numberOfLines=1;[stack addArrangedSubview:_status];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(move:)];pan.allowedTouchTypes=@[@(UITouchTypeDirect),@(UITouchTypePencil)];pan.maximumNumberOfTouches=1;pan.delegate=self;[self addGestureRecognizer:pan];
    UIRotationGestureRecognizer *rotate=[[UIRotationGestureRecognizer alloc]initWithTarget:self action:@selector(rotateRuler:)];rotate.delegate=self;rotate.allowedTouchTypes=@[@(UITouchTypeDirect)];[self addGestureRecognizer:rotate];
    UIPinchGestureRecognizer *pinch=[[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(scaleRuler:)];pinch.delegate=self;pinch.allowedTouchTypes=@[@(UITouchTypeDirect)];[self addGestureRecognizer:pinch];
    UITapGestureRecognizer *reset=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTapRuler:)];reset.numberOfTapsRequired=2;reset.allowedTouchTypes=@[@(UITouchTypeDirect)];reset.delegate=self;[self addGestureRecognizer:reset];
    _symmetryPanel=[[UIView alloc]initWithFrame:CGRectMake(12,65,390,150)];_symmetryPanel.backgroundColor=_panel.backgroundColor;_symmetryPanel.layer.cornerRadius=12;_symmetryPanel.hidden=YES;[self addSubview:_symmetryPanel];
    UIStackView *symStack=[[UIStackView alloc]initWithFrame:CGRectMake(12,10,366,130)];symStack.axis=UILayoutConstraintAxisVertical;symStack.spacing=10;[_symmetryPanel addSubview:symStack];
    _symmetryModes=[[UISegmentedControl alloc]initWithItems:@[@"Verticale",@"Orizzontale",@"Entrambi",@"Radiale"]];_symmetryModes.backgroundColor=UIColor.systemGrayColor;_symmetryModes.selectedSegmentIndex=0;_symmetryModes.accessibilityIdentifier=@"procreate-rulers-symmetry-modes";[_symmetryModes addTarget:self action:@selector(symmetryModeChanged:) forControlEvents:UIControlEventValueChanged];[symStack addArrangedSubview:_symmetryModes];
    UIStackView *symActions=[UIStackView new];symActions.distribution=UIStackViewDistributionFillEqually;
    [symActions addArrangedSubview:[self button:@"Modifica assi" action:@selector(editSymmetry:)]];
    UIButton *off=[self button:@"Disattiva" action:@selector(disableSymmetry:)];off.accessibilityIdentifier=@"procreate-rulers-symmetry-off";[symActions addArrangedSubview:off];[symStack addArrangedSubview:symActions];
    _symmetryStatus=[UILabel new];_symmetryStatus.numberOfLines=2;_symmetryStatus.font=[UIFont systemFontOfSize:12];_symmetryStatus.textColor=UIColor.whiteColor;[symStack addArrangedSubview:_symmetryStatus];
    return self;
}
- (void)layoutSubviews {[super layoutSubviews];[self refreshPlacement];}
- (void)refreshPlacement {
    UIViewController *document=findDocument(self.window.rootViewController);
    if(_documentController!=document){_canvas=nil;_snap=NO;_selecting=NO;_transformButton=nil;_documentController=document;}
    if(!_transformButton.window)_transformButton=findTransform(self.window,self);
    // Prefer the real native control, including compact toolbar variants.
    if(!_transformButton && document){
        id toolbar=nativeObject(document,@"toolbarController");
        id candidate=nativeObject(toolbar,@"transformButton");
        if(![candidate isKindOfClass:UIView.class] || !((UIView *)candidate).window)candidate=nativeObject(toolbar,@"transformButtonCompact");
        if([candidate isKindOfClass:UIView.class] && ((UIView *)candidate).window)_transformButton=candidate;
    }
    BOOL visible=document && !document.presentedViewController && _transformButton.window && !_transformButton.hidden && _transformButton.alpha>.01;
    _rulerButton.hidden=!visible;_symmetryButton.hidden=!visible;
    if(!visible){_snap=NO;_selecting=NO;_panel.hidden=YES;_symmetryPanel.hidden=YES;_guideVisible=NO;[self setNeedsDisplay];return;}
    CGRect anchor=[_transformButton convertRect:_transformButton.bounds toView:self];
    CGFloat side=44, x=CGRectGetMaxX(anchor)+2;
    CGFloat y=CGRectGetMidY(anchor)-side/2;
    // Never overlay the existing right-hand brush/color controls in a narrow window.
    if(x+2*side>self.bounds.size.width*.60){_rulerButton.hidden=YES;_symmetryButton.hidden=YES;_snap=NO;_guideVisible=NO;_panel.hidden=YES;_symmetryPanel.hidden=YES;return;}
    _rulerButton.frame=CGRectMake(x,y,side,side);_symmetryButton.frame=CGRectMake(x+side,y,side,side);
    CGRect panel=_panel.frame;panel.origin=CGPointMake(fmin(x,self.bounds.size.width-panel.size.width-12),CGRectGetMaxY(_rulerButton.frame)+8);_panel.frame=panel;CGRect sym=_symmetryPanel.frame;sym.origin=CGPointMake(fmin(x,self.bounds.size.width-sym.size.width-12),panel.origin.y);_symmetryPanel.frame=sym;
}
- (void)toggleRuler:(id)sender {
    _symmetryPanel.hidden=YES;_guideVisible=!_guideVisible;_panel.hidden=!_guideVisible;
    _rulerButton.tintColor=_guideVisible?UIColor.systemBlueColor:[UIColor colorWithWhite:.76 alpha:1];
    if(!_guideVisible){_snap=NO;_selecting=NO;}
    if(_guideVisible){
        id engine=nativeObject(nativeObject(_documentController,@"modelController"),@"valkyrieController");
        id render=nativeObject(engine,@"valkyrieView");
        _canvas=[render isKindOfClass:UIView.class]?((UIView *)render).superview:nil;
        _snap=nativeHookReady && nativePlotHookReady && _canvas.window && _canvas.window==self.window;_selecting=NO;_nativeSamples=0;[self updateRulerStatus];
    }
    [self setNeedsDisplay];
}
- (BOOL)activateSymmetryType:(NSInteger)mode finish:(BOOL)finish {
    id model=nativeObject(_documentController,@"modelController");
    id engine=nativeObject(model,@"valkyrieController");
    if(!nativeBool(engine,@"drawingGuideEnabled:",YES) || !nativeVoid(model,@"beginDrawingGuideMode")){[self showNativeError];return NO;}
    id controller=nativeObject(model,@"drawingGuideController");
    if(![controller respondsToSelector:NSSelectorFromString(@"finishCheckpoint")] || !nativeInteger(controller,@"beginGuideTypeChangedCheckpoint:",3)){[self showNativeError];return NO;}
    BOOL changed=nativeInteger(engine,@"drawingGuideTypeChanged:",3) && nativeInteger(engine,@"drawingGuideSymmetryTypeChanged:",mode);
    nativeVoid(controller,@"finishCheckpoint");
    if(changed && finish)changed=nativeBool(controller,@"setAssistedValueForFinish:",YES) && nativeVoid(model,@"finishDrawingGuideMode");
    nativeVoid(model,@"updateInterface");
    if(!changed)[self showNativeError];return changed;
}
- (void)openSymmetry:(id)sender {
    _panel.hidden=YES;_symmetryPanel.hidden=!_symmetryPanel.hidden;
    if(!_symmetryPanel.hidden)[self symmetryModeChanged:_symmetryModes];
}
- (void)symmetryModeChanged:(UISegmentedControl *)control {
    if([self activateSymmetryType:control.selectedSegmentIndex finish:YES])
        _symmetryStatus.text=control.selectedSegmentIndex==3 ? @"Radiale: 8 settori. Assistenza attiva sul livello." : @"Assistenza attiva sul livello. Modifica assi per spostarli o ruotarli.";
}
- (void)editSymmetry:(id)sender {
    _symmetryPanel.hidden=YES;_panel.hidden=YES;_guideVisible=NO;_snap=NO;_selecting=NO;[self setNeedsDisplay];
    [self activateSymmetryType:_symmetryModes.selectedSegmentIndex finish:NO];
}
- (void)disableSymmetry:(id)sender {
    id model=nativeObject(_documentController,@"modelController");id engine=nativeObject(model,@"valkyrieController");
    if(!nativeBool(engine,@"drawingGuideEnabled:",NO)){[self showNativeError];return;}
    nativeBool(nativeObject(nativeObject(model,@"document"),@"editingLayer"),@"setDrawingGuideAssisted:",NO);
    nativeVoid(model,@"updateInterface");_symmetryPanel.hidden=YES;
}
- (void)showNativeError {
    UIViewController *presenter=_documentController ?: self.window.rootViewController;
    while(presenter.presentedViewController)presenter=presenter.presentedViewController;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Simmetria" message:@"Il collegamento alle guide native non è disponibile. Apri Azioni > Tela > Guida disegno > Modifica guida disegno e scegli Simmetria." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    if(self.hidden)return nil;
    UIView *hit=[super hitTest:p withEvent:event];
    if(hit!=self)return hit;
    if(_selecting)return self;
    // The guide must never steal Undo, brush sliders or other native controls.
    UIView *documentView=_documentController.view;
    UIView *under=[documentView hitTest:[self convertPoint:p toView:documentView] withEvent:event];
    for(UIView *view=under;view;view=view.superview)if([view isKindOfClass:UIControl.class])return nil;
    NSInteger handle=[self handleAtPoint:p];
    UITouch *nearest=nil;CGFloat distance=CGFLOAT_MAX;
    for(UITouch *touch in event.allTouches){
        if(touch.phase==UITouchPhaseEnded || touch.phase==UITouchPhaseCancelled)continue;
        CGPoint q=[touch locationInView:self];CGFloat d=hypot(q.x-p.x,q.y-p.y);
        if(d<distance){nearest=touch;distance=d;}
    }
    BOOL pencil=nearest.type==UITouchTypePencil;
    if(_guideVisible && !_rulerLocked && handle>=0 && (!pencil || handle<3))return self;
    return nil;
}
- (void)updateRulerStatus {
    if(!nativeHookReady || !nativePlotHookReady || !_snap){_status.text=@"Collegamento al disegno non disponibile";return;}
    _status.text=@"Tratto vincolato · sposta i cerchi per regolare";
}
- (void)kind:(UISegmentedControl *)s {_guide.kind=s.selectedSegmentIndex==0?PRLine:PRFlexible;[self updateRulerStatus];[self setNeedsDisplay];}
- (NSInteger)handleAtPoint:(CGPoint)point {
    PRPoint p={point.x,point.y};NSInteger best=-1;double distance=22*22;
    for(int i=0;i<3;i++) {
        if(_guide.kind==PRLine && i==1)continue;
        double d=pr_distance2(p,pr_handle(i,_guide));
        if(d<distance){distance=d;best=i;}
    }
    if(best<0 && pr_distance2(p,pr_project(p,_guide))<24*24)return 4;
    return best;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    NSInteger handle=[self handleAtPoint:[touch locationInView:self]];
    return _guideVisible && !_rulerLocked && !_selecting && touch.view==self && handle>=0 && (touch.type==UITouchTypeDirect || (touch.type==UITouchTypePencil && handle<3));
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    return ([a isKindOfClass:UIRotationGestureRecognizer.class] && [b isKindOfClass:UIPinchGestureRecognizer.class]) || ([b isKindOfClass:UIRotationGestureRecognizer.class] && [a isKindOfClass:UIPinchGestureRecognizer.class]);
}
- (void)toggleLock:(id)sender {_rulerLocked=!_rulerLocked;[_lockButton setTitle:_rulerLocked?@"Sblocca":@"Blocca" forState:0];}
- (void)rotateRuler:(UIRotationGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan)_rotationStart=_guide.angle;
    _guide.angle=pr_snap_angle(_rotationStart+gesture.rotation);[self setNeedsDisplay];
}
- (void)scaleRuler:(UIPinchGestureRecognizer *)gesture {_guide.radius=fmax(1,fmin(500,_guide.radius*gesture.scale));gesture.scale=1;[self setNeedsDisplay];}
- (void)resetRuler {PRKind kind=_guide.kind;_guide=pr_default_guide((PRPoint){self.bounds.size.width/2,self.bounds.size.height*.6});_guide.kind=kind;[self setNeedsDisplay];}
- (void)fitRuler {_guide=pr_fit_guide(_guide,self.bounds.size.width,self.bounds.size.height);[self setNeedsDisplay];}
- (void)doubleTapRuler:(UITapGestureRecognizer *)gesture {
    NSInteger handle=[self handleAtPoint:[gesture locationInView:self]];
    if(_guide.kind==PRFlexible && handle>=0 && handle<3)[self fitRuler];else [self resetRuler];
}
- (void)moveHandleAtIndex:(NSInteger)index toPoint:(CGPoint)p {
    pr_move_handle(&_guide,(int)index,(PRPoint){p.x,p.y});[self setNeedsDisplay];
}
- (void)move:(UIPanGestureRecognizer *)g {
    if(g.state==UIGestureRecognizerStateBegan){
        CGPoint p=[g locationInView:self],delta=[g translationInView:self];
        _dragIndex=[self handleAtPoint:CGPointMake(p.x-delta.x,p.y-delta.y)];
        if(_dragIndex>=0)_dragStart=pr_handle((int)_dragIndex,_guide);
    }
    if((g.state==UIGestureRecognizerStateBegan || g.state==UIGestureRecognizerStateChanged) && _dragIndex>=0){
        CGPoint delta=[g translationInView:self];[self moveHandleAtIndex:_dragIndex toPoint:CGPointMake(_dragStart.x+delta.x,_dragStart.y+delta.y)];
    }
}
- (void)drawRect:(CGRect)rect {
    if(!_guideVisible)return;
    CGContextRef c=UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);CGContextTranslateCTM(c,_guide.center.x,_guide.center.y);CGContextRotateCTM(c,_guide.angle);
    double r=_guide.radius,len=hypot(self.bounds.size.width,self.bounds.size.height);
    CGMutablePathRef path=CGPathCreateMutable();
    if(_guide.kind==PRFlexible){PRPoint *p=_guide.points,control=pr_curve_control(_guide);CGPathMoveToPoint(path,NULL,p[0].x*r,p[0].y*r);CGPathAddQuadCurveToPoint(path,NULL,control.x*r,control.y*r,p[2].x*r,p[2].y*r);}
    else {CGPathMoveToPoint(path,NULL,-len,0);CGPathAddLineToPoint(path,NULL,len,0);}
    CGContextSetLineCap(c,kCGLineCapRound);CGContextSetStrokeColorWithColor(c,[UIColor colorWithWhite:.45 alpha:.10].CGColor);CGContextSetLineWidth(c,30);CGContextAddPath(c,path);CGContextStrokePath(c);
    CGContextSetStrokeColorWithColor(c,[UIColor colorWithWhite:.35 alpha:.55].CGColor);CGContextSetLineWidth(c,.8);CGContextAddPath(c,path);CGContextStrokePath(c);
    if(_guide.kind==PRLine){for(int i=-40;i<=40;i++){double x=i*10;CGContextMoveToPoint(c,x,0);CGContextAddLineToPoint(c,x,i%5==0?9:4);}CGContextStrokePath(c);}
    CGPathRelease(path);CGContextRestoreGState(c);
    for(int i=0;i<3;i++){
        if(_guide.kind==PRLine && i==1)continue;PRPoint p=pr_handle(i,_guide);
        CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:1 alpha:.75].CGColor);CGContextFillEllipseInRect(c,CGRectMake(p.x-7,p.y-7,14,14));
        CGContextSetLineWidth(c,1);CGContextSetStrokeColorWithColor(c,[UIColor colorWithWhite:.35 alpha:.7].CGColor);CGContextStrokeEllipseInRect(c,CGRectMake(p.x-7,p.y-7,14,14));
    }
}

@end

static void installLayer(void) {
    installNativeInputHook();
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    NSMutableOrderedSet<UIWindow *> *windows=[NSMutableOrderedSet orderedSet];
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if(![scene isKindOfClass:UIWindowScene.class])continue;
        [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
    }
    // Legacy apps can have no connected UIWindowScene at all.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [windows addObjectsFromArray:UIApplication.sharedApplication.windows];
#pragma clang diagnostic pop
    for(UIWindow *window in windows) {
        if(window.hidden || window.windowLevel!=UIWindowLevelNormal || !window.rootViewController || !findDocument(window.rootViewController))continue;
        if(activeLayer.window==window){
            if(window.subviews.lastObject!=activeLayer)[window bringSubviewToFront:activeLayer];
            [activeLayer refreshPlacement];if(activeLayer.guideVisible)[activeLayer updateRulerStatus];return;
        }
        [activeLayer removeFromSuperview];PRLayer *layer=[[PRLayer alloc]initWithFrame:window.bounds];[window addSubview:layer];activeLayer=layer;[layer refreshPlacement];return;
    }
    if(activeLayer){activeLayer.snap=NO;activeLayer.selecting=NO;activeLayer.hidden=YES;}
}
__attribute__((constructor)) static void startRulers(void) {
    @autoreleasepool {
        // Sideloadly can change CFBundleIdentifier. Match the executable instead.
        if(![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"] isEqualToString:@"Procreate"])return;
        installNativeInputHook();
        dispatch_async(dispatch_get_main_queue(),^{
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){installLayer();}];
            installLayer();
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer){
                activeLayer.hidden=NO;installLayer();
            }];
        });
    }
}
