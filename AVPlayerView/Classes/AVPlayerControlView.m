//
//  AVPlayerControlView.m
//  AVPlayerView
//
//  Created by ChoJaehyun on 2016. 8. 1..
//  Copyright © 2016년 com.skswhwo. All rights reserved.
//

#import "AVPlayerControlView.h"
#import "BufferSpinnerView.h"

@interface AVPlayerControlView ()
{
    NSTimer *hideTimer;
    CAGradientLayer *_gradientLayer;
    
    dispatch_once_t once;
    
    BufferSpinnerView *spinnerView;
}
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIView *bottomControlView;


@property (weak, nonatomic) IBOutlet UIButton *viewModeButton;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *endTimeLabel;
@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation AVPlayerControlView

+ (AVPlayerControlView *)getControlView
{
    NSBundle *bundle = [NSBundle bundleForClass:[AVPlayerControlView class]];
    NSArray *views = [bundle loadNibNamed:@"AVPlayerControlView" owner:nil options:nil];
    AVPlayerControlView *view = [views objectAtIndex:0];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

- (void)dealloc
{
    [self removeObserver];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.backgroundColor = [UIColor clearColor];
    [[UISlider appearance] setThumbImage:[UIImage imageNamed:@"video_circle_default"] forState:UIControlStateNormal];
    [[UISlider appearance] setThumbImage:[UIImage imageNamed:@"video_circle_pressed"] forState:UIControlStateHighlighted];
    
    _gradientLayer = [CAGradientLayer layer];
    [self.bottomControlView.layer insertSublayer:_gradientLayer atIndex:0];
    _gradientLayer.colors = @[(id)[[UIColor blackColor] colorWithAlphaComponent:0].CGColor,(id)[[UIColor blackColor] colorWithAlphaComponent:0.54].CGColor];
    
    spinnerView = [[BufferSpinnerView alloc] initWithFrame:self.actionButton.bounds];
    [self.actionButton addSubview:spinnerView];
    [spinnerView stopAnimating];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _gradientLayer.frame = self.bottomControlView.bounds;
}

#pragma mark - Setter
- (void)setPlayerItem:(AVPlayerItem *)playerItem
{
    [self removeObserver];
    _playerItem = playerItem;
    [self updateDownloadProgress];
    [_playerItem addObserver:self
                  forKeyPath:@"loadedTimeRanges"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:nil];
}
- (void)setGradientColorsAtBottom:(NSArray *)colors
{
    _gradientLayer.colors = colors;
}

#pragma mark - Observer 
- (void)observeValueForKeyPath:(NSString*)path ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if ([path isEqualToString:@"loadedTimeRanges"]) {
        [self updateDownloadProgress];
    }
}

#pragma mark - Content
- (void)reloadControlView
{
    [self updateDuration];
    [self updateActionButton];
    [self updateBottomControlView];
}

- (void)updateDuration
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.playerItem) {
            
            dispatch_once(&once, ^{
                [self updateDurationOnMainThread:0];
                AVURLAsset *asset = (AVURLAsset *)[self.playerItem asset];
                float duration = CMTimeGetSeconds(asset.duration);
                if (!isnan(duration)) {
                    [self updateDurationOnMainThread:duration];
                }
            });
            
        } else {
            once = 0;
            [self updateDurationOnMainThread:0];
        }
    });
}

- (void)updateDurationOnMainThread:(float)duration
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timeSlider.maximumValue = duration;
        self.endTimeLabel.text = [self getFormattedTime:(duration == 0?-1:duration)];
    });
}

- (void)updateActionButton
{
    AVPlayerState state = [self.delegate currentControlStateForControlView:self];
    [self.actionButton setImage:[self getImageForState:state] forState:UIControlStateNormal];
    if (state == AVPlayerStateBuffering) {
        [spinnerView startAnimating];
    } else {
        [spinnerView stopAnimating];
    }
}

- (void)updateBottomControlView
{
    AVPlayerViewMode viewMode = [self.delegate currentViewModeForControlView:self];
    switch (viewMode) {
        case AVPlayerViewModeNormal:
            self.viewModeButton.selected = NO;
            break;
        case AVPlayerViewModeFullSize:
            self.viewModeButton.selected = YES;
            break;
    }
}

- (void)updateProgress:(float)time
{
    if (isnan(time) == false) {
        self.timeSlider.value = time;
        self.currentTimeLabel.text = [self getFormattedTime:time];
    }
}

- (void)updateDownloadProgress
{
    CMTime availbelCMTime = [self getAvailableDuration];
    float availableTime = CMTimeGetSeconds(availbelCMTime);
    float totalTime     = CMTimeGetSeconds(self.playerItem.duration);
    if (isnan(totalTime) == false) {
        self.progressView.progress = availableTime/totalTime;
    }
}

