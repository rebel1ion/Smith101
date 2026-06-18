#import <UIKit/UIKit.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// ── Globals ───────────────────────────────────────────────────────────────────
static UIWindow          *_gWin          = nil;
static id                 _gPanel        = nil;
static UIButton          *_gSWTBtn       = nil;
static void              (^_gAutoStopBlock)(void) = nil;
static IMP                _gOrigHUDShow  = NULL;
static dispatch_source_t  _gRoomTimer    = nil;
static dispatch_source_t  _gClickTimer   = nil;
static dispatch_queue_t   _gClickQueue   = nil;
static UIView __weak     *_gTargetMike   = nil;
static BOOL               _gClickRunning = NO;
static NSInteger          _gClickRate    = 500;
static volatile int32_t   _gClickCount   = 0;
static volatile int32_t   _gClickPending = 0;

// ── Forward declarations ──────────────────────────────────────────────────────
static NSArray *_sortedMikes(void);
static NSArray *_collectViews(UIView *root, Class cls);
static void     _startAutoClick(NSInteger idx);
static void     _stopAutoClick(void);
static void     _tapView(UIView *v);
static BOOL     _tapControlInView(UIView *v);
static void     _hideLocked(UIView *v);
static BOOL     _isHideableText(NSString *s);
static BOOL     _hudHasHideableText(id hud);
static void     _swizzleHUDIfNeeded(void);
static void     _registerBroadcastListeners(void);
static void     _broadcastStart(NSInteger idx);
static void     _broadcastStop(void);

// ── QultashAlert ──────────────────────────────────────────────────────────────
@interface QultashAlert : UIView
- (instancetype)initWithObjTitle:(NSString *)title onConfirm:(void(^)(void))block;
- (void)show;
- (void)dismiss;
- (void)confirmTapped:(id)sender;
- (void)dragged:(UIPanGestureRecognizer *)pan;
@end

@implementation QultashAlert {
    void(^_confirmBlock)(void);
}

