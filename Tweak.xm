#import <UIKit/UIKit.h>
#import <substrate.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <mach-o/dyld.h>
#import "RBXPanel.h"

// ============================================================
//  MARK: - Anti-Detection
// ============================================================

static BOOL rbx_isFridaRunning(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && (strstr(name, "frida") || strstr(name, "FridaGadget"))) {
            return YES;
        }
    }
    return NO;
}

// ============================================================
//  MARK: - Network
// ============================================================

static int rbx_sock = -1;

static void rbx_connect(void) {
    rbx_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (rbx_sock < 0) return;

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons(7890); // عدّل البورت
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");

    int opt = 1;
    setsockopt(rbx_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    if (connect(rbx_sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(rbx_sock);
        rbx_sock = -1;
    }
}

// ============================================================
//  MARK: - Main Panel (WindowHost)
// ============================================================

static _UIKBWindowHost *rbx_mainPanel = nil;

@implementation _UIKBWindowHost {
    UILabel  *_rateDisplayLabel;
    UISlider *_rateCtrl;
    UISwitch *_toggleCtrlA;
    UISwitch *_toggleCtrlB;
    BOOL      _isRunning;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.layer.cornerRadius = 12;
    self.layer.borderWidth  = 1;
    self.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    self.clipsToBounds = YES;

    [self _setupUI];
    return self;
}

- (void)_setupUI {
    // Rate Display
    _rateDisplayLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 120, 20)];
    _rateDisplayLabel.textColor = [UIColor whiteColor];
    _rateDisplayLabel.font      = [UIFont systemFontOfSize:12];
    _rateDisplayLabel.text      = @"Rate: 1.0";
    [self addSubview:_rateDisplayLabel];

    // Toggle A
    _toggleCtrlA = [[UISwitch alloc] init];
    _toggleCtrlA.onTintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1];
    [_toggleCtrlA addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:_toggleCtrlA];

    // Toggle B
    _toggleCtrlB = [[UISwitch alloc] init];
    _toggleCtrlB.onTintColor = [UIColor colorWithRed:0.8 green:0.4 blue:0.2 alpha:1];
    [_toggleCtrlB addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:_toggleCtrlB];

    // Rate Slider
    _rateCtrl = [[UISlider alloc] initWithFrame:CGRectMake(10, 40, self.bounds.size.width - 20, 30)];
    _rateCtrl.minimumValue = 0.1;
    _rateCtrl.maximumValue = 10.0;
    _rateCtrl.value        = 1.0;
    _rateCtrl.minimumTrackTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:1];
    [_rateCtrl addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:_rateCtrl];

    // Drag gesture
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint delta = [pan translationInView:self.superview];
    self.center   = CGPointMake(self.center.x + delta.x, self.center.y + delta.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)switchToggled:(UISwitch *)sw {
    // TODO: منطقك هنا
}

- (void)sliderChanged:(UISlider *)sl {
    _rateDisplayLabel.text = [NSString stringWithFormat:@"Rate: %.1f", sl.value];
}

- (void)_beginSequence {
    if (rbx_sock < 0) rbx_connect();
    _isRunning = YES;
    [self _fire];
}

- (void)_endSequence {
    _isRunning = NO;
}

- (void)_fire {
    if (!_isRunning) return;
    // TODO: منطق الـ fire
    NSTimeInterval delay = 1.0 / MAX(0.1, _rateCtrl.value);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self _fire];
    });
}

- (void)_simulateTouchAtPoint:(CGPoint)point phase:(UITouchPhase)phase {
    // TODO: منطق محاكاة اللمس
}

- (void)showAnimated:(BOOL)animated {
    self.hidden = NO;
    if (animated) {
        self.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{ self.alpha = 1; }];
    }
}

- (void)hideAnimated:(BOOL)animated {
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{ self.alpha = 0; }
                         completion:^(BOOL f){ self.hidden = YES; }];
    } else {
        self.hidden = YES;
    }
}

@end

// ============================================================
//  MARK: - Trigger Button
// ============================================================

@implementation _UIKBTrigger

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor    = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.9];
    self.layer.cornerRadius = frame.size.width / 2;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap)];
    [self addGestureRecognizer:tap];
    return self;
}

- (void)didTap {
    if (rbx_mainPanel.hidden) {
        [rbx_mainPanel showAnimated:YES];
    } else {
        [rbx_mainPanel hideAnimated:YES];
    }
}

@end

// ============================================================
//  MARK: - Hooks
// ============================================================

%hook UIApplication

- (void)_run {
    %orig;
}

%end

// ============================================================
//  MARK: - Constructor
// ============================================================

%ctor {
    if (rbx_isFridaRunning()) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        UIWindow *win = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                win = ((UIWindowScene *)scene).windows.firstObject;
                break;
            }
        }

        if (!win) return;

        // Panel
        rbx_mainPanel = [[_UIKBWindowHost alloc] initWithFrame:CGRectMake(20, 100, 200, 160)];
        rbx_mainPanel.hidden = YES;
        [win addSubview:rbx_mainPanel];

        // Trigger
        _UIKBTrigger *trigger = [[_UIKBTrigger alloc] initWithFrame:CGRectMake(win.bounds.size.width - 60, 120, 44, 44)];
        [win addSubview:trigger];
        [win bringSubviewToFront:trigger];
    });
}
