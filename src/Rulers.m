#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Geometry.h"

@interface PRLayer : UIView
@property(nonatomic) PRGuide guide;
@property(nonatomic) BOOL snap, selecting;
@property(nonatomic,weak) UIView *canvas;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *snapButton;
@property(nonatomic,strong) UIButton *rulerButton, *symmetryButton;
@property(nonatomic,weak) UIView *transformButton;
@property(nonatomic,weak) UIViewController *documentController;
@property(nonatomic) BOOL guideVisible;
- (void)refreshPlacement;
@end
static __weak PRLayer *activeLayer;

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

static CGPoint projectTouch(UITouch *touch, UIView *view, CGPoint raw) {
    PRLayer *layer=activeLayer; UIView *canvas=layer.canvas;
    if(!layer.snap || !layer.guideVisible || !canvas.window || layer.window!=touch.window || touch.type!=UITouchTypePencil) return raw;
    UIView *hit=touch.view;
    if(!hit || !(hit==canvas || [hit isDescendantOfView:canvas])) return raw;
    for(UIView *v=hit;v;v=v.superview) if([v isKindOfClass:UIControl.class] || v==layer) return raw;
    UIView *coordinateView=view ?: touch.window;
    CGPoint screen=[coordinateView convertPoint:raw toView:layer];
    PRPoint p=pr_project((PRPoint){screen.x,screen.y},layer.guide);
    return [layer convertPoint:CGPointMake(p.x,p.y) toView:coordinateView];
}

// Each selector has its own saved implementation, including subpixel Pencil locations.
static CGPoint (*originalLocation)(id,SEL,UIView *);
static CGPoint (*originalPrevious)(id,SEL,UIView *);
static CGPoint (*originalPrecise)(id,SEL,UIView *);
static CGPoint (*originalPrecisePrevious)(id,SEL,UIView *);
static CGPoint hookedLocation(UITouch *t,SEL s,UIView *v){return projectTouch(t,v,originalLocation(t,s,v));}
static CGPoint hookedPrevious(UITouch *t,SEL s,UIView *v){return projectTouch(t,v,originalPrevious(t,s,v));}
static CGPoint hookedPrecise(UITouch *t,SEL s,UIView *v){return projectTouch(t,v,originalPrecise(t,s,v));}
static CGPoint hookedPrecisePrevious(UITouch *t,SEL s,UIView *v){return projectTouch(t,v,originalPrecisePrevious(t,s,v));}