- (instancetype)initWithObjTitle:(NSString *)title onConfirm:(void(^)(void))block {
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat w = 270, h = 230;
    CGRect f = CGRectMake((screen.size.width - w) / 2, (screen.size.height - h) / 2, w, h);
    self = [super initWithFrame:f];
    if (!self) return nil;
    _confirmBlock = [block copy];
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.75, 0.75);
    self.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.18 alpha:0.97];
    self.layer.cornerRadius = 14;
    self.layer.masksToBounds = NO;
    self.layer.borderColor = [UIColor colorWithRed:0.4 green:0.4 blue:1.0 alpha:0.7].CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.shadowColor = [UIColor colorWithRed:0.3 green:0.3 blue:1.0 alpha:1.0].CGColor;
    self.layer.shadowRadius = 18;
    self.layer.shadowOpacity = 0.12;
    self.layer.shadowOffset = CGSizeZero;

    // Header
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 38)];
    hdr.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.14 alpha:1.0];
    hdr.layer.cornerRadius = 14;
    hdr.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self addSubview:hdr];

    UILabel *hdrLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, 38)];
    hdrLbl.text = @"Smith101";
    hdrLbl.textAlignment = NSTextAlignmentCenter;
    hdrLbl.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:1.0 alpha:0.9];
    hdrLbl.font = [UIFont boldSystemFontOfSize:14];
    [hdr addSubview:hdrLbl];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)];
    [hdr addGestureRecognizer:pan];

    // Title
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 46, w - 28, 20)];
    titleLbl.text = title;
    titleLbl.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0];
    titleLbl.font = [UIFont systemFontOfSize:12];
    titleLbl.numberOfLines = 1;
    titleLbl.adjustsFontSizeToFitWidth = YES;
    [self addSubview:titleLbl];

    // Divider
    UIView *div1 = [[UIView alloc] initWithFrame:CGRectMake(14, 70, w - 28, 0.5)];
    div1.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self addSubview:div1];

    // Info lines
    NSArray *lines = @[
        @"Auto-click for YallaLite",
        @"Slide to start clicking",
        @"Pick mike slot (0-9)",
        @"Rate slider = speed",
        @"Remote via CFNotification"
    ];
    UIColor *lineColors[] = {
        [UIColor colorWithWhite:0.5 alpha:1.0],
        [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:1.0],
        [UIColor colorWithWhite:0.5 alpha:1.0],
        [UIColor colorWithWhite:0.5 alpha:1.0],
        [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:1.0],
    };
    CGFloat y = 78;
    for (int i = 0; i < 5; i++) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, y, w - 28, 16)];
        l.text = lines[i];
        l.textColor = lineColors[i];
        l.font = [UIFont systemFontOfSize:10];
        [self addSubview:l];
        y += 18;
    }

    // Divider
    UIView *div2 = [[UIView alloc] initWithFrame:CGRectMake(14, y + 2, w - 28, 0.5)];
    div2.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self addSubview:div2];
    y += 10;

    // Buttons
    CGFloat bw = (w - 32) / 2;
    UIButton *ok = [UIButton buttonWithType:UIButtonTypeCustom];
    ok.frame = CGRectMake(14, y, bw, 36);
    [ok setTitle:@"✓ Confirm" forState:UIControlStateNormal];
    ok.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    ok.backgroundColor = [UIColor colorWithRed:0.6 green:0.15 blue:1.0 alpha:1.0];
    ok.layer.cornerRadius = 18;
    ok.layer.shadowColor = [UIColor colorWithRed:1.0 green:0 blue:0.7 alpha:1.0].CGColor;
    ok.layer.shadowRadius = 8;
    ok.layer.shadowOpacity = 0.15;
    ok.layer.shadowOffset = CGSizeZero;
    [ok addTarget:self action:@selector(confirmTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:ok];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel.frame = CGRectMake(14 + bw + 8, y, bw, 36);
    [cancel setTitle:@"✕ Cancel" forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    cancel.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.24 alpha:1.0];
    cancel.layer.cornerRadius = 18;
    cancel.layer.borderWidth = 0.7;
    cancel.layer.borderColor = [UIColor colorWithRed:0.4 green:0.4 blue:1.0 alpha:0.5].CGColor;
    [cancel addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:cancel];

    return self;
}

- (void)confirmTapped:(id)sender {
    if (_confirmBlock) _confirmBlock();
    [self dismiss];
}

- (void)dragged:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.superview];
    CGRect f = self.frame;
    CGRect screen = [UIScreen mainScreen].bounds;
    f.origin.x = fmax(0, fmin(f.origin.x + t.x, screen.size.width  - f.size.width));
    f.origin.y = fmax(0, fmin(f.origin.y + t.y, screen.size.height - f.size.height));
    self.frame = f;
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)show {
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.75, 0.75);
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL fin) {
        [self removeFromSuperview];
    }];
}
@end


// ── FaelBtn ───────────────────────────────────────────────────────────────────
@interface FaelBtn : UIControl
@property (nonatomic, copy) void(^onActivate)(void);
- (CGFloat)maxX;
- (void)setRunning:(BOOL)running;
@end

@implementation FaelBtn {
    UILabel *_lbl;
    UIView  *_thumb;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor colorWithRed:0.07 green:0.5 blue:0.95 alpha:1.0];
    self.layer.cornerRadius = frame.size.height / 2;
    self.clipsToBounds = YES;

    _lbl = [[UILabel alloc] initWithFrame:self.bounds];
    _lbl.text = @"▶";
    _lbl.textColor = [UIColor whiteColor];
    _lbl.textAlignment = NSTextAlignmentCenter;
    _lbl.font = [UIFont boldSystemFontOfSize:14];
    [self addSubview:_lbl];

    CGFloat sz = frame.size.height - 8;
    _thumb = [[UIView alloc] initWithFrame:CGRectMake(4, 4, sz, sz)];
    _thumb.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    _thumb.layer.cornerRadius = sz / 2;
    [self addSubview:_thumb];
    return self;
}

