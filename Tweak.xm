#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdatomic.h>
#import <dlfcn.h>

// ── Anti-debug: يمنع الـ debugger من الاتصال ──────────────────────────────
__attribute__((constructor(101)))
static void _gd(void) {
    const uint8_t _pe[] = {0x2A,0x2E,0x28,0x3B,0x39,0x3F};
    char _pd[7]; for(int _i=0;_i<6;_i++) _pd[_i]=(char)(_pe[_i]^0x5A); _pd[6]=0;
    typedef int(*_pf)(int,int,void*,int);
    _pf _p = (_pf)dlsym(RTLD_DEFAULT, _pd);
    if (_p) _p(31, 0, 0, 0);
}

// ── Symbol obfuscation: C functions ──────────────────────────────────────
#define isHideableText          _xF1a2
#define hideLocked              _xB3c4
#define collectViews            _xD5e6
#define sortedMikes             _x7F89
#define tapControlInView        _xA0b1
#define tapView                 _x2C3d
#define hudHasHideableText      _xE4f5
#define swizzleHUDIfNeeded      _x6A7b
#define startAutoClick          _x8C9d
#define stopAutoClick           _x0EfA
#define broadcastStart          _x1B2c
#define broadcastStop           _x3D4e
#define onRemoteStart           _x5F6a
#define onRemoteStop            _x7B8c
#define registerBroadcastListeners _x9D0e
#define smith101_load           _xF1b2
#define smith101_unload         _x3E4f
#define hideDecorativeViews     _x4G5h

// ── Symbol obfuscation: ObjC classes ─────────────────────────────────────
#define MicPanel                _Xq1r2
#define FaelBtn                 _Xs3t4
#define QultashAlert            _Xu5v6
#define SWTHelper               _Xw7x8
#define PassWin                 _Xy9z0

// ── Symbol obfuscation: ObjC methods (ours only) ──────────────────────────
#define doStart                 _ma01
#define doStop                  _mb02
#define autoStop                _mc03
#define remoteStart             _md04
#define remoteStop              _me05
#define qultashTapped           _mf06
#define updateMikeCount         _mg07
#define pick                    _mh08
#define drag                    _mi09
#define rateChanged             _mj0A
#define build                   _mk0B
#define setRunning              _ml0C
#define confirmTapped           _mm0D
#define dismiss                 _mn0E
#define show                    _mo0F
#define dragged                 _mp10
#define tapped                  _mq11
#define shared                  _mr12
#define maxX                    _ms13
// ─────────────────────────────────────────────────────────────────────────

// ─── Hide toast messages ──────────────────────────────────────────────────

static BOOL isHideableText(NSString *t) {
    if (!t || t.length == 0) return NO;
    NSString *low = t.lowercaseString;
    if ([low containsString:@"mic locked"])           return YES;
    if ([low containsString:@"locked by owner"])      return YES;
    if ([low containsString:@"already on mic"])       return YES;
    if ([low containsString:@"you're already on"])    return YES;
    if ([low containsString:@"connection lost"])      return YES;
    if ([low containsString:@"network connection"])   return YES;
    if ([t containsString:@"مقفل من"])               return YES;
    if ([t containsString:@"مقفل بواسطة"])           return YES;
    if ([t containsString:@"مغلق من"])               return YES;
    if ([t containsString:@"مغلق بواسطة"])           return YES;
    if ([t containsString:@"بواسطة المالك"])          return YES;
    if ([t containsString:@"أنت بالفعل"])            return YES;
    if ([t containsString:@"على المايك"])             return YES;
    if ([t containsString:@"بالفعل على"])             return YES;
    if ([t containsString:@"انقطع الاتصال"])          return YES;
    if ([t containsString:@"فقد الاتصال"])            return YES;
    if ([t containsString:@"الاتصال بالإنترنت"])      return YES;
    if ([t containsString:@"يرجى المحاولة"])          return YES;
    return NO;
}

static void hideLocked(UIView *root) {
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    NSMutableSet   *seen  = [NSMutableSet set];
    while (stack.count > 0) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([seen containsObject:v]) continue;
        [seen addObject:v];
        NSString *t = nil;
        if ([v isKindOfClass:[UILabel class]])    t = [(UILabel *)v text];
        if ([v isKindOfClass:[UITextView class]]) t = [(UITextView *)v text];
        if (isHideableText(t)) {
            v.hidden = YES; v.alpha = 0;
            if (v.superview) { v.superview.hidden = YES; v.superview.alpha = 0; }
        }
        NSArray *subs = nil;
        @try { subs = [v.subviews copy]; } @catch (NSException *e) {}
        for (UIView *s in subs) [stack addObject:s];
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────

static NSArray *collectViews(UIView *root, Class cls) {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableArray *stack  = [NSMutableArray arrayWithObject:root];
    NSMutableSet   *seen   = [NSMutableSet set];
    while (stack.count > 0) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([seen containsObject:v]) continue;
        [seen addObject:v];
        if ([v isKindOfClass:cls]) [result addObject:v];
        NSArray *subs = nil;
        @try { subs = [v.subviews copy]; } @catch (NSException *e) {}
        for (UIView *s in subs) [stack addObject:s];
    }
    return result;
}

