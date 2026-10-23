#import "CCPerspective.h"

@implementation CCPerspectiveViewController
- (BOOL)providesOwnPlatter { return YES; }
- (CGFloat)preferredExpandedContentHeight { return 0; }
- (CGFloat)preferredExpandedContentWidth { return 0; }
- (BOOL)shouldBeginTransitionToExpandedContentModule { return NO; }
- (void)viewDidLoad {
    [super viewDidLoad];
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    UIImage *glyph = [UIImage imageNamed:@"icon@3x" inBundle:bundle compatibleWithTraitCollection:nil];
    if (!glyph) glyph = [UIImage systemImageNamed:@"magnifyingglass"];
    self.glyphImage = [glyph imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.selectedGlyphImage = self.glyphImage;
    self.glyphColor = UIColor.whiteColor;
    self.selectedGlyphColor = UIColor.whiteColor;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ccperspective_stateChanged:) name:CCPerspectiveStateDidChangeNotification object:nil];
    [self ccperspective_stateChanged:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self ccperspective_stateChanged:nil]; }
- (void)ccperspective_stateChanged:(NSNotification *)note { (void)note; self.selected = CCPerspectiveIsEnabled(); }
- (void)buttonTapped:(id)sender forEvent:(UIEvent *)event { (void)sender; (void)event; CCPerspectiveToggle(); }
@end
