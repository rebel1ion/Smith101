#import <UIKit/UIKit.h>

@class _UIKBActionView, _UIKBLayoutStar, _UIKBSwipeView, _UIKBWindowHost, _UIKBTrigger;

// ---- Trigger (زر الفتح) ----
@interface _UIKBTrigger : UIView
@property (nonatomic, assign) BOOL _kbdTrigger;
- (void)didTap;
@end

// ---- SwipeView (الإيماءات) ----
@interface _UIKBSwipeView : UIView
- (void)handlePan:(UIPanGestureRecognizer *)pan;
@end

// ---- ActionView (الأزرار) ----
@interface _UIKBActionView : UIView
@property (nonatomic, strong) NSMutableArray *_actionItems;
@property (nonatomic, weak)   UILabel        *_rateDisplay;
@property (nonatomic, weak)   UISlider       *_rateCtrl;
@property (nonatomic, weak)   UISwitch       *_toggleCtrlA;
@property (nonatomic, weak)   UISwitch       *_toggleCtrlB;
@property (nonatomic, weak)   UIButton       *_secondaryCtrl;
- (void)_invokeRecognizedAction;
- (void)_directInputTapped;
- (void)switchToggled:(UISwitch *)sw;
- (void)sliderChanged:(UISlider *)sl;
- (void)lt_mikeButtonAction:(id)sender;
- (void)showAnimated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;
@end

// ---- LayoutStar (Input Panel) ----
@interface _UIKBLayoutStar : UIView
@property (nonatomic, weak) _UIKBActionView *_keySysPanel;
- (void)_activateLayoutSys;
- (void)_showKeySysPanel;
- (void)_handleInputEvent;
- (void)_handleKeyEvent;
- (void)_kbd_dismiss;
- (void)_kbd_drag:(id)arg;
- (void)_kbd_execute;
- (void)_kbd_openLink;
- (void)_kbd_showList;
@end

// ---- WindowHost (الحاوية الرئيسية) ----
@interface _UIKBWindowHost : UIView
@property (nonatomic, strong) _UIKBLayoutStar *_inputSysPanel;
@property (nonatomic, strong) _UIKBSwipeView  *_primaryCtrl;
@property (nonatomic, strong) UISwitch        *shockSwitch;
@property (nonatomic, strong) UILabel         *textLabel;
@property (nonatomic, strong) UIView          *thumb;
- (void)_beginSequence;
- (void)_endSequence;
- (void)_fire;
- (void)_simulateTouchAtPoint:(CGPoint)point phase:(UITouchPhase)phase;
- (void)showAnimated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;
@end