static NSArray *sortedMikes(void) {
    Class cls = NSClassFromString(@"YallaLite.LTMikeElement")
             ?: NSClassFromString(@"LTMikeElement")
             ?: NSClassFromString(@"YallaLite_LTMikeElement")
             ?: NSClassFromString(@"YallaLite.LTLiveMikeFace")
             ?: NSClassFromString(@"LTLiveMikeFace");
    if (!cls) {
        // Dynamic search in main bundle
        unsigned int count = 0;
        const char *img = [[[NSBundle mainBundle] executablePath] UTF8String];
        const char **names = objc_copyClassNamesForImage(img, &count);
        if (names) {
            for (unsigned int pass = 0; pass < 2 && !cls; pass++) {
                for (unsigned int i = 0; i < count; i++) {
                    NSString *n = @(names[i]);
                    NSString *lower = n.lowercaseString;
                    BOOL match = pass == 0
                        ? ([lower containsString:@"mike"] && [lower containsString:@"element"])
                        : [lower containsString:@"mike"];
                    if (match) {
                        Class c = NSClassFromString(n);
                        if (c && [c isSubclassOfClass:[UIView class]]) { cls = c; break; }
                    }
                }
            }
            free((void*)names);
        }
    }
    if (!cls) return @[];
    NSMutableArray *all = [NSMutableArray array];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        [all addObjectsFromArray:collectViews(w, cls)];
#pragma clang diagnostic pop
    BOOL rtl = UIApplication.sharedApplication.userInterfaceLayoutDirection
               == UIUserInterfaceLayoutDirectionRightToLeft;
    [all sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGRect ra = [a.superview convertRect:a.frame toView:nil];
        CGRect rb = [b.superview convertRect:b.frame toView:nil];
        if (fabs(ra.origin.y - rb.origin.y) > 30)
            return ra.origin.y < rb.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return rtl
            ? (ra.origin.x > rb.origin.x ? NSOrderedAscending : NSOrderedDescending)
            : (ra.origin.x < rb.origin.x ? NSOrderedAscending : NSOrderedDescending);
    }];
    return all;
}

static BOOL tapControlInView(UIView *root) {
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    NSMutableSet   *seen  = [NSMutableSet set];
    while (stack.count > 0) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([seen containsObject:v]) continue;
        [seen addObject:v];
        if ([v isKindOfClass:[UIControl class]]) {
            [(UIControl *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
            return YES;
        }
        NSArray *subs = nil;
        @try { subs = [v.subviews copy]; } @catch (NSException *e) {}
        for (UIView *s in subs) [stack addObject:s];
    }
    return NO;
}

static void tapView(UIView *v) {
    if (!v) return;
    if (tapControlInView(v)) return;
    for (UIGestureRecognizer *gr in v.gestureRecognizers) {
        if (![gr isKindOfClass:[UITapGestureRecognizer class]]) continue;
        NSArray *targets = nil;
        @try { targets = [gr valueForKey:@"_targets"]; } @catch (NSException *e) {}
        for (id ta in targets) {
            id  target = nil, actVal = nil;
            @try {
                target = [ta valueForKey:@"_target"];
                actVal = [ta valueForKey:@"_action"];
            } @catch (NSException *e) {}
            SEL sel = [actVal isKindOfClass:[NSString class]]
                      ? NSSelectorFromString(actVal) : nil;
            if (target && sel && [target respondsToSelector:sel]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:sel withObject:gr];
                #pragma clang diagnostic pop
            }
        }
        return;
    }
}

// ─── Hide decorative views ────────────────────────────────────────────────

static void hideDecorativeViews(UIWindow *win) {
    static NSArray *clsNames = nil;
    if (!clsNames) clsNames = @[@"YallaLite.LTGiftTrack",
                                 @"YallaLite.LTBroadcastTrack",
                                 @"YallaLite.LTXibView",
                                 @"YallaLite.LTLiveBackdrop"];
    for (NSString *name in clsNames) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        for (UIView *v in collectViews(win, cls)) {
            if (!v.hidden) v.hidden = YES;
        }
    }
}

// ─── MBProgressHUD Hook ───────────────────────────────────────────────────

static IMP gOrigHUDShow = NULL;

static BOOL hudHasHideableText(id hud) {
    @try {
        NSString *t = [[hud valueForKey:@"label"] valueForKey:@"text"];
        if (isHideableText(t)) return YES;
        t = [[hud valueForKey:@"detailsLabel"] valueForKey:@"text"];
        if (isHideableText(t)) return YES;
        t = [hud valueForKey:@"labelText"];
        if (isHideableText(t)) return YES;
        t = [hud valueForKey:@"detailsLabelText"];
        if (isHideableText(t)) return YES;
    } @catch (NSException *e) {}
    return NO;
}

static void swizzleHUDIfNeeded(void) {
    Class hudClass = NSClassFromString(@"MBProgressHUD");
    if (!hudClass) return;
    SEL sel = @selector(showAnimated:);
    Method m = class_getInstanceMethod(hudClass, sel);
    if (!m) {
        sel = NSSelectorFromString(@"show:");
        m = class_getInstanceMethod(hudClass, sel);
    }
    if (!m) return;
    SEL captured = sel;
    gOrigHUDShow = method_setImplementation(m, imp_implementationWithBlock(^(id hud, BOOL animated) {
        if (hudHasHideableText(hud)) return;
        if (gOrigHUDShow) ((void(*)(id,SEL,BOOL))objc_msgSend)(hud, captured, animated);
    }));
}

