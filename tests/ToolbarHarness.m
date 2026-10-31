// UIKit integration harness. Native Procreate objects are explicit test doubles.
// This verifies our UI/lifecycle, NOT compatibility with the real Procreate engine.
#import <UIKit/UIKit.h>

@interface ValkyrieDrawingGuide : NSObject
@property(nonatomic) NSUInteger type;
@property(nonatomic) BOOL updated;
- (void)updateSegments;
@end
@implementation ValkyrieDrawingGuide
- (void)updateSegments {_updated=YES;}
@end
@interface PRTestDocument : NSObject
@property(nonatomic,strong) ValkyrieDrawingGuide *drawingGuide;
@end
@implementation PRTestDocument
@end
@interface PRTestCheckpoint : NSObject
@property(nonatomic) NSInteger startedType;
@property(nonatomic) BOOL finished;
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
@property(nonatomic) BOOL began, refreshed;
- (void)beginDrawingGuideMode;
- (void)updateInterface;
@end
@implementation PRTestModel
- (void)beginDrawingGuideMode {_began=YES;}
- (void)updateInterface {_refreshed=YES;}
@end
@interface DocumentViewController : UIViewController
@property(nonatomic,strong) PRTestModel *modelController;
@end
@implementation DocumentViewController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=[UIColor colorWithWhite:.92 alpha:1];
    _modelController=[PRTestModel new];_modelController.document=[PRTestDocument new];_modelController.document.drawingGuide=[ValkyrieDrawingGuide new];_modelController.drawingGuideController=[PRTestCheckpoint new];
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
            [symmetry sendActionsForControlEvents:UIControlEventTouchUpInside];
            PRTestModel *model=((DocumentViewController *)self.window.rootViewController).modelController;
            if(!model.began || model.document.drawingGuide.type!=3 || !model.document.drawingGuide.updated || !model.drawingGuideController.finished || !model.refreshed)[failures addObject:@"Native symmetry bridge did not execute its validated selector sequence"];
            if([[layer valueForKey:@"guideVisible"] boolValue])[failures addObject:@"Ruler remains active over the native symmetry editor"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
            if([[layer valueForKey:@"guideVisible"] boolValue])[failures addObject:@"Ruler cannot be dismissed"];
            [ruler sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        NSDictionary *result=@{@"passed":@(failures.count==0),@"failures":failures,@"scope":@"UIKit toolbar + legacy window + altered bundle ID + native bridge test doubles; real Procreate not executed"};
        NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"toolbar-test.json"];
        [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
    }];
    return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(PRTestDelegate.class));}}
