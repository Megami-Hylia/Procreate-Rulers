// UIKit integration harness. Native Procreate objects are explicit test doubles.
// This verifies our UI/lifecycle, NOT compatibility with the real Procreate engine.
#import <UIKit/UIKit.h>
#import "../src/Geometry.h"
#import "../src/NativePlot.h"
#include <string.h>
@protocol PRTestLayerAccess
- (PRGuide)guide;
- (void)moveHandleAtIndex:(NSInteger)index toPoint:(CGPoint)point;
@end
@interface ValkyrieStrokeSegmentPoint : NSObject <NSCopying>
@property(nonatomic) unsigned int index;
@property(nonatomic) CGPoint location;
@property(nonatomic) double pressure,altitude,azimuth,timeInterval;
@property(nonatomic) double size,opacity,absoluteRollAngle,relativeRollAngle;
@property(nonatomic) BOOL predicted;
@end
@implementation ValkyrieStrokeSegmentPoint
- (id)copyWithZone:(NSZone *)zone {
    ValkyrieStrokeSegmentPoint *p=[ValkyrieStrokeSegmentPoint new];p.index=_index;p.location=_location;p.pressure=_pressure;p.altitude=_altitude;p.azimuth=_azimuth;p.timeInterval=_timeInterval;p.predicted=_predicted;p.size=_size;p.opacity=_opacity;p.absoluteRollAngle=_absoluteRollAngle;p.relativeRollAngle=_relativeRollAngle;return p;
}
@end
@interface PRTestTouch : UITouch
@property(nonatomic) CGPoint testLocation;
@property(nonatomic) UITouchType testType;
@end
@implementation PRTestTouch
- (CGPoint)locationInView:(UIView *)view {return _testLocation;}
- (UITouchType)type {return _testType;}
- (UITouchPhase)phase {return UITouchPhaseBegan;}
@end
@interface PRTestEvent : UIEvent
@property(nonatomic,strong) NSSet *testTouches;
@end
@implementation PRTestEvent
- (NSSet *)allTouches {return _testTouches;}
@end
@interface ValkyrieDrawingGuide : NSObject
@property(nonatomic) NSUInteger type;
@property(nonatomic) NSInteger symmetryType;
@property(nonatomic) BOOL updated;
- (void)updateSegments;
@end
@implementation ValkyrieDrawingGuide
- (void)updateSegments {_updated=YES;}
@end
@interface PRTestEditingLayer : NSObject
@property(nonatomic) BOOL drawingGuideAssisted;
@end
@implementation PRTestEditingLayer
@end
@interface PRTestDocument : NSObject
@property(nonatomic,strong) ValkyrieDrawingGuide *drawingGuide;
@property(nonatomic,strong) PRTestEditingLayer *editingLayer;
@end
@implementation PRTestDocument
@end
@interface ValkyrieStrokeOptions : NSObject <NSCopying>
@property(nonatomic) NSInteger marker;
- (id)secondaryOptions;
@end
@implementation ValkyrieStrokeOptions
- (id)copyWithZone:(NSZone *)zone {ValkyrieStrokeOptions *copy=[ValkyrieStrokeOptions new];copy.marker=_marker;return copy;}
- (id)secondaryOptions {return _marker==-1?nil:[self copy];}
@end
typedef struct {float values[14][4];} PRTestNativeCurve;
// Explicit native layout fixture, checked by the same runtime guards as production.
@interface ValkyrieStrokePlot : NSObject {
@public
    uint8_t _padding[0x300];
    PRNativeDab *_points;
    NSUInteger _plotCount;
}
@property(nonatomic,strong) ValkyrieStrokeOptions *options;
@property(nonatomic,strong) NSArray<NSValue *> *fixtureOrigins;
@property(nonatomic,strong) NSMutableData *storage;
@property(nonatomic,strong) NSData *originalBytes;
@property(nonatomic) NSUInteger originalCalls;
- (PRNativeDab *)points;
- (NSUInteger)plotCount;
- (void)plotCurve:(PRTestNativeCurve)curve previousPlot:(id)previous initialAngle:(float)angle;
@end
@implementation ValkyrieStrokePlot
- (PRNativeDab *)points {return _points;}
- (NSUInteger)plotCount {return _plotCount;}
- (void)plotCurve:(PRTestNativeCurve)curve previousPlot:(id)previous initialAngle:(float)angle {
    _originalCalls++;_plotCount=_fixtureOrigins.count;_storage=[NSMutableData dataWithLength:_plotCount*sizeof(PRNativeDab)];_points=_storage.mutableBytes;
    memset(_points,0x6d,_storage.length);
    for(NSUInteger i=0;i<_plotCount;i++){
        CGPoint p=_fixtureOrigins[i].CGPointValue;_points[i].origin[0]=p.x;_points[i].origin[1]=p.y;
        _points[i].variance[0]=7;_points[i].variance[1]=13;
    }
    _originalBytes=[_storage copy];
}
@end
@interface DocumentValkyrieController : NSObject
@property(nonatomic,strong) PRTestDocument *document;
@property(nonatomic) BOOL enabled;
@property(nonatomic,strong) UIView *valkyrieView;
@property(nonatomic) CGAffineTransform documentToView;
@property(nonatomic,strong) ValkyrieStrokeOptions *valkyrieStrokeOptions;
- (BOOL)paintBegan:(NSArray *)points options:(ValkyrieStrokeOptions *)options;
- (void)paintRestart:(NSArray *)points options:(ValkyrieStrokeOptions *)options;
- (CGPoint)viewPointFromValkyriePoint:(CGPoint)point;
- (CGPoint)valkyriePointFromViewPoint:(CGPoint)point;
- (void)drawingGuideEnabled:(BOOL)enabled;
- (void)drawingGuideTypeChanged:(NSInteger)type;
- (void)drawingGuideSymmetryTypeChanged:(NSInteger)type;
@end
@implementation DocumentValkyrieController
- (BOOL)paintBegan:(NSArray *)points options:(ValkyrieStrokeOptions *)options {_valkyrieStrokeOptions=options;return YES;}
- (void)paintRestart:(NSArray *)points options:(ValkyrieStrokeOptions *)options {_valkyrieStrokeOptions=options;}
- (CGPoint)viewPointFromValkyriePoint:(CGPoint)p {return CGPointApplyAffineTransform(p,_documentToView);}
- (CGPoint)valkyriePointFromViewPoint:(CGPoint)p {return CGPointApplyAffineTransform(p,CGAffineTransformInvert(_documentToView));}
- (void)drawingGuideEnabled:(BOOL)enabled {_enabled=enabled;if(!_document.drawingGuide)_document.drawingGuide=[ValkyrieDrawingGuide new];}
- (void)drawingGuideTypeChanged:(NSInteger)type {_document.drawingGuide.type=type;[_document.drawingGuide updateSegments];}
- (void)drawingGuideSymmetryTypeChanged:(NSInteger)type {_document.drawingGuide.symmetryType=type;}
@end
// Exact native entry-point ABI; its original implementation deliberately does no snapping.
@interface DocumentValkyrieViewController : NSObject
@property(nonatomic,strong) DocumentValkyrieController *valkyrieController;
@property(nonatomic) NSUInteger originalCalls;
- (NSArray *)constrainedControlPoints:(NSArray *)points initialLocationInView:(CGPoint)initial;
@end
@implementation DocumentValkyrieViewController
- (NSArray *)constrainedControlPoints:(NSArray *)points initialLocationInView:(CGPoint)initial {_originalCalls++;return points;}
@end
@interface PRTestCheckpoint : NSObject
@property(nonatomic) NSInteger startedType;
@property(nonatomic) BOOL finished;
@property(nonatomic) BOOL assistedValueForFinish;
- (void)beginGuideTypeChangedCheckpoint:(NSInteger)type;
- (void)finishCheckpoint;
@end
@implementation PRTestCheckpoint
- (void)beginGuideTypeChangedCheckpoint:(NSInteger)type {_startedType=type;}
- (void)finishCheckpoint {_finished=YES;}
@end
@interface PRTestModel : NSObject
@property(nonatomic,strong) PRTestDocument *document;
@property(nonatomic,strong) PRTestCheckpoint *drawingGuideController;
@property(nonatomic,strong) DocumentValkyrieController *valkyrieController;
@property(nonatomic) BOOL began, refreshed;
@property(nonatomic,strong) UIView *canvasView;
- (void)beginDrawingGuideMode;
- (void)updateInterface;
- (void)finishDrawingGuideMode;
@end
@implementation PRTestModel
- (void)beginDrawingGuideMode {_began=YES;}
- (void)updateInterface {_refreshed=YES;}
- (void)finishDrawingGuideMode {_document.editingLayer.drawingGuideAssisted=_drawingGuideController.assistedValueForFinish;}
@end
@interface DocumentViewController : UIViewController
@property(nonatomic,strong) PRTestModel *modelController;
@end
@implementation DocumentViewController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=[UIColor colorWithWhite:.92 alpha:1];
    _modelController=[PRTestModel new];_modelController.document=[PRTestDocument new];_modelController.drawingGuideController=[PRTestCheckpoint new];
    _modelController.document.editingLayer=[PRTestEditingLayer new];
    _modelController.valkyrieController=[DocumentValkyrieController new];_modelController.valkyrieController.document=_modelController.document;
    _modelController.canvasView=[[UIView alloc]initWithFrame:CGRectMake(20,80,self.view.bounds.size.width-40,self.view.bounds.size.height-100)];
    _modelController.valkyrieController.documentToView=CGAffineTransformConcat(CGAffineTransformMakeScale(1.7,1.7),CGAffineTransformConcat(CGAffineTransformMakeRotation(.3),CGAffineTransformMakeTranslation(70,40)));
    _modelController.valkyrieController.valkyrieView=[[UIView alloc]initWithFrame:_modelController.canvasView.bounds];[_modelController.canvasView addSubview:_modelController.valkyrieController.valkyrieView];
    _modelController.canvasView.backgroundColor=UIColor.whiteColor;_modelController.canvasView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.view addSubview:_modelController.canvasView];
    UIView *bar=[[UIView alloc]initWithFrame:CGRectMake(0,24,self.view.bounds.size.width,48)];bar.backgroundColor=[UIColor colorWithWhite:.14 alpha:1];bar.autoresizingMask=UIViewAutoresizingFlexibleWidth;[self.view addSubview:bar];
    NSArray *titles=@[@"Gallery",@"Actions",@"Adjust",@"Select",@"Transform"];
    NSArray *symbols=@[@"",@"wrench",@"wand.and.stars",@"s.circle",@"arrow.up.right"];
    for(NSUInteger i=0;i<titles.count;i++) {
        UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.frame=CGRectMake(i?90+(i-1)*44:8,2,i?44:80,44);b.tintColor=UIColor.lightGrayColor;
        if(i)[b setImage:[UIImage systemImageNamed:symbols[i]] forState:0];else[b setTitle:titles[i] forState:0];
        if(i==4)b.accessibilityIdentifier=@"document-transform-button";[bar addSubview:b];
    }
    UILabel *label=[[UILabel alloc]initWithFrame:CGRectMake(40,330,750,90)];label.numberOfLines=0;label.text=@"Ambiente di prova UIKit\nLa barra e i controlli dell’estensione sono reali.\nL’editor Procreate è simulato per il test.";[self.view addSubview:label];
}
@end
static UIView *findIdentifier(UIView *view,NSString *identifier) {
    if([view.accessibilityIdentifier isEqualToString:identifier])return view;
    for(UIView *child in view.subviews){UIView *v=findIdentifier(child,identifier);if(v)return v;}return nil;
}
@interface PRTestDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation PRTestDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[DocumentViewController new];[self.window makeKeyAndVisible];
    __block NSInteger tries=0;
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){
        UIButton *ruler=(UIButton *)findIdentifier(self.window,@"procreate-rulers-ruler");
        UIButton *symmetry=(UIButton *)findIdentifier(self.window,@"procreate-rulers-symmetry");
        if((!ruler || ruler.hidden || !symmetry || symmetry.hidden) && ++tries<15)return;
        [timer invalidate];
        NSMutableArray *failures=[NSMutableArray array];
        if(!ruler || ruler.hidden || !symmetry || symmetry.hidden)[failures addObject:@"Toolbar buttons not visible after bundle ID change / legacy-window startup"];
        if(ruler && symmetry) {
            UIView *anchor=findIdentifier(self.window,@"document-transform-button");
            CGRect a=[anchor convertRect:anchor.bounds toView:self.window];CGRect r=[ruler convertRect:ruler.bounds toView:self.window];CGRect s=[symmetry convertRect:symmetry.bounds toView:self.window];
            if(CGRectGetMinX(r)<CGRectGetMaxX(a) || CGRectGetMinX(s)<CGRectGetMaxX(r) || fabs(CGRectGetMidY(a)-CGRectGetMidY(r))>1)[failures addObject:@"Buttons are not aligned after Transform"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            UIView *layer=ruler.superview;
            if(![[layer valueForKey:@"guideVisible"] boolValue] || [[layer valueForKey:@"panel"] isHidden])[failures addObject:@"Ruler does not open its panel"];
            UISegmentedControl *kinds=(UISegmentedControl *)findIdentifier(layer,@"procreate-rulers-kind");
            if(kinds.numberOfSegments!=2 || ![[kinds titleForSegmentAtIndex:0] isEqualToString:@"Dritto"] || ![[kinds titleForSegmentAtIndex:1] isEqualToString:@"Flessibile"])[failures addObject:@"Ruler choices are not Dritto/Flessibile"];
            UIView *canvas=((DocumentViewController *)self.window.rootViewController).modelController.canvasView;
            PRTestModel *boundModel=((DocumentViewController *)self.window.rootViewController).modelController;
            DocumentValkyrieController *engine=boundModel.valkyrieController;
            DocumentValkyrieViewController *input=[DocumentValkyrieViewController new];input.valkyrieController=engine;
            PRGuide guide=[(id<PRTestLayerAccess>)layer guide];
            NSMutableArray *rawBatch=[NSMutableArray array];
            for(int i=0;i<30;i++){
                ValkyrieStrokeSegmentPoint *point=[ValkyrieStrokeSegmentPoint new];
                CGPoint screen=CGPointMake(guide.center.x-160+i*10,guide.center.y+sin(i)*45+50);
                point.location=[engine valkyriePointFromViewPoint:[layer convertPoint:screen toView:canvas]];
                point.index=i;point.pressure=.2+i*.02;point.altitude=.8;point.azimuth=.4;point.timeInterval=i*.004;point.predicted=i>=25;[rawBatch addObject:point];
            }
            NSArray *nativeResult=[input constrainedControlPoints:rawBatch initialLocationInView:CGPointZero];
            if(input.originalCalls!=1 || nativeResult==rawBatch || nativeResult.count!=rawBatch.count)[failures addObject:@"Native runtime hook was not invoked around the original method"];
            for(NSUInteger i=0;i<nativeResult.count;i++){
                ValkyrieStrokeSegmentPoint *before=rawBatch[i],*after=nativeResult[i];
                CGPoint screen=[canvas convertPoint:[engine viewPointFromValkyriePoint:after.location] toView:layer];
                if(fabs(screen.y-guide.center.y)>.001){[failures addObject:@"Native committed/predicted samples escape the straight guide after pan/zoom/rotation"];break;}
                if(before==after || before.pressure!=after.pressure || before.altitude!=after.altitude || before.azimuth!=after.azimuth || before.timeInterval!=after.timeInterval || before.predicted!=after.predicted)[failures addObject:@"Projection mutated input samples or lost stylus attributes"];
            }
            kinds.selectedSegmentIndex=1;[kinds sendActionsForControlEvents:UIControlEventValueChanged];
            [(id<PRTestLayerAccess>)layer moveHandleAtIndex:1 toPoint:CGPointMake(guide.center.x+20,guide.center.y+150)];
            guide=[(id<PRTestLayerAccess>)layer guide];PRPoint middle=pr_world(pr_curve(.5,guide),guide);
            if(fabs(middle.x-guide.center.x-20)>.001 || fabs(middle.y-guide.center.y-150)>.001)[failures addObject:@"Middle handle is not on the flexible ruler's curve"];
            nativeResult=[input constrainedControlPoints:rawBatch initialLocationInView:CGPointZero];
            for(ValkyrieStrokeSegmentPoint *sample in nativeResult){
                CGPoint screen=[canvas convertPoint:[engine viewPointFromValkyriePoint:sample.location] toView:layer];double nearest=INFINITY;
                for(int j=0;j<=10000;j++)nearest=fmin(nearest,pr_distance2((PRPoint){screen.x,screen.y},pr_world(pr_curve(j/10000.,guide),guide)));
                if(nearest>.01){[failures addObject:@"Native samples escape the edited flexible guide"];break;}
            }
            // Regression from the device video: on-curve endpoints alone still draw a chord.
            NSMutableArray *sparse=[NSMutableArray array];
            for(int i=0;i<2;i++){
                ValkyrieStrokeSegmentPoint *p=[ValkyrieStrokeSegmentPoint new];PRPoint screen=pr_handle(i?2:0,guide);
                p.location=[engine valkyriePointFromViewPoint:[layer convertPoint:CGPointMake(screen.x,screen.y) toView:canvas]];
                p.index=i;p.timeInterval=i*.1;p.pressure=.2+i*.6;p.opacity=.6;p.size=8;p.predicted=i==1;[sparse addObject:p];
            }
            NSArray *sweep=[input constrainedControlPoints:sparse initialLocationInView:CGPointZero];
            if(sweep.count<17)[failures addObject:@"Sparse curve sweep has no intermediate arc samples"];
            for(NSUInteger i=0;i<sweep.count;i++){
                ValkyrieStrokeSegmentPoint *p=sweep[i];double f=i/(double)(sweep.count-1);
                if(p.index!=i || fabs(p.timeInterval-.1*f)>.000001 || fabs(p.pressure-(.2+.6*f))>.000001 || p.size!=8 || p.opacity!=.6)[failures addObject:@"Arc resampling lost contiguous indices, timing, pressure, size or opacity"];
                if(i){
                    ValkyrieStrokeSegmentPoint *prev=sweep[i-1];
                    CGPoint a=[canvas convertPoint:[engine viewPointFromValkyriePoint:prev.location] toView:layer],b=[canvas convertPoint:[engine viewPointFromValkyriePoint:p.location] toView:layer];
                    for(int j=0;j<=4;j++){
                        PRPoint between={a.x+(b.x-a.x)*j/4.,a.y+(b.y-a.y)*j/4.};
                        if(pr_distance2(between,pr_project(between,guide))>1)[failures addObject:@"Rendered connection cuts across the arc instead of following it"];
                    }
                }
            }
            NSArray *replay=[input constrainedControlPoints:sparse initialLocationInView:CGPointZero];
            if(replay.count!=sweep.count)[failures addObject:@"Repeated native batch changed subdivision count"];
            for(NSUInteger i=0;i<MIN(replay.count,sweep.count);i++){
                ValkyrieStrokeSegmentPoint *a=replay[i],*b=sweep[i];
                if(a.index!=b.index || !CGPointEqualToPoint(a.location,b.location))[failures addObject:@"Repeated native batch changed stable sample IDs or locations"];
            }
            ValkyrieStrokeSegmentPoint *last=sparse.lastObject;last.index=5;
            if([input constrainedControlPoints:sparse initialLocationInView:CGPointZero]!=sparse)[failures addObject:@"Unsupported native index gaps were expanded unsafely"];
            last.index=1;
            if([[layer valueForKey:@"nativeSamples"] unsignedIntegerValue]<60)[failures addObject:@"Native projection counter did not observe the real hooked entry point"];
            ValkyrieStrokeOptions *settings=[ValkyrieStrokeOptions new];settings.marker=42;
            [engine paintBegan:rawBatch options:settings];
            if(engine.valkyrieStrokeOptions==settings || engine.valkyrieStrokeOptions.marker!=42)[failures addObject:@"Ruler stroke did not get an isolated native-options snapshot"];
            ValkyrieStrokePlot *plot=[ValkyrieStrokePlot new];plot.options=[[engine.valkyrieStrokeOptions copy] secondaryOptions];
            ValkyrieStrokeOptions *noSecondary=[plot.options copy];noSecondary.marker=-1;
            if([noSecondary secondaryOptions])[failures addObject:@"Missing secondary native options were not preserved"];
            PRGuide nativeGuide=guide;nativeGuide.center=(PRPoint){0,0};nativeGuide.angle=0;nativeGuide.radius=1;
            for(int i=0;i<3;i++){
                PRPoint p=pr_handle(i,guide);CGPoint value=[engine valkyriePointFromViewPoint:[layer convertPoint:CGPointMake(p.x,p.y) toView:canvas]];
                nativeGuide.points[i]=(PRPoint){value.x,value.y};
            }
            NSMutableArray *chord=[NSMutableArray array];
            for(int i=0;i<=64;i++){
                PRPoint a=nativeGuide.points[0],b=nativeGuide.points[2];
                [chord addObject:[NSValue valueWithCGPoint:CGPointMake(a.x+(b.x-a.x)*i/64.,a.y+(b.y-a.y)*i/64.)]];
            }
            plot.fixtureOrigins=chord;
            dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[plot plotCurve:(PRTestNativeCurve){0} previousPlot:nil initialAngle:0];});
            if(plot.originalCalls!=1 || plot.plotCount!=65)[failures addObject:@"Post-smoothing runtime hook skipped the original renderer"];
            for(NSUInteger i=0;i<plot.plotCount;i++){
                PRNativeDab *p=plot.points+i;PRPoint origin={p->origin[0],p->origin[1]},jittered={origin.x+p->variance[0],origin.y+p->variance[1]};
                if(pr_distance2(origin,pr_project(origin,nativeGuide))>.00001 || pr_distance2(jittered,pr_project(jittered,nativeGuide))>.00001)[failures addObject:@"Final brush dabs still lie inside the curve after downstream smoothing"];
                const PRNativeDab *before=(const PRNativeDab *)plot.originalBytes.bytes+i;
                if(memcmp(p->prefix,before->prefix,sizeof(p->prefix)) || memcmp(p->middle,before->middle,sizeof(p->middle)) || memcmp(p->suffix,before->suffix,sizeof(p->suffix)))[failures addObject:@"Final projection changed opaque brush/color/pressure fields"];
            }
            NSData *rendered=[plot.storage copy];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[plot plotCurve:(PRTestNativeCurve){0} previousPlot:nil initialAngle:0];});
            if(![rendered isEqualToData:plot.storage])[failures addObject:@"Delayed rendering lost the immutable stroke guide after the ruler was disabled"];
            [engine paintBegan:rawBatch options:settings];
            if(engine.valkyrieStrokeOptions!=settings)[failures addObject:@"Disabled ruler still copies/tags future freehand stroke options"];
            ValkyrieStrokePlot *freehand=[ValkyrieStrokePlot new];freehand.options=settings;freehand.fixtureOrigins=chord;
            [freehand plotCurve:(PRTestNativeCurve){0} previousPlot:nil initialAngle:0];
            if(![freehand.storage isEqualToData:freehand.originalBytes])[failures addObject:@"Post-smoothing hook modified a freehand stroke"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            PRTestTouch *pencil=[PRTestTouch new],*finger=[PRTestTouch new];pencil.testType=UITouchTypePencil;finger.testType=UITouchTypeDirect;
            PRPoint handle=pr_handle(0,guide),body=pr_world(pr_curve(.25,guide),guide);
            pencil.testLocation=CGPointMake(handle.x,handle.y);
            PRTestEvent *event=[PRTestEvent new];event.testTouches=[NSSet setWithObject:pencil];
            if([layer hitTest:pencil.testLocation withEvent:event]!=layer)[failures addObject:@"Pencil cannot select a ruler handle"];
            pencil.testLocation=CGPointMake(body.x,body.y);
            if([layer hitTest:pencil.testLocation withEvent:event]!=nil)[failures addObject:@"Ruler body intercepts Pencil painting"];
            finger.testLocation=CGPointMake(body.x,body.y);pencil.testLocation=CGPointMake(body.x+250,body.y+100);event.testTouches=[NSSet setWithObjects:pencil,finger,nil];
            if([layer hitTest:finger.testLocation withEvent:event]!=layer)[failures addObject:@"An unrelated Pencil contact blocks finger manipulation"];
            UIButton *nativeUndo=[UIButton buttonWithType:UIButtonTypeSystem];
            CGPoint undoPoint=[layer convertPoint:finger.testLocation toView:self.window.rootViewController.view];
            nativeUndo.frame=CGRectMake(undoPoint.x-20,undoPoint.y-20,40,40);[self.window.rootViewController.view addSubview:nativeUndo];
            if([layer hitTest:finger.testLocation withEvent:event]!=nil)[failures addObject:@"The ruler steals touches intended for native Undo or slider controls"];
            [nativeUndo removeFromSuperview];
            BOOL pencilPan=NO;
            for(UIGestureRecognizer *gesture in layer.gestureRecognizers)if([gesture isKindOfClass:UIPanGestureRecognizer.class] && [gesture.allowedTouchTypes containsObject:@(UITouchTypePencil)])pencilPan=YES;
            if(!pencilPan)[failures addObject:@"Ruler drag recognizer rejects the Pencil"];
            DocumentValkyrieViewController *unrelated=[DocumentValkyrieViewController new];unrelated.valkyrieController=[DocumentValkyrieController new];
            if([unrelated constrainedControlPoints:rawBatch initialLocationInView:CGPointZero]!=rawBatch)[failures addObject:@"Ruler altered an unrelated document pipeline"];
            [unrelated.valkyrieController paintBegan:rawBatch options:settings];
            if(unrelated.valkyrieController.valkyrieStrokeOptions!=settings)[failures addObject:@"Ruler tagged another document's rendering options"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            if([input constrainedControlPoints:rawBatch initialLocationInView:CGPointZero]!=rawBatch)[failures addObject:@"Disabling the ruler failed to restore the original native samples"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            [symmetry sendActionsForControlEvents:UIControlEventTouchUpInside];
            PRTestModel *model=((DocumentViewController *)self.window.rootViewController).modelController;
            if(!model.valkyrieController.enabled || !model.began || model.document.drawingGuide.type!=3 || !model.document.drawingGuide.updated || !model.drawingGuideController.finished || !model.refreshed)[failures addObject:@"Native symmetry bridge did not create/enable a guide and execute its validated selector sequence"];
            UISegmentedControl *modes=(UISegmentedControl *)findIdentifier(layer,@"procreate-rulers-symmetry-modes");
            if(modes.hidden || modes.numberOfSegments!=4)[failures addObject:@"Sketchbook-style quick symmetry choices are unavailable"];
            for(NSInteger i=0;i<4;i++) {
                modes.selectedSegmentIndex=i;[modes sendActionsForControlEvents:UIControlEventValueChanged];
                if(model.document.drawingGuide.symmetryType!=i || !model.document.editingLayer.drawingGuideAssisted)[failures addObject:@"Symmetry mode did not commit native assisted drawing"];
            }
            UIButton *off=(UIButton *)findIdentifier(layer,@"procreate-rulers-symmetry-off");[off sendActionsForControlEvents:UIControlEventTouchUpInside];
            if(model.valkyrieController.enabled || model.document.editingLayer.drawingGuideAssisted)[failures addObject:@"Symmetry off did not disable guide and assistance"];
            if([[layer valueForKey:@"guideVisible"] boolValue])[ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            if([[layer valueForKey:@"guideVisible"] boolValue])[failures addObject:@"Ruler cannot be dismissed"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        NSDictionary *result=@{@"passed":@(failures.count==0),@"failures":failures,@"scope":@"Production input and post-smoothing plot runtime hooks with explicit native ABI/layout test doubles; off-main-thread final brush dab and variance projection, options-copy propagation, immutable delayed snapshots, untouched opaque fields and freehand passthrough; previous input/gesture/symmetry regressions; real Procreate binary not executed"};
        NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"toolbar-test.json"];
        [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
    }];
    return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(PRTestDelegate.class));}}