// ─── Auto-clicker ────────────────────────────────────────────────────────

static dispatch_source_t  gClickTimer;
static dispatch_block_t   gAutoStopBlock = nil;
static dispatch_queue_t   gClickQueue;
static volatile int32_t   gClickCount   = 0;
static volatile int32_t   gClickPending = 0;
static BOOL               gClickRunning = NO;
static NSInteger          gClickRate    = 500;
static UIView * __weak    gTargetMike   = nil;

static void stopAutoClick(void);

static void startAutoClick(NSInteger mikeIndex) {
    stopAutoClick();
    NSArray *mikes = sortedMikes();
    if (mikeIndex >= (NSInteger)mikes.count) return;
    gTargetMike   = mikes[mikeIndex];
    gClickRunning = YES;
    if (!gClickQueue)
        gClickQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    gClickTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gClickQueue);
    uint64_t interval = (uint64_t)(NSEC_PER_SEC / MAX(1, gClickRate));
    dispatch_source_set_timer(gClickTimer, DISPATCH_TIME_NOW, interval, 0);
    dispatch_source_set_event_handler(gClickTimer, ^{
        if (!gClickRunning) return;
        if (!__sync_bool_compare_and_swap(&gClickPending, 0, 1)) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (gClickRunning) {
                UIView *mike = gTargetMike;
                if (mike && mike.window != nil) {
                    [UIView performWithoutAnimation:^{ tapView(mike); }];
                    __sync_fetch_and_add(&gClickCount, 1);
                } else {
                    dispatch_block_t blk = gAutoStopBlock;
                    if (blk) blk(); else stopAutoClick();
                }
            }
            gClickPending = 0;
        });
    });
    dispatch_resume(gClickTimer);
}

static void stopAutoClick(void) {
    gClickRunning = NO;
    gTargetMike   = nil;
    gClickPending = 0;
    if (gClickTimer) {
        dispatch_source_cancel(gClickTimer);
        gClickTimer = nil;
    }
}

// ─── Multi-account broadcast ──────────────────────────────────────────────

static void broadcastStart(NSInteger micIdx) {
    NSString *n = [@"com.smith101.broadcast.start." stringByAppendingFormat:@"%ld", (long)micIdx];
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)n, NULL, NULL, YES);
}

static void broadcastStop(void) {
    NSString *s = @"com.smith101.broadcast.stop";
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)s, NULL, NULL, YES);
}

// ─── QultashAlert ─────────────────────────────────────────────────────────

@interface QultashAlert : UIView
- (instancetype)initWithObjTitle:(NSString *)title onConfirm:(void(^)(void))confirm;
- (void)show;
@end

@implementation QultashAlert