- (CGFloat)maxX {
    return self.bounds.size.width - _thumb.bounds.size.width - 4;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGFloat tx = [touch locationInView:self].x;
    CGFloat newX = tx - _thumb.bounds.size.width / 2.0;
    newX = fmax(4, fmin(newX, [self maxX]));
    CGRect f = _thumb.frame;
    f.origin.x = newX;
    _thumb.frame = f;
    CGFloat span = fmax(1.0, [self maxX] - 4.0);
    _lbl.alpha = 1.0 - ((newX - 4.0) / span) * 0.5;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGFloat thumbX = _thumb.frame.origin.x;
    CGFloat span   = fmax(1.0, [self maxX] - 4.0);
    CGFloat pct    = (thumbX - 4.0) / span;
    if (pct >= 0.7 && _onActivate) _onActivate();
    [UIView animateWithDuration:0.3 animations:^{
        CGRect f = _thumb.frame;
        f.origin.x = 4;
        _thumb.frame = f;
        _lbl.alpha = 1.0;
    }];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)setRunning:(BOOL)running {
    self.userInteractionEnabled = !running;
    if (running) {
        self.backgroundColor = [UIColor colorWithRed:0.9 green:0.35 blue:0.1 alpha:1.0];
        _lbl.text = @"◼";
        [UIView animateWithDuration:0.3 animations:^{
            CGRect f = _thumb.frame;
            f.origin.x = [self maxX];
            _thumb.frame = f;
        }];
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.07 green:0.5 blue:0.95 alpha:1.0];
        _lbl.text = @"▶";
        _lbl.alpha = 1.0;
        [UIView animateWithDuration:0.3 animations:^{
            CGRect f = _thumb.frame;
            f.origin.x = 4;
            _thumb.frame = f;
        }];
    }
}
@end


// ── MicPanel ──────────────────────────────────────────────────────────────────
@interface MicPanel : UIView
- (void)build;
- (void)updateMikeCount:(NSUInteger)count;
- (void)rateChanged:(UISlider *)slider;
- (void)pick:(UIButton *)btn;
- (void)doStart;
- (void)doStop;
- (void)autoStop;
- (void)remoteStart:(NSInteger)idx;
- (void)remoteStop;
- (void)qultashTapped;
- (void)drag:(UIPanGestureRecognizer *)pan;
@end

@implementation MicPanel {
    NSInteger          _sel;
    UILabel           *_titleMask;
    dispatch_source_t  _counterTimer;
    FaelBtn           *_fael;
    UISlider          *_rateSlider;
    UILabel           *_rateLabel;
    UILabel           *_status;
    NSMutableArray    *_btns;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _sel = -1;
    self.hidden = YES;
    [self build];
    return self;
}