@implementation PRLayer
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    b.accessibilityLabel=title; return b;
}
- (UISlider *)slider:(float)minimum max:(float)maximum value:(float)value action:(SEL)action label:(NSString *)label {
    UISlider *s=[UISlider new];s.minimumValue=minimum;s.maximumValue=maximum;s.value=value;
    s.accessibilityLabel=label;[s addTarget:self action:action forControlEvents:UIControlEventValueChanged];return s;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if(!(self=[super initWithFrame:frame]))return nil;
    self.backgroundColor=UIColor.clearColor;self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _guide=(PRGuide){{frame.size.width/2,frame.size.height/2},0,150,.6,PRLine};
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
    _panel.frame=CGRectMake(12,65,350,188);_panel.hidden=YES;[self addSubview:_panel];
    UIStackView *stack=[[UIStackView alloc]initWithFrame:CGRectMake(10,6,330,176)];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=4;[_panel addSubview:stack];
    UIStackView *row=[UIStackView new];row.distribution=UIStackViewDistributionFillEqually;
    [row addArrangedSubview:[self button:@"Righelli ▾" action:@selector(collapse:)]];
    [row addArrangedSubview:[self button:@"Scegli tela" action:@selector(selectCanvas:)]];
    _snapButton=[self button:@"Aggancio OFF" action:@selector(toggleSnap:)];[row addArrangedSubview:_snapButton];[stack addArrangedSubview:row];
    UISegmentedControl *kinds=[[UISegmentedControl alloc]initWithItems:@[@"Retta",@"90°",@"45°",@"○",@"Ellisse",@"Curva",@"Angolo"]];
    kinds.selectedSegmentIndex=0;kinds.backgroundColor=UIColor.systemGrayColor;[kinds addTarget:self action:@selector(kind:) forControlEvents:UIControlEventValueChanged];[stack addArrangedSubview:kinds];
    [stack addArrangedSubview:[self slider:-180 max:180 value:0 action:@selector(angle:) label:@"Angolo del righello"]];
    [stack addArrangedSubview:[self slider:20 max:500 value:150 action:@selector(radius:) label:@"Dimensione della guida"]];
    _status=[UILabel new];_status.font=[UIFont systemFontOfSize:11];_status.textColor=UIColor.whiteColor;_status.numberOfLines=2;
    _status.text=@"Trascina il centro blu. Scegli la tela con un dito.\nSimmetria: usa le guide native di Procreate.";[stack addArrangedSubview:_status];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(move:)];pan.allowedTouchTypes=@[@(UITouchTypeDirect)];[self addGestureRecognizer:pan];
    return self;
}
- (void)layoutSubviews {[super layoutSubviews];[self refreshPlacement];}
- (void)refreshPlacement {
    UIViewController *document=findDocument(self.window.rootViewController);
    if(_documentController!=document){_canvas=nil;_snap=NO;_selecting=NO;_transformButton=nil;_documentController=document;[_snapButton setTitle:@"Aggancio OFF" forState:0];}
    if(!_transformButton.window)_transformButton=findTransform(self.window,self);
    // Prefer the real native control, including compact toolbar variants.
    if(!_transformButton && document){
        id toolbar=nativeObject(document,@"toolbarController");
        id candidate=nativeObject(toolbar,@"transformButton");
        if(![candidate isKindOfClass:UIView.class] || !((UIView *)candidate).window)candidate=nativeObject(toolbar,@"transformButtonCompact");
        if([candidate isKindOfClass:UIView.class] && ((UIView *)candidate).window)_transformButton=candidate;
    }
    BOOL visible=document && _transformButton.window && !_transformButton.hidden && _transformButton.alpha>.01;
    _rulerButton.hidden=!visible;_symmetryButton.hidden=!visible;
    if(!visible){_snap=NO;_selecting=NO;_panel.hidden=YES;_guideVisible=NO;[self setNeedsDisplay];return;}
    CGRect anchor=[_transformButton convertRect:_transformButton.bounds toView:self];
    CGFloat side=44, x=CGRectGetMaxX(anchor)+2;
    CGFloat y=CGRectGetMidY(anchor)-side/2;
    // Never overlay the existing right-hand brush/color controls in a narrow window.
    if(x+2*side>self.bounds.size.width*.60){_rulerButton.hidden=YES;_symmetryButton.hidden=YES;_snap=NO;_guideVisible=NO;_panel.hidden=YES;return;}
    _rulerButton.frame=CGRectMake(x,y,side,side);_symmetryButton.frame=CGRectMake(x+side,y,side,side);
    CGRect panel=_panel.frame;panel.origin=CGPointMake(fmin(x,self.bounds.size.width-panel.size.width-12),CGRectGetMaxY(_rulerButton.frame)+8);_panel.frame=panel;
}
- (void)toggleRuler:(id)sender {
    _guideVisible=!_guideVisible;_panel.hidden=!_guideVisible;
    _rulerButton.tintColor=_guideVisible?UIColor.systemBlueColor:[UIColor colorWithWhite:.76 alpha:1];
    if(!_guideVisible){_snap=NO;_selecting=NO;[_snapButton setTitle:@"Aggancio OFF" forState:0];}
    [self setNeedsDisplay];
}
- (void)openSymmetry:(id)sender {
    _panel.hidden=YES;_guideVisible=NO;_snap=NO;_selecting=NO;
    _rulerButton.tintColor=[UIColor colorWithWhite:.76 alpha:1];[_snapButton setTitle:@"Aggancio OFF" forState:0];[self setNeedsDisplay];
    id model=nativeObject(_documentController,@"modelController");
    id document=nativeObject(model,@"document");
    id guide=nativeObject(document,@"drawingGuide");
    // Confirmed in the supplied build: guide type 3 is symmetry (symmetryStrokes).
    if(!guide || ![guide isKindOfClass:NSClassFromString(@"ValkyrieDrawingGuide")] || !nativeVoid(model,@"beginDrawingGuideMode")){
        [self showNativeError];return;
    }
    id controller=nativeObject(model,@"drawingGuideController");
    // beginDrawingGuideMode may replace state: reacquire the current guide.
    guide=nativeObject(nativeObject(model,@"document"),@"drawingGuide");
    NSMethodSignature *setter=[guide methodSignatureForSelector:NSSelectorFromString(@"setType:")];
    if(!controller || !setter || ![controller respondsToSelector:NSSelectorFromString(@"finishCheckpoint")]){[self showNativeError];return;}
    if(!nativeInteger(controller,@"beginGuideTypeChangedCheckpoint:",3)){[self showNativeError];return;}
    BOOL changed=nativeInteger(guide,@"setType:",3);
    if(changed)nativeVoid(guide,@"updateSegments");
    nativeVoid(controller,@"finishCheckpoint");nativeVoid(model,@"updateInterface");
    if(!changed)[self showNativeError];
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
    if(_selecting || (_guideVisible && hypot(p.x-_guide.center.x,p.y-_guide.center.y)<26))return self;
    return nil;
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(!_selecting)return;
    CGPoint p=[touches.anyObject locationInView:self.window];
    self.hidden=YES;UIView *hit=[self.window hitTest:p withEvent:event];self.hidden=NO;
    _selecting=NO;
    // Explicit user selection avoids guessing undocumented Procreate canvas classes.
    BOOL invalid=!hit || hit==self.window;
    for(UIView *v=hit;v;v=v.superview) if([v isKindOfClass:UIControl.class] || [v isKindOfClass:UIScrollView.class]) invalid=YES;
    if(invalid){_status.text=@"Selezione non valida: scegli una zona vuota della tela.";return;}
    _canvas=hit;_status.text=[NSString stringWithFormat:@"Tela: %@. Aggancio solo Apple Pencil.\nGuide fisse sullo schermo: regola dopo zoom/rotazione.",NSStringFromClass(hit.class)];
}
- (void)selectCanvas:(id)sender {_snap=NO;[_snapButton setTitle:@"Aggancio OFF" forState:0];_selecting=YES;_status.text=@"Tocca con un dito una zona vuota della tela.";}
- (void)toggleSnap:(id)sender {
    if(!_canvas.window){_status.text=@"Prima premi Scegli tela e tocca la tela.";return;}
    _snap=!_snap;[_snapButton setTitle:_snap?@"Aggancio ON":@"Aggancio OFF" forState:0];
}
- (void)collapse:(UIButton *)sender {
    BOOL collapsed=_panel.bounds.size.height<50;CGRect f=_panel.frame;f.size.height=collapsed?188:38;_panel.frame=f;_panel.clipsToBounds=YES;
    [sender setTitle:collapsed?@"Righelli ▾":@"Righelli ▸" forState:0];
}
- (void)kind:(UISegmentedControl *)s {_guide.kind=(PRKind)s.selectedSegmentIndex;[self setNeedsDisplay];}
- (void)angle:(UISlider *)s {_guide.angle=s.value*M_PI/180;_status.text=[NSString stringWithFormat:@"Angolo %.1f° — aggancio solo Apple Pencil",s.value];[self setNeedsDisplay];}
- (void)radius:(UISlider *)s {_guide.radius=s.value;[self setNeedsDisplay];}
- (void)move:(UIPanGestureRecognizer *)g {
    CGPoint p=[g locationInView:self];
    if(g.state==UIGestureRecognizerStateBegan && hypot(p.x-_guide.center.x,p.y-_guide.center.y)>35){g.enabled=NO;g.enabled=YES;return;}
    if(g.state==UIGestureRecognizerStateChanged){_guide.center=(PRPoint){p.x,p.y};[self setNeedsDisplay];}
}
- (void)drawRect:(CGRect)rect {
    if(!_guideVisible)return;
    CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetStrokeColorWithColor(c,[UIColor colorWithRed:.1 green:.8 blue:1 alpha:.8].CGColor);CGContextSetLineWidth(c,1.5);
    CGContextSaveGState(c);CGContextTranslateCTM(c,_guide.center.x,_guide.center.y);CGContextRotateCTM(c,_guide.angle);
    double r=_guide.radius, len=hypot(self.bounds.size.width,self.bounds.size.height);
    if(_guide.kind==PRCircle || _guide.kind==PREllipse){double y=_guide.kind==PRCircle?r:r*_guide.ratio;CGContextStrokeEllipseInRect(c,CGRectMake(-r,-y,2*r,2*y));}
    else if(_guide.kind==PRCurve){CGContextMoveToPoint(c,-r,0);CGContextAddQuadCurveToPoint(c,0,-r,r,0);CGContextStrokePath(c);}
    else {
        CGContextMoveToPoint(c,-len,0);CGContextAddLineToPoint(c,len,0);
        if(_guide.kind==PRSquare90){CGContextMoveToPoint(c,0,-len);CGContextAddLineToPoint(c,0,len);}
        if(_guide.kind==PRSquare45){CGContextMoveToPoint(c,-len,-len);CGContextAddLineToPoint(c,len,len);}
        CGContextStrokePath(c);
        for(int i=-40;i<=40;i++){double x=i*10;CGContextMoveToPoint(c,x,0);CGContextAddLineToPoint(c,x,i%5==0?12:6);}CGContextStrokePath(c);
        if(_guide.kind==PRProtractor){CGContextAddArc(c,0,0,r,M_PI,2*M_PI,0);CGContextStrokePath(c);
            for(int deg=0;deg<=180;deg+=10){double a=deg*M_PI/180;CGContextMoveToPoint(c,r*cos(a),-r*sin(a));CGContextAddLineToPoint(c,(r-12)*cos(a),-(r-12)*sin(a));}CGContextStrokePath(c);}
    }
    CGContextRestoreGState(c);CGContextSetFillColorWithColor(c,UIColor.systemBlueColor.CGColor);CGContextFillEllipseInRect(c,CGRectMake(_guide.center.x-8,_guide.center.y-8,16,16));
}
@end