- (instancetype)initWithObjTitle:(NSString *)title onConfirm:(void(^)(void))confirm {
    CGFloat W = 270, H = 230;
    CGRect  sc = UIScreen.mainScreen.bounds;
    self = [super initWithFrame:CGRectMake((sc.size.width - W) / 2,
                                           (sc.size.height - H) / 2, W, H)];
    self.backgroundColor     = [UIColor colorWithRed:0.03 green:0.03 blue:0.09 alpha:0.98];
    self.layer.cornerRadius  = 18;
    self.layer.borderWidth   = 1;
    self.layer.borderColor   = [UIColor colorWithRed:0.1 green:0.35 blue:1.0 alpha:0.55].CGColor;
    self.layer.shadowColor   = [UIColor colorWithRed:0.0 green:0.3 blue:1.0 alpha:1].CGColor;
    self.layer.shadowRadius  = 22;
    self.layer.shadowOpacity = 0.55f;
    self.layer.shadowOffset  = CGSizeZero;

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 38)];
    bar.backgroundColor     = [UIColor colorWithRed:0.06 green:0.04 blue:0.18 alpha:1];
    bar.layer.cornerRadius  = 18;
    bar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self addSubview:bar];

    UILabel *barTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, W, 38)];
    barTitle.text          = @"Method: .cxx_destruct";
    barTitle.textAlignment = NSTextAlignmentCenter;
    barTitle.textColor     = [UIColor colorWithRed:0.55 green:0.65 blue:1.0 alpha:1];
    barTitle.font          = [UIFont boldSystemFontOfSize:12];
    [bar addSubview:barTitle];
    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragged:)];
    [bar addGestureRecognizer:drag];

    UILabel *objLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 46, W - 28, 16)];
    objLbl.text      = title;
    objLbl.textColor = [UIColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1];
    objLbl.font      = [UIFont systemFontOfSize:10.5];
    objLbl.numberOfLines = 1;
    objLbl.adjustsFontSizeToFitWidth = YES;
    [self addSubview:objLbl];

    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(14, 67, W - 28, 0.5)];
    sep1.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [self addSubview:sep1];

    NSArray *lines  = @[@"Signature:", @"- (void).cxx_destruct", @"", @"Return Type:", @"v"];
    NSArray *colors = @[
        [UIColor colorWithWhite:0.5 alpha:1],
        [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1],
        [UIColor clearColor],
        [UIColor colorWithWhite:0.5 alpha:1],
        [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1],
    ];
    UIFont *mono = [UIFont fontWithName:@"Courier-Bold" size:12] ?: [UIFont boldSystemFontOfSize:11];
    NSArray *fonts = @[
        [UIFont systemFontOfSize:11], mono,
        [UIFont systemFontOfSize:6],
        [UIFont systemFontOfSize:11], mono,
    ];
    CGFloat y = 74;
    for (int i = 0; i < 5; i++) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, y, W - 28, 18)];
        l.text = lines[i]; l.textColor = colors[i]; l.font = fonts[i];
        [self addSubview:l]; y += 18;
    }

    UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(14, y + 2, W - 28, 0.5)];
    sep2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [self addSubview:sep2];

    CGFloat bY = y + 10, bH = 36, bW = (W - 32) / 2;

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel.frame = CGRectMake(12, bY, bW, bH);
    [cancel setTitle:@"إلغاء" forState:UIControlStateNormal];
    cancel.titleLabel.font    = [UIFont boldSystemFontOfSize:13];
    cancel.backgroundColor    = [UIColor colorWithRed:0.60 green:0.04 blue:0.10 alpha:1];
    cancel.layer.cornerRadius = bH / 2;
    cancel.layer.shadowColor  = [UIColor colorWithRed:1.0 green:0.0 blue:0.1 alpha:1].CGColor;
    cancel.layer.shadowRadius = 7; cancel.layer.shadowOpacity = 0.5f; cancel.layer.shadowOffset = CGSizeZero;
    [cancel addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:cancel];

    void (^cb)(void) = [confirm copy];
    UIButton *ok = [UIButton buttonWithType:UIButtonTypeCustom];
    ok.frame = CGRectMake(12 + bW + 8, bY, bW, bH);
    [ok setTitle:@"موافقة" forState:UIControlStateNormal];
    ok.titleLabel.font    = [UIFont boldSystemFontOfSize:13];
    ok.backgroundColor    = [UIColor colorWithRed:0.04 green:0.35 blue:0.90 alpha:1];
    ok.layer.cornerRadius = bH / 2;
    ok.layer.shadowColor  = [UIColor colorWithRed:0.0 green:0.4 blue:1.0 alpha:1].CGColor;
    ok.layer.shadowRadius = 7; ok.layer.shadowOpacity = 0.5f; ok.layer.shadowOffset = CGSizeZero;
    objc_setAssociatedObject(ok, "cb", cb, OBJC_ASSOCIATION_COPY);
    [ok addTarget:self action:@selector(confirmTapped:) forControlEvents:UIControlEventTouchUpInside];
    [ok addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:ok];
    return self;
}
- (void)confirmTapped:(UIButton *)btn {
    void (^cb)(void) = objc_getAssociatedObject(btn, "cb");
    if (cb) cb();
}
- (void)dragged:(UIPanGestureRecognizer *)g {
    CGPoint d = [g translationInView:self.superview];
    CGRect  f = CGRectOffset(self.frame, d.x, d.y);
    CGRect sc = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(f.origin.x, sc.size.width  - f.size.width));
    f.origin.y = MAX(0, MIN(f.origin.y, sc.size.height - f.size.height));
    self.frame = f;
    [g setTranslation:CGPointZero inView:self.superview];
}
- (void)show {
    UIWindow *kw = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        if (w.isKeyWindow) { kw = w; break; }
#pragma clang diagnostic pop
    self.alpha = 0; self.transform = CGAffineTransformMakeScale(0.88, 0.88);
    [kw.rootViewController.view addSubview:self];
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.75
          initialSpringVelocity:0.5 options:0 animations:^{
        self.alpha = 1; self.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)dismiss {
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 0; self.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL done) { [self removeFromSuperview]; }];
}
@end

// ─── فعل (Swipe-to-Activate) ─────────────────────────────────────────────

@interface FaelBtn : UIView
@property (nonatomic, copy) void (^onActivate)(void);
- (void)setRunning:(BOOL)running;
@end