- (void)build {
    CGFloat w = self.bounds.size.width;

    // Panel style
    self.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:0.97];
    self.layer.cornerRadius = 14;
    self.layer.masksToBounds = NO;
    self.layer.borderColor = [UIColor colorWithRed:0.35 green:0.35 blue:1.0 alpha:0.85].CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.shadowColor = [UIColor colorWithRed:0.2 green:0.2 blue:1.0 alpha:1.0].CGColor;
    self.layer.shadowRadius = 18;
    self.layer.shadowOpacity = 0.14;
    self.layer.shadowOffset = CGSizeMake(0, 4);

    // Header container
    UIView *hdrBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 40)];
    hdrBg.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.14 alpha:1.0];
    hdrBg.layer.cornerRadius = 14;
    hdrBg.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self addSubview:hdrBg];

    // Gradient shimmer layer
    UIView *gradView = [[UIView alloc] initWithFrame:hdrBg.bounds];
    [hdrBg addSubview:gradView];

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = CGRectMake(0, 0, w * 3, 40);
    grad.startPoint = CGPointMake(0, 0.5);
    grad.endPoint   = CGPointMake(1, 0.5);
    grad.colors = @[
        (id)[UIColor colorWithRed:0.35 green:0.1  blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.1  green:0.7  blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:1.0  green:0.15 blue:0.4 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.35 green:0.1  blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.1  green:0.7  blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:1.0  green:0.15 blue:0.4 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.35 green:0.1  blue:1.0 alpha:1.0].CGColor,
    ];
    [gradView.layer addSublayer:grad];

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.fromValue   = @0;
    anim.toValue     = @(-w);
    anim.duration    = 2.5;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [grad addAnimation:anim forKey:@"wave"];

    // Title label masked over the gradient
    _titleMask = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, 40)];
    _titleMask.text          = @"S";
    _titleMask.textAlignment = NSTextAlignmentCenter;
    _titleMask.textColor     = [UIColor whiteColor];
    _titleMask.font          = [UIFont boldSystemFontOfSize:14];
    gradView.layer.mask = _titleMask.layer;

    // Pan gesture for dragging panel
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [hdrBg addGestureRecognizer:pan];

    // Mike buttons (0-9) in 2 rows of 5
    _btns = [NSMutableArray array];
    CGFloat btnSz = 42;
    CGFloat hGap  = (w - 210.0) / 6.0;
    for (int i = 0; i < 10; i++) {
        int col = i % 5;
        int row = i / 5;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat bx = hGap + (btnSz + hGap) * col;
        CGFloat by = (btnSz + 8) * row + 52.0;
        btn.frame = CGRectMake(bx, by, btnSz, btnSz);
        [btn setTitle:[NSString stringWithFormat:@"%d", i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        btn.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0];
        btn.layer.cornerRadius = btnSz / 2;
        btn.tag = i;
        [btn addTarget:self action:@selector(pick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [_btns addObject:btn];
    }

    // Status label
    CGFloat statusY = (btnSz + 8) * 2 + 52 + 6;
    _status = [[UILabel alloc] initWithFrame:CGRectMake(0, statusY, w, 22)];
    _status.text          = @"--";
    _status.textAlignment = NSTextAlignmentCenter;
    _status.textColor     = [UIColor colorWithWhite:0.6 alpha:1.0];
    _status.font          = [UIFont systemFontOfSize:12];
    [self addSubview:_status];

    CGFloat afterStatus = CGRectGetMaxY(_status.frame) + 8;
    CGFloat btnW = (w - 12 - 8 - 12) / 2;

    // Stop button (left)
    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    stopBtn.frame = CGRectMake(12, afterStatus, btnW, 44);
    [stopBtn setTitle:@"⏹ Stop" forState:UIControlStateNormal];
    stopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    stopBtn.backgroundColor = [UIColor colorWithRed:0.22 green:0.07 blue:0.07 alpha:1.0];
    stopBtn.layer.cornerRadius = 22;
    stopBtn.layer.shadowColor  = [UIColor colorWithRed:1.0 green:0 blue:0.5 alpha:1.0].CGColor;
    stopBtn.layer.shadowRadius = 8;
    stopBtn.layer.shadowOpacity = 0.15;
    stopBtn.layer.shadowOffset = CGSizeZero;
    [stopBtn addTarget:self action:@selector(doStop) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:stopBtn];

    // FaelBtn — slide to start (right)
    FaelBtn *fael = [[FaelBtn alloc] initWithFrame:CGRectMake(btnW + 12 + 8, afterStatus, btnW, 44)];
    _fael = fael;
    __weak MicPanel *ws = self;
    _fael.onActivate = ^{ [ws doStart]; };
    [self addSubview:_fael];

    // Rate label
    CGFloat afterFael = CGRectGetMaxY(_fael.frame) + 8;
    _rateLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, afterFael, w, 18)];
    _rateLabel.text          = [NSString stringWithFormat:@"Rate: %ld/s", (long)_gClickRate];
    _rateLabel.textAlignment = NSTextAlignmentCenter;
    _rateLabel.textColor     = [UIColor colorWithWhite:0.75 alpha:1.0];
    _rateLabel.font          = [UIFont systemFontOfSize:12];
    [self addSubview:_rateLabel];

    // Rate slider
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(12, afterFael + 22, w - 24, 30)];
    _rateSlider = slider;
    slider.minimumValue = 1;
    slider.maximumValue = 1500;
    slider.value        = 500;
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.35 green:0.35 blue:1.0 alpha:1.0];
    [slider addTarget:self action:@selector(rateChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:slider];

    // Info / qultash button
    CGFloat afterSlider = CGRectGetMaxY(slider.frame) + 6;
    UIButton *infoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    infoBtn.frame = CGRectMake(12, afterSlider, w - 24, 26);
    [infoBtn setTitle:@"ℹ Info" forState:UIControlStateNormal];
    infoBtn.titleLabel.font  = [UIFont boldSystemFontOfSize:11];
    infoBtn.backgroundColor  = [UIColor colorWithRed:0.14 green:0.14 blue:0.18 alpha:1.0];
    infoBtn.layer.cornerRadius = 10;
    infoBtn.layer.borderWidth  = 0.5;
    infoBtn.layer.borderColor  = [UIColor colorWithRed:0.4 green:0.4 blue:1.0 alpha:0.4].CGColor;
    infoBtn.layer.shadowColor  = [UIColor colorWithRed:0.4 green:0.0 blue:1.0 alpha:1.0].CGColor;
    infoBtn.layer.shadowRadius = 6;
    infoBtn.layer.shadowOpacity = 0.18;
    infoBtn.layer.shadowOffset  = CGSizeZero;
    [infoBtn addTarget:self action:@selector(qultashTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:infoBtn];
}

- (void)updateMikeCount:(NSUInteger)count {
    if (_sel < 0) {
        _status.text = [NSString stringWithFormat:@"Mikes: %lu", (unsigned long)count];
    }
}

- (void)rateChanged:(UISlider *)slider {
    _gClickRate = (NSInteger)slider.value;
    _rateLabel.text = [NSString stringWithFormat:@"Rate: %ld/s", (long)_gClickRate];
    if (_gClickRunning) _startAutoClick(_sel);
}

- (void)pick:(UIButton *)btn {
    _sel = btn.tag;
    for (UIButton *b in _btns) {
        b.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0];
    }
    btn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:1.0 alpha:1.0];
    _status.text = [NSString stringWithFormat:@"Mike: %ld", (long)_sel];
}