#pragma mark - IBAction
- (IBAction)actionButtonClicked:(UIButton *)actionButton
{
    [self.delegate actionButtonClickedAtControlView:self];
    [self runHideControlViewTimer];
}

- (IBAction)touchDownSlider:(UISlider *)slider
{
    if ([self.delegate respondsToSelector:@selector(controlView:beginValueChanged:)]) {
        [self.delegate controlView:self beginValueChanged:slider.value];
    }
    [self runHideControlViewTimer];
}

- (IBAction)sliderValueChanged:(UISlider *)slider
{
    if ([self.delegate respondsToSelector:@selector(controlView:timeValueChanged:)]) {
        [self.delegate controlView:self timeValueChanged:slider.value];
    }
    [self runHideControlViewTimer];
}

- (IBAction)sliderDragFinished:(UISlider *)slider
{
    if ([self.delegate respondsToSelector:@selector(controlView:finishValueChanged:)]) {
        [self.delegate controlView:self finishValueChanged:slider.value];
    }
    [self runHideControlViewTimer];
}

- (IBAction)viewModeButtonClicked:(UIButton *)viewModeButton
{
    if ([self.delegate respondsToSelector:@selector(controlView:viewModeClicked:)]) {
        if (viewModeButton.selected) {
            [self.delegate controlView:self viewModeClicked:AVPlayerViewModeFullSize];
        } else {
            [self.delegate controlView:self viewModeClicked:AVPlayerViewModeNormal];
        }
    }
    [self runHideControlViewTimer];
}

- (IBAction)controlViewTapped:(id)sender
{
    [self.delegate controlViewClicked:self];
    
    if ([self controlVisible]) {
        [self hideControlView];
    } else {
        [self showControlView];
    }
}

- (IBAction)pinchAVPlayer:(UIPinchGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        AVPlayerViewMode viewMode = [self.delegate currentViewModeForControlView:self];
        if (viewMode == AVPlayerViewModeNormal) {
            if (recognizer.scale > 1) {
                [self viewModeButtonClicked:self.viewModeButton];
            }
        } else {
            if (recognizer.scale < 1) {
                [self viewModeButtonClicked:self.viewModeButton];
            }
        }
    }
}

#pragma mark - Visibility
- (void)runHideControlViewTimer
{
    if (hideTimer) {
        [hideTimer invalidate];
        hideTimer = nil;
    }
    hideTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(autoHideControlView) userInfo:nil repeats:NO];
}

- (void)showControlView
{
    [self runHideControlViewTimer];
    [UIView animateWithDuration:0.2 animations:^{
        self.actionButton.alpha = 1;
        self.bottomControlView.alpha = 1;
    }];
}

- (void)autoHideControlView
{
    AVPlayerState state = [self.delegate currentControlStateForControlView:self];
    if (state == AVPlayerStatePlay) {
        [self hideControlView];
    }
}
- (void)hideControlView
{
    [hideTimer invalidate];
    hideTimer = nil;

    [UIView animateWithDuration:0.2 animations:^{
        self.actionButton.alpha = 0;
        self.bottomControlView.alpha = 0;
    }];
}

- (void)setHidden:(BOOL)hidden
{
    [self.actionButton setHidden:hidden];
    [self.bottomControlView setHidden:hidden];
}

#pragma mark - Private
- (UIImage *)getImageForState:(AVPlayerState)state
{
    switch (state) {
        case AVPlayerStatePlay:
            return [UIImage imageNamed:@"video_pause_white"];
        case AVPlayerStatePause:
            return [UIImage imageNamed:@"video_play_white"];
        case AVPlayerStateBuffering:
            return [UIImage new];
        case AVPlayerStateFinish:
            return [UIImage imageNamed:@"video_replay_white"];
    }
}

- (BOOL)controlVisible
{
    return (self.actionButton.alpha == 1);
}

- (NSString *)getFormattedTime:(float)time
{
    if (time == -1) return @"--:--";
    
    NSDateComponentsFormatter *dcFormatter = [[NSDateComponentsFormatter alloc] init];
    dcFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorNone;
    dcFormatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    if (time >= 60*60) {
        dcFormatter.allowedUnits |= NSCalendarUnitHour;
    }
    dcFormatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
    return [dcFormatter stringFromTimeInterval:time];
}

- (void)removeObserver
{
    if (_playerItem) {
        [_playerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    }
}

- (CMTime)getAvailableDuration
{
    NSValue *range = self.playerItem.loadedTimeRanges.firstObject;
    if (range != nil){
        return CMTimeRangeGetEnd(range.CMTimeRangeValue);
    }
    return kCMTimeZero;
}

@end