@implementation FaelBtn {
    UIView  *_thumb;
    UILabel *_lbl;
}
- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    self.backgroundColor    = [UIColor colorWithRed:0.14 green:0.52 blue:1 alpha:1];
    self.layer.cornerRadius = f.size.height / 2;
    self.clipsToBounds      = YES;
    _lbl = [[UILabel alloc] initWithFrame:self.bounds];
    _lbl.text          = @"فعل ›";
    _lbl.textColor     = UIColor.whiteColor;
    _lbl.textAlignment = NSTextAlignmentCenter;
    _lbl.font          = [UIFont boldSystemFontOfSize:14];
    [self addSubview:_lbl];
    CGFloat h = f.size.height - 8;
    _thumb = [[UIView alloc] initWithFrame:CGRectMake(4, 4, h, h)];
    _thumb.backgroundColor    = [UIColor colorWithWhite:1 alpha:0.25];
    _thumb.layer.cornerRadius = h / 2;
    [self addSubview:_thumb];
    return self;
}
- (CGFloat)maxX { return self.bounds.size.width - _thumb.bounds.size.width - 4; }
- (void)touchesMoved:(NSSet<UITouch *> *)ts withEvent:(UIEvent *)e {
    CGPoint p = [[ts anyObject] locationInView:self];
    CGFloat x = MAX(4, MIN(p.x - _thumb.bounds.size.width / 2, self.maxX));
    _thumb.frame = CGRectMake(x, _thumb.frame.origin.y,
                              _thumb.bounds.size.width, _thumb.bounds.size.height);
    _lbl.alpha = 1.0 - 0.5 * (x - 4) / MAX(1, self.maxX - 4);
}
- (void)touchesEnded:(NSSet<UITouch *> *)ts withEvent:(UIEvent *)e {
    CGFloat prog = (_thumb.frame.origin.x - 4) / MAX(1, self.maxX - 4);
    if (prog >= 0.7 && self.onActivate) self.onActivate();
    [UIView animateWithDuration:0.2 animations:^{
        self->_thumb.frame = CGRectMake(4, self->_thumb.frame.origin.y,
                                        self->_thumb.bounds.size.width,
                                        self->_thumb.bounds.size.height);
        self->_lbl.alpha = 1;
    }];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)ts withEvent:(UIEvent *)e {
    [self touchesEnded:ts withEvent:e];
}
- (void)setRunning:(BOOL)running {
    self.userInteractionEnabled = !running;
    if (running) {
        self.backgroundColor = [UIColor colorWithRed:0.85 green:0.35 blue:0.1 alpha:1];
        _lbl.text = @"● يعمل";
        [UIView animateWithDuration:0.3 animations:^{
            self->_thumb.frame = CGRectMake(self.maxX, self->_thumb.frame.origin.y,
                                            self->_thumb.bounds.size.width,
                                            self->_thumb.bounds.size.height);
        }];
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.14 green:0.52 blue:1 alpha:1];
        _lbl.text = @"فعل ›";
        _lbl.alpha = 1;
        [UIView animateWithDuration:0.3 animations:^{
            self->_thumb.frame = CGRectMake(4, self->_thumb.frame.origin.y,
                                            self->_thumb.bounds.size.width,
                                            self->_thumb.bounds.size.height);
        }];
    }
}
@end

// ─── Mic Panel ────────────────────────────────────────────────────────────

@interface MicPanel : UIView
- (void)updateMikeCount:(NSUInteger)count;
- (void)autoStop;
- (void)remoteStart:(NSInteger)micIdx;
- (void)remoteStop;
@end

@implementation MicPanel {
    NSMutableArray<UIButton *> *_btns;
    NSInteger   _sel;
    UILabel    *_status;
    UILabel    *_rateLabel;
    UISlider   *_rateSlider;
    FaelBtn    *_fael;
    NSTimer    *_counterTimer;
    UILabel    *_titleMask;
}

- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    _sel = -1;
    self.hidden = YES;
    [self build];
    return self;
}