- (void)doStart {
    if (_sel < 0) {
        _status.text = @"Pick a mike first!";
        return;
    }
    NSArray *mikes = _sortedMikes();
    if ((NSUInteger)_sel >= mikes.count) {
        _status.text = [NSString stringWithFormat:@"No mike %ld found", (long)_sel];
        return;
    }
    _startAutoClick(_sel);
    [_fael setRunning:YES];
    _status.text = [NSString stringWithFormat:@"Clicking #%ld", (long)_sel];
    _broadcastStart(_sel);
}

- (void)doStop {
    _stopAutoClick();
    [_fael setRunning:NO];
    _status.text = @"Stopped";
    _broadcastStop();
}

- (void)autoStop {
    _stopAutoClick();
    [_fael setRunning:NO];
    _status.text = @"Auto-stopped";
}

- (void)remoteStart:(NSInteger)idx {
    if (idx >= 0 && (NSUInteger)idx < _btns.count) {
        [self pick:_btns[idx]];
    }
    if (_gClickRunning) return;
    NSArray *mikes = _sortedMikes();
    if ((NSUInteger)idx >= mikes.count) return;
    _startAutoClick(idx);
    [_fael setRunning:YES];
    _status.text = [NSString stringWithFormat:@"Remote #%ld", (long)idx];
}

- (void)remoteStop {
    [self autoStop];
}

- (void)qultashTapped {
    __weak MicPanel *ws = self;
    QultashAlert *alert = [[QultashAlert alloc]
        initWithObjTitle:@"Stop auto-click?"
               onConfirm:^{ [ws doStop]; }];
    [self.superview addSubview:alert];
    [alert show];
}

- (void)drag:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.superview];
    CGRect f  = self.frame;
    CGRect screen = [UIScreen mainScreen].bounds;
    f.origin.x = fmax(0, fmin(f.origin.x + t.x, screen.size.width  - f.size.width));
    f.origin.y = fmax(0, fmin(f.origin.y + t.y, screen.size.height - f.size.height));
    self.frame = f;
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)dealloc {
    if (_counterTimer) dispatch_source_cancel(_counterTimer);
}
@end