static void installLayer(void) {
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
            [activeLayer refreshPlacement];return;
        }
        [activeLayer removeFromSuperview];PRLayer *layer=[[PRLayer alloc]initWithFrame:window.bounds];[window addSubview:layer];activeLayer=layer;[layer refreshPlacement];return;
    }
    if(activeLayer){activeLayer.snap=NO;activeLayer.selecting=NO;activeLayer.hidden=YES;}
}
__attribute__((constructor)) static void startRulers(void) {
    @autoreleasepool {
        // Sideloadly can change CFBundleIdentifier. Match the executable instead.
        if(![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"] isEqualToString:@"Procreate"])return;
        originalLocation=(void *)method_setImplementation(class_getInstanceMethod(UITouch.class,@selector(locationInView:)),(IMP)hookedLocation);
        originalPrevious=(void *)method_setImplementation(class_getInstanceMethod(UITouch.class,@selector(previousLocationInView:)),(IMP)hookedPrevious);
        originalPrecise=(void *)method_setImplementation(class_getInstanceMethod(UITouch.class,@selector(preciseLocationInView:)),(IMP)hookedPrecise);
        originalPrecisePrevious=(void *)method_setImplementation(class_getInstanceMethod(UITouch.class,@selector(precisePreviousLocationInView:)),(IMP)hookedPrecisePrevious);
        dispatch_async(dispatch_get_main_queue(),^{
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){installLayer();}];
            installLayer();
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer){
                activeLayer.hidden=NO;installLayer();
            }];
        });
    }
}