- (void)build {
    CGFloat W = self.bounds.size.width;
    self.backgroundColor     = [UIColor colorWithRed:0.03 green:0.03 blue:0.09 alpha:0.97];
    self.layer.cornerRadius  = 18;
    self.layer.borderWidth   = 1;
    self.layer.borderColor   = [UIColor colorWithRed:0.1 green:0.35 blue:1.0 alpha:0.5].CGColor;
    self.layer.shadowColor   = [UIColor colorWithRed:0.0 green:0.3 blue:1.0 alpha:1].CGColor;
    self.layer.shadowRadius  = 18;
    self.layer.shadowOpacity = 0.45f;
    self.layer.shadowOffset  = CGSizeMake(0, 4);

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 40)];
    bar.backgroundColor     = [UIColor colorWithRed:0.06 green:0.04 blue:0.18 alpha:1];
    bar.layer.cornerRadius  = 18;
    bar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self addSubview:bar];

    UIView *gradView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 40)];
    [bar addSubview:gradView];

    _titleMask = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, W, 40)];
    _titleMask.text          = @"Rebellion • Smith";
    _titleMask.textAlignment = NSTextAlignmentCenter;
    _titleMask.textColor     = UIColor.whiteColor;
    _titleMask.font          = [UIFont boldSystemFontOfSize:14];
    gradView.layer.mask = _titleMask.layer;

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame      = CGRectMake(0, 0, W * 3, 40);
    grad.startPoint = CGPointMake(0, 0.5);
    grad.endPoint   = CGPointMake(1, 0.5);
    grad.colors = @[
        (id)[UIColor colorWithRed:0.90 green:0.08 blue:0.20 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.45 blue:1.00 alpha:1].CGColor,
        (id)[UIColor colorWithRed:1.00 green:0.78 blue:0.08 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.90 green:0.08 blue:0.20 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.45 blue:1.00 alpha:1].CGColor,
        (id)[UIColor colorWithRed:1.00 green:0.78 blue:0.08 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.90 green:0.08 blue:0.20 alpha:1].CGColor,
    ];
    [gradView.layer addSublayer:grad];

    CABasicAnimation *wave = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    wave.fromValue      = @0;
    wave.toValue        = @(-W);
    wave.duration       = 2.5;
    wave.repeatCount    = HUGE_VALF;
    wave.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [grad addAnimation:wave forKey:@"wave"];

    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(drag:)];
    [bar addGestureRecognizer:drag];

    _btns = [NSMutableArray array];
    CGFloat bSz = 42, gap = (W - 5 * bSz) / 6;
    for (int i = 0; i < 10; i++) {
        int row = i / 5, col = i % 5;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(gap + col * (bSz + gap), 52 + row * (bSz + 8), bSz, bSz);
        [b setTitle:[NSString stringWithFormat:@"%d", i + 1] forState:UIControlStateNormal];
        b.titleLabel.font    = [UIFont boldSystemFontOfSize:15];
        b.backgroundColor    = [UIColor colorWithRed:0.09 green:0.09 blue:0.22 alpha:1];
        b.layer.cornerRadius = bSz / 2;
        b.tag = i;
        [b addTarget:self action:@selector(pick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:b];
        [_btns addObject:b];
    }

    CGFloat afterBtns = 52 + 2 * (bSz + 8) + 6;

    _status = [[UILabel alloc] initWithFrame:CGRectMake(0, afterBtns, W, 22)];
    _status.text          = @"لم يتم الاختيار";
    _status.textAlignment = NSTextAlignmentCenter;
    _status.textColor     = [UIColor colorWithWhite:0.6 alpha:1];
    _status.font          = [UIFont systemFontOfSize:12];
    [self addSubview:_status];

    CGFloat rowY = CGRectGetMaxY(_status.frame) + 8;
    CGFloat rowH = 44;
    CGFloat btnW = (W - 12 - 8 - 12) / 2;

    UIButton *stop = [UIButton buttonWithType:UIButtonTypeCustom];
    stop.frame = CGRectMake(12, rowY, btnW, rowH);
    [stop setTitle:@"إيقاف" forState:UIControlStateNormal];
    stop.titleLabel.font    = [UIFont boldSystemFontOfSize:14];
    stop.backgroundColor    = [UIColor colorWithRed:0.78 green:0.04 blue:0.13 alpha:1];
    stop.layer.cornerRadius = rowH / 2;
    stop.layer.shadowColor  = [UIColor colorWithRed:1.0 green:0.0 blue:0.1 alpha:1].CGColor;
    stop.layer.shadowRadius = 8; stop.layer.shadowOpacity = 0.6f; stop.layer.shadowOffset = CGSizeZero;
    [stop addTarget:self action:@selector(doStop) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:stop];

    _fael = [[FaelBtn alloc] initWithFrame:CGRectMake(12 + btnW + 8, rowY, btnW, rowH)];
    __weak typeof(self) ws = self;
    _fael.onActivate = ^{ [ws doStart]; };
    [self addSubview:_fael];

    CGFloat slY = CGRectGetMaxY(_fael.frame) + 8;
    _rateLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, slY, W, 18)];
    _rateLabel.text          = @"السرعة: 500 ض/ث";
    _rateLabel.textAlignment = NSTextAlignmentCenter;
    _rateLabel.textColor     = [UIColor colorWithWhite:0.75 alpha:1];
    _rateLabel.font          = [UIFont systemFontOfSize:12];
    [self addSubview:_rateLabel];

    _rateSlider = [[UISlider alloc] initWithFrame:CGRectMake(12, slY + 22, W - 24, 30)];
    _rateSlider.minimumValue          = 1;
    _rateSlider.maximumValue          = 1500;
    _rateSlider.value                 = 500;
    _rateSlider.minimumTrackTintColor = [UIColor colorWithRed:0.10 green:0.45 blue:1.0 alpha:1];
    [_rateSlider addTarget:self action:@selector(rateChanged:)
          forControlEvents:UIControlEventValueChanged];
    [self addSubview:_rateSlider];

    CGFloat ctrY = CGRectGetMaxY(_rateSlider.frame) + 6;
    UIButton *qBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    qBtn.frame = CGRectMake(12, ctrY, W - 24, 26);
    [qBtn setTitle:@"قلتش" forState:UIControlStateNormal];
    qBtn.titleLabel.font    = [UIFont boldSystemFontOfSize:13];
    qBtn.backgroundColor    = [UIColor colorWithRed:0.06 green:0.06 blue:0.20 alpha:1];
    qBtn.layer.cornerRadius = 10;
    qBtn.layer.borderWidth  = 0.8;
    qBtn.layer.borderColor  = [UIColor colorWithRed:0.5 green:0.2 blue:1.0 alpha:0.6].CGColor;
    qBtn.layer.shadowColor  = [UIColor colorWithRed:0.5 green:0.0 blue:1.0 alpha:1].CGColor;
    qBtn.layer.shadowRadius = 6; qBtn.layer.shadowOpacity = 0.4f; qBtn.layer.shadowOffset = CGSizeZero;
    [qBtn addTarget:self action:@selector(qultashTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:qBtn];
}

- (void)updateMikeCount:(NSUInteger)count {
    if (_sel < 0)
        _status.text = [NSString stringWithFormat:@"مايكات في الروم: %lu", (unsigned long)count];
}