// ── SWTHelper ─────────────────────────────────────────────────────────────────
@interface SWTHelper : NSObject
+ (instancetype)shared;
- (void)tapped:(id)sender;
- (void)dragged:(UIPanGestureRecognizer *)pan;
@end

@implementation SWTHelper
+ (instancetype)shared {
    static SWTHelper *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [SWTHelper new]; });
    return s;
}
- (void)tapped:(id)sender {
    [_gPanel setHidden:![_gPanel isHidden]];
}
- (void)dragged:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    CGPoint t = [pan translationInView:v.superview];
    CGRect f  = v.frame;
    CGRect screen = [UIScreen mainScreen].bounds;
    f.origin.x = fmax(0, fmin(f.origin.x + t.x, screen.size.width  - f.size.width));
    f.origin.y = fmax(0, fmin(f.origin.y + t.y, screen.size.height - f.size.height));
    v.frame = f;
    [pan setTranslation:CGPointZero inView:v.superview];
}
@end


// ── PassWin ───────────────────────────────────────────────────────────────────
@interface PassWin : UIWindow
@end
@implementation PassWin
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self.rootViewController.view) return nil;
    return hit;
}
@end


// ── C helpers ─────────────────────────────────────────────────────────────────
static NSArray *_collectViews(UIView *root, Class cls) {
    NSMutableArray *out = [NSMutableArray array];
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:cls]) [out addObject:v];
        [out addObjectsFromArray:_collectViews(v, cls)];
    }
    return out;
}

static NSArray *_sortedMikes(void) {
    NSMutableArray *mikes = [NSMutableArray array];
    Class cls = NSClassFromString(@"YallaLite_LTMikeElement");
    if (!cls) cls = NSClassFromString(@"LTMikeElement");
    if (!cls) cls = NSClassFromString(@"YallaLite_LTLiveMikeFace");
    if (!cls) cls = NSClassFromString(@"LTLiveMikeFace");
    if (!cls) return mikes;

    NSArray *allWindows = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    allWindows = [UIApplication sharedApplication].windows;
#pragma clang diagnostic pop
    for (UIWindow *win in allWindows) {
        if (win == _gWin) continue;
        [mikes addObjectsFromArray:_collectViews(win, cls)];
    }

    BOOL rtl = ([UIApplication sharedApplication].userInterfaceLayoutDirection
                == UIUserInterfaceLayoutDirectionRightToLeft);

    [mikes sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGRect ra = [a.superview convertRect:a.frame toView:nil];
        CGRect rb = [b.superview convertRect:b.frame toView:nil];
        if (fabs(ra.origin.y - rb.origin.y) <= 30.0) {
            if (rtl) return ra.origin.x > rb.origin.x ? NSOrderedAscending : NSOrderedDescending;
            else     return ra.origin.x < rb.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }
        return ra.origin.y < rb.origin.y ? NSOrderedAscending : NSOrderedDescending;
    }];
    return mikes;
}