- (void)rateChanged:(UISlider *)s {
    gClickRate = (NSInteger)s.value;
    _rateLabel.text = [NSString stringWithFormat:@"السرعة: %ld ض/ث", (long)gClickRate];
    if (gClickRunning) startAutoClick(_sel);
}

- (void)pick:(UIButton *)b {
    _sel = b.tag;
    for (UIButton *x in _btns)
        x.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
    b.backgroundColor = [UIColor colorWithRed:0.05 green:0.40 blue:1.0 alpha:1];
    _status.text = [NSString stringWithFormat:@"تم اختيار مايك %ld", (long)(_sel + 1)];
}

- (void)doStart {
    if (_sel < 0) { _status.text = @"اختر مايك أولاً"; return; }
    NSArray *mikes = sortedMikes();
    if (_sel >= (NSInteger)mikes.count) {
        _status.text = [NSString stringWithFormat:@"مايك %ld غير موجود", (long)(_sel + 1)];
        return;
    }
    gClickCount = 0;
    startAutoClick(_sel);
    [_fael setRunning:YES];
    _status.text = [NSString stringWithFormat:@"مايك %ld يعمل", (long)(_sel + 1)];
    broadcastStart(_sel);
}

- (void)doStop {
    gClickRunning = NO;
    gTargetMike   = nil;
    stopAutoClick();
    broadcastStop();
    [_counterTimer invalidate];
    _counterTimer = nil;
    [_fael setRunning:NO];
    NSString *msg = gClickCount > 0
        ? [NSString stringWithFormat:@"توقف عند: %d ضغطة", (int)gClickCount]
        : @"تم الإيقاف";
    _status.text = msg;
    gClickCount = 0;
    for (UIButton *b in _btns)
        b.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.22 alpha:1];
    _sel = -1;
}

- (void)autoStop {
    gClickRunning = NO;
    gTargetMike   = nil;
    stopAutoClick();
    [_counterTimer invalidate];
    _counterTimer = nil;
    [_fael setRunning:NO];
    NSString *saved = (_sel >= 0)
        ? [NSString stringWithFormat:@"⚠ طيرك - مايك %ld محفوظ", (long)(_sel + 1)]
        : @"⚠ طيرك - توقف تلقائي";
    _status.text = gClickCount > 0
        ? [NSString stringWithFormat:@"%@ | %d ض", saved, (int)gClickCount]
        : saved;
    gClickCount = 0;
    dispatch_async(dispatch_get_main_queue(), ^{ self.hidden = NO; });
}

- (void)remoteStart:(NSInteger)micIdx {
    if (gClickRunning) return;
    NSArray *mikes = sortedMikes();
    if (micIdx < 0 || micIdx >= (NSInteger)mikes.count) return;
    _sel = micIdx;
    gClickCount = 0;
    startAutoClick(micIdx);
    [_fael setRunning:YES];
    if (micIdx < (NSInteger)_btns.count) {
        for (UIButton *b in _btns)
            b.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.22 alpha:1];
        ((UIButton *)_btns[micIdx]).backgroundColor = [UIColor colorWithRed:0.05 green:0.40 blue:1.0 alpha:1];
    }
    _status.text = [NSString stringWithFormat:@"مايك %ld يعمل", (long)(micIdx + 1)];
}

- (void)remoteStop {
    if (!gClickRunning) return;
    gClickRunning = NO;
    gTargetMike   = nil;
    stopAutoClick();
    [_fael setRunning:NO];
    _status.text = @"تم الإيقاف";
}

- (void)qultashTapped {
    Class cls = NSClassFromString(@"YallaLite.LTLiveMikeFace")
             ?: NSClassFromString(@"LTLiveMikeFace");
    NSMutableArray *faces = [NSMutableArray array];
    if (cls) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *w in UIApplication.sharedApplication.windows)
            if (w != self.window) [faces addObjectsFromArray:collectViews(w, cls)];
#pragma clang diagnostic pop
    }
    NSString *objTitle = faces.count > 0
        ? [NSString stringWithFormat:@"YallaLite.LTLiveMikeFace %p", (void *)faces.firstObject]
        : @"YallaLite.LTLiveMikeFace";
    NSArray *facesToCall = [faces copy];
    QultashAlert *alert = [[QultashAlert alloc] initWithObjTitle:objTitle onConfirm:^{
        const uint8_t _cxe[] = {0x75,0x0E,0x05,0x05,0x48,0x09,0x0A,0x1F,0x1C,0x1D,0x09,0x0A,0x1C};
        char _cxd[14]; for(int _i=0;_i<13;_i++) _cxd[_i]=(char)(_cxe[_i]^0x5B); _cxd[13]=0;
        SEL sel = sel_registerName(_cxd);
        for (id face in facesToCall) {
            if ([face respondsToSelector:sel])
                ((void(*)(id,SEL))objc_msgSend)(face, sel);
        }
    }];
    [alert show];
}

- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint d = [g translationInView:self.superview];
    CGRect  f = CGRectOffset(self.frame, d.x, d.y);
    CGRect sc = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(f.origin.x, sc.size.width  - f.size.width));
    f.origin.y = MAX(0, MIN(f.origin.y, sc.size.height - f.size.height));
    self.frame = f;
    [g setTranslation:CGPointZero inView:self.superview];
}
@end

// ─── #SWT Helper ──────────────────────────────────────────────────────────

static MicPanel *gPanel;

@interface SWTHelper : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)b;
- (void)dragged:(UIPanGestureRecognizer *)g;
@end
@implementation SWTHelper
+ (instancetype)shared {
    static SWTHelper *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [SWTHelper new]; });
    return s;
}
- (void)tapped:(UIButton *)b    { gPanel.hidden = !gPanel.hidden; }
- (void)dragged:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint d = [g translationInView:v.superview];
    CGRect  f = CGRectOffset(v.frame, d.x, d.y);
    CGRect sc = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(f.origin.x, sc.size.width  - f.size.width));
    f.origin.y = MAX(0, MIN(f.origin.y, sc.size.height - f.size.height));
    v.frame = f;
    [g setTranslation:CGPointZero inView:v.superview];
}
@end

// ─── Pass-through Window ──────────────────────────────────────────────────

@interface PassWin : UIWindow @end
@implementation PassWin
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self.rootViewController.view) ? nil : v;
}
@end

// ─── Entry point ──────────────────────────────────────────────────────────

static PassWin          *gWin;
static UIButton         *gSWTBtn;
static dispatch_source_t gRoomTimer;

static void onRemoteStart(CFNotificationCenterRef c, void *o, CFStringRef name,
                           const void *obj, CFDictionaryRef info) {
    NSString *n = (__bridge NSString *)name;
    NSInteger idx = [n.pathExtension integerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPanel && !gClickRunning) [gPanel remoteStart:idx];
    });
}

static void onRemoteStop(CFNotificationCenterRef c, void *o, CFStringRef name,
                          const void *obj, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPanel) [gPanel remoteStop];
    });
}

static void registerBroadcastListeners(void) {
    CFNotificationCenterRef dc = CFNotificationCenterGetDarwinNotifyCenter();
    NSString *base = @"com.smith101.broadcast.start.";
    for (int i = 0; i < 10; i++) {
        NSString *n = [base stringByAppendingFormat:@"%d", i];
        CFNotificationCenterAddObserver(dc, NULL, onRemoteStart,
            (__bridge CFStringRef)n, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    CFNotificationCenterAddObserver(dc, NULL, onRemoteStop,
        CFSTR("com.smith101.broadcast.stop"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
}

__attribute__((constructor))
static void smith101_load(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        CGRect  sc = UIScreen.mainScreen.bounds;
        CGFloat W  = 280, H = 342;

        gWin = [[PassWin alloc] initWithFrame:sc];
        gWin.windowLevel     = UIWindowLevelAlert + 100;
        gWin.backgroundColor = UIColor.clearColor;

        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = UIColor.clearColor;
        gWin.rootViewController = vc;
        [gWin makeKeyAndVisible];

        gPanel = [[MicPanel alloc] initWithFrame:
            CGRectMake((sc.size.width - W) / 2, 100, W, H)];
        [vc.view addSubview:gPanel];
        gAutoStopBlock = ^{ [gPanel autoStop]; };

        gSWTBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        gSWTBtn.frame              = CGRectMake(sc.size.width - 68, 120, 60, 28);
        gSWTBtn.backgroundColor    = [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:0.85];
        gSWTBtn.layer.cornerRadius = 14;
        gSWTBtn.layer.borderWidth  = 1;
        gSWTBtn.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
        [gSWTBtn setTitle:@"#SWT" forState:UIControlStateNormal];
        gSWTBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        gSWTBtn.hidden = YES;
        [gSWTBtn addTarget:[SWTHelper shared] action:@selector(tapped:)
              forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc]
            initWithTarget:[SWTHelper shared] action:@selector(dragged:)];
        [gSWTBtn addGestureRecognizer:panGR];
        [vc.view addSubview:gSWTBtn];

        gRoomTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                            dispatch_get_main_queue());
        dispatch_source_set_timer(gRoomTimer, DISPATCH_TIME_NOW,
                                  (uint64_t)(0.2 * NSEC_PER_SEC), 0);
        __block BOOL wasInRoom = NO;
        dispatch_source_set_event_handler(gRoomTimer, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSArray *wins = [UIApplication.sharedApplication.windows copy];
#pragma clang diagnostic pop
            for (UIWindow *w in wins) {
                if (w != gWin) {
                    hideLocked(w);
                    hideDecorativeViews(w);
                }
            }
            NSArray *mikes = sortedMikes();
            BOOL inRoom = mikes.count > 0;
            gSWTBtn.hidden = !inRoom;
            if (inRoom) {
                [gPanel updateMikeCount:mikes.count];
            } else if (wasInRoom) {
                [gPanel autoStop];
            }
            wasInRoom = inRoom;
        });
        dispatch_resume(gRoomTimer);
        swizzleHUDIfNeeded();
        registerBroadcastListeners();
    });
}

__attribute__((destructor))
static void smith101_unload(void) {
    if (gRoomTimer) dispatch_source_cancel(gRoomTimer);
    stopAutoClick();
    gWin = nil;
}