static BOOL _tapControlInView(UIView *view) {
    if ([view isKindOfClass:[UIControl class]]) {
        [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
        return YES;
    }
    for (UIView *sub in view.subviews) {
        if (_tapControlInView(sub)) return YES;
    }
    return NO;
}

static void _tapView(UIView *view) {
    if (!view) return;
    if (_tapControlInView(view)) return;
    for (UIGestureRecognizer *gr in view.gestureRecognizers) {
        if (![gr isKindOfClass:[UITapGestureRecognizer class]]) continue;
        NSArray *targets = nil;
        @try { targets = [gr valueForKey:@"_targets"]; }
        @catch (NSException *e) {}
        for (id tgtWrapper in targets) {
            id target = nil, actionStr = nil;
            @try {
                target = [tgtWrapper valueForKey:@"_target"];
                actionStr = [tgtWrapper valueForKey:@"_action"];
            }
            @catch (NSException *e) {}
            SEL sel = [actionStr isKindOfClass:[NSString class]] ? NSSelectorFromString(actionStr) : NULL;
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

static void _startAutoClick(NSInteger idx) {
    _stopAutoClick();
    NSArray *mikes = _sortedMikes();
    if ((NSUInteger)idx >= mikes.count) return;

    _gTargetMike   = mikes[idx];
    _gClickRunning = YES;

    if (!_gClickQueue) {
        _gClickQueue = dispatch_queue_create("smith101.clicker", NULL);
    }

    NSInteger rate   = MAX(1, _gClickRate);
    uint64_t  itvl   = (uint64_t)(1000000000ULL / (uint64_t)rate);

    _gClickTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _gClickQueue);
    dispatch_source_set_timer(_gClickTimer, DISPATCH_TIME_NOW, itvl, 0);
    dispatch_source_set_event_handler(_gClickTimer, ^{
        if (!_gClickRunning) return;
        if (_gClickPending != 0) return;
        if (__sync_bool_compare_and_swap(&_gClickPending, 0, 1)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_gClickRunning) {
                    UIView *tgt = _gTargetMike;
                    if (tgt && tgt.window) {
                        [UIView performWithoutAnimation:^{ _tapView(tgt); }];
                        __sync_fetch_and_add(&_gClickCount, 1);
                    } else {
                        if (_gAutoStopBlock) _gAutoStopBlock();
                        else _stopAutoClick();
                    }
                }
                _gClickPending = 0;
            });
        }
    });
    dispatch_resume(_gClickTimer);
}

static void _stopAutoClick(void) {
    _gClickRunning = NO;
    _gClickPending = 0;
    if (_gClickTimer) {
        dispatch_source_cancel(_gClickTimer);
        _gClickTimer = nil;
    }
    _gTargetMike = nil;
}

static void _broadcastStart(NSInteger idx) {
    CFNotificationCenterRef c = CFNotificationCenterGetDarwinNotifyCenter();
    NSString *name = [NSString stringWithFormat:@"com.smith101.broadcast.start.%ld", (long)idx];
    CFNotificationCenterPostNotification(c, (__bridge CFStringRef)name, NULL, NULL, YES);
}

static void _broadcastStop(void) {
    CFNotificationCenterRef c = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(c, CFSTR("com.smith101.broadcast.stop"), NULL, NULL, YES);
}

static BOOL _isHideableText(NSString *text) {
    if (!text || text.length == 0) return NO;
    NSString *lower = [text lowercaseString];
    for (NSString *kw in @[@"miclocked", @"lockedbyowner", @"alreadyonmic",
                           @"you are already on", @"connectionlost", @"networkconnection"]) {
        if ([lower containsString:kw]) return YES;
    }
    return NO;
}

static void _hideLocked(UIView *root) {
    for (UIView *v in root.subviews) {
        NSString *text = nil;
        if ([v isKindOfClass:[UILabel class]])    text = ((UILabel *)v).text;
        else if ([v isKindOfClass:[UITextView class]]) text = ((UITextView *)v).text;
        if (_isHideableText(text)) {
            v.hidden = YES;
            v.alpha  = 0;
            if (v.superview) { v.superview.hidden = YES; v.superview.alpha = 0; }
        }
        _hideLocked(v);
    }
}

static BOOL _hudHasHideableText(id hud) {
    return _isHideableText([hud valueForKeyPath:@"label.text"])
        || _isHideableText([hud valueForKeyPath:@"detailsLabel.text"])
        || _isHideableText([hud valueForKey:@"labelText"])
        || _isHideableText([hud valueForKey:@"detailsLabelText"]);
}

static void _swizzleHUDIfNeeded(void) {
    Class cls = NSClassFromString(@"MBProgressHUD");
    if (!cls) return;
    SEL sel = NSSelectorFromString(@"showAnimated:");
    if (!sel) sel = NSSelectorFromString(@"show:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    SEL capSel = sel;
    IMP newImp = imp_implementationWithBlock(^(id self, BOOL animated) {
        if (!_hudHasHideableText(self) && _gOrigHUDShow)
            ((void(*)(id,SEL,BOOL))_gOrigHUDShow)(self, capSel, animated);
    });
    _gOrigHUDShow = method_setImplementation(m, newImp);
}

static void _onRemoteStart(CFNotificationCenterRef c, void *o,
                           CFStringRef name, const void *obj, CFDictionaryRef info) {
    NSString *n   = (__bridge NSString *)name;
    NSInteger idx = [n.pathExtension integerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_gPanel && !_gClickRunning) [(MicPanel *)_gPanel remoteStart:idx];
    });
}

static void _onRemoteStop(CFNotificationCenterRef c, void *o,
                          CFStringRef name, const void *obj, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_gPanel) [(MicPanel *)_gPanel remoteStop];
    });
}

static void _registerBroadcastListeners(void) {
    CFNotificationCenterRef c = CFNotificationCenterGetDarwinNotifyCenter();
    for (int i = 0; i < 10; i++) {
        NSString *n = [NSString stringWithFormat:@"com.smith101.broadcast.start.%d", i];
        CFNotificationCenterAddObserver(c, NULL, _onRemoteStart,
                                        (__bridge CFStringRef)n, NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    CFNotificationCenterAddObserver(c, NULL, _onRemoteStop,
                                    CFSTR("com.smith101.broadcast.stop"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}


// ── Constructor / Destructor ──────────────────────────────────────────────────
__attribute__((constructor)) static void _smith101_load(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat pw = 280, ph = 342;

        PassWin *win = [[PassWin alloc] initWithFrame:screen];
        _gWin = win;
        win.windowLevel = UIWindowLevelAlert + 100;
        win.backgroundColor = [UIColor clearColor];

        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        win.rootViewController = vc;
        [win makeKeyAndVisible];

        MicPanel *panel = [[MicPanel alloc]
            initWithFrame:CGRectMake((screen.size.width - pw) / 2, 100, pw, ph)];
        _gPanel = panel;
        [vc.view addSubview:panel];

        _gAutoStopBlock = ^{ [(MicPanel *)_gPanel autoStop]; };

        // Floating toggle button
        UIButton *swt = [UIButton buttonWithType:UIButtonTypeCustom];
        _gSWTBtn = swt;
        swt.frame = CGRectMake(screen.size.width - 68, 0, 60, 28);
        swt.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:0.9];
        swt.layer.cornerRadius = 14;
        swt.layer.masksToBounds = YES;
        swt.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.45].CGColor;
        swt.layer.borderWidth = 0.5;
        [swt setTitle:@"SWT" forState:UIControlStateNormal];
        swt.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        swt.hidden = YES;

        SWTHelper *helper = [SWTHelper shared];
        [swt addTarget:helper action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc]
            initWithTarget:helper action:@selector(dragged:)];
        [swt addGestureRecognizer:panGR];
        [vc.view addSubview:swt];

        // Room timer — fires every 200ms on main queue
        _gRoomTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                             dispatch_get_main_queue());
        dispatch_source_set_timer(_gRoomTimer, DISPATCH_TIME_NOW, 200000000ULL, 0);

        static BOOL prevHadMikes = NO;
        dispatch_source_set_event_handler(_gRoomTimer, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSArray *roomWindows = [UIApplication sharedApplication].windows;
#pragma clang diagnostic pop
            for (UIWindow *w in roomWindows) {
                if (w != _gWin) _hideLocked(w);
            }
            NSArray *mikes = _sortedMikes();
            BOOL hasMikes = mikes.count > 0;
            _gSWTBtn.hidden = !hasMikes;
            if (hasMikes) {
                [(MicPanel *)_gPanel updateMikeCount:mikes.count];
            } else if (prevHadMikes) {
                [(MicPanel *)_gPanel autoStop];
            }
            prevHadMikes = hasMikes;
        });
        dispatch_resume(_gRoomTimer);

        _swizzleHUDIfNeeded();
        _registerBroadcastListeners();
    });
}

__attribute__((destructor)) static void _smith101_unload(void) {
    if (_gRoomTimer) { dispatch_source_cancel(_gRoomTimer); _gRoomTimer = nil; }
    _stopAutoClick();
    _gWin = nil;
}
