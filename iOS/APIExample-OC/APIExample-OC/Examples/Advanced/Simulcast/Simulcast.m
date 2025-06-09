#import "Simulcast.h"
#import "BaseViewController.h"
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <AgoraRtcKit/AgoraEnumerates.h>
#import "VideoView.h"
#import "APIExample_OC-swift.h"
#import "KeyCenter.h"
#import "Util.h"

@interface SimulcastEntry ()
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *roleSegment;
@end

@implementation SimulcastEntry

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)onClickJoinButton:(id)sender {
    [self.textField resignFirstResponder];
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Simulcast" bundle:nil];
    BaseViewController *newViewController = [storyBoard instantiateViewControllerWithIdentifier:@"Simulcast"];
    newViewController.configs = @{
        @"channelName": self.textField.text,
        @"role_index": @(self.roleSegment.selectedSegmentIndex)
    };
    [self.navigationController pushViewController:newViewController animated:YES];
}

@end

@interface SimulcastViewController ()<AgoraRtcEngineDelegate>
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (nonatomic, strong) VideoView *localView;
@property (nonatomic, strong) VideoView *remoteView;
@property (nonatomic, strong) AgoraRtcEngineKit *agoraKit;
@property (nonatomic, copy) NSString *channelName;
@property (nonatomic, assign) BOOL isJoined;
@property (nonatomic, assign) NSUInteger remoteUid;

@property (weak, nonatomic) IBOutlet UIView *hostSettingContainer;
@property (weak, nonatomic) IBOutlet UISegmentedControl *audienceLayerSegment;
@property (weak, nonatomic) IBOutlet UILabel *tipsLabel;
@property (weak, nonatomic) IBOutlet UISwitch *layer1Switch;
@property (weak, nonatomic) IBOutlet UISwitch *layer2Switch;
@property (weak, nonatomic) IBOutlet UISwitch *layer3Switch;
@property (weak, nonatomic) IBOutlet UISwitch *layer4Switch;
@end

@implementation SimulcastViewController

- (VideoView *)localView {
    if (_localView == nil) {
        _localView = (VideoView *)[NSBundle loadVideoViewFormType:StreamTypeLocal audioOnly:NO];
    }
    return _localView;
}

- (VideoView *)remoteView {
    if (_remoteView == nil) {
        _remoteView = (VideoView *)[NSBundle loadVideoViewFormType:StreamTypeRemote audioOnly:NO];
    }
    return _remoteView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *channelName = [self.configs objectForKey:@"channelName"];
    NSInteger roleIndex = [[self.configs objectForKey:@"role_index"] integerValue];
    self.channelName = channelName;
    
    // layout render view
    [self.localView setPlaceholder:@"Local Host".localized];
    [self.remoteView setPlaceholder:@"Remote Host".localized];
    [self.containerView layoutStream:@[self.localView, self.remoteView]];
    
    // set up agora instance when view loaded
    AgoraRtcEngineConfig *config = [[AgoraRtcEngineConfig alloc] init];
    config.appId = KeyCenter.AppId;
    config.channelProfile = AgoraChannelProfileLiveBroadcasting;
    
    self.agoraKit = [AgoraRtcEngineKit sharedEngineWithConfig:config delegate:self];
    
    // set up view
    self.hostSettingContainer.hidden = (roleIndex != 0);
    self.audienceLayerSegment.hidden = (roleIndex == 0);
    
    // enable video module and set up video encoding configs
    [self.agoraKit enableAudio];
    [self.agoraKit enableVideo];
    [self.agoraKit setClientRole:(roleIndex == 0) ? AgoraClientRoleBroadcaster : AgoraClientRoleAudience];
    
    if (roleIndex == 0) {
        // Set video encoder configuration
        AgoraVideoEncoderConfiguration *videoConfig = [[AgoraVideoEncoderConfiguration alloc] initWithSize:CGSizeMake(640, 360)
                                                                                                 frameRate:AgoraVideoFrameRateFps15
                                                                                                   bitrate:AgoraVideoBitrateStandard
                                                                                           orientationMode:AgoraVideoOutputOrientationModeAdaptative
                                                                                                mirrorMode:AgoraVideoMirrorModeAuto];
        [self.agoraKit setVideoEncoderConfiguration:videoConfig];
        
        // set up local video to render your local camera preview
        AgoraRtcVideoCanvas *videoCanvas = [[AgoraRtcVideoCanvas alloc] init];
        videoCanvas.uid = 0;
        videoCanvas.view = self.localView.videoView;
        videoCanvas.renderMode = AgoraVideoRenderModeHidden;
        [self.agoraKit setupLocalVideo:videoCanvas];
        [self.agoraKit startPreview];
        [self setupSimulcast];
    }
    
    // Set audio route to speaker
    [self.agoraKit setEnableSpeakerphone:YES];
    
    // start joining channel
    AgoraRtcChannelMediaOptions *options = [[AgoraRtcChannelMediaOptions alloc] init];
    options.autoSubscribeAudio = YES;
    options.autoSubscribeVideo = YES;
    options.publishCameraTrack = (roleIndex == 0);
    options.publishMicrophoneTrack = (roleIndex == 0);
    options.clientRoleType = (roleIndex == 0) ? AgoraClientRoleBroadcaster : AgoraClientRoleAudience;
    
    [[NetworkManager shared] generateTokenWithChannelName:channelName uid:0 success:^(NSString * _Nullable token) {
        int result = [self.agoraKit joinChannelByToken:token channelId:channelName uid:0 mediaOptions:options joinSuccess:nil];
        if (result != 0) {
            NSLog(@"joinChannel call failed: %d, please check your params", result);
        }
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.agoraKit disableAudio];
    [self.agoraKit disableVideo];
    if (self.isJoined) {
        [self.agoraKit stopPreview];
        [self.agoraKit leaveChannel:nil];
    }
    [AgoraRtcEngineKit destroy];
}

- (IBAction)onClickSimulcastSwitch:(UISwitch *)sender {
    if (self.layer1Switch.isOn && self.layer2Switch.isOn &&
        self.layer3Switch.isOn && self.layer4Switch.isOn) {
        [ToastView showWithText:@"Maxmum 3 layers can be selected".localized postion:ToastViewPostionCenter];
        sender.on = !sender.isOn;
        return;
    }
    [self setupSimulcast];
}

- (IBAction)onClickLayerSegment:(UISegmentedControl *)sender {
    if (self.remoteUid == 0) {
        [ToastView showWithText:@"No remote user".localized postion:ToastViewPostionCenter];
        return;
    }
    AgoraVideoStreamType layer = (AgoraVideoStreamType)sender.selectedSegmentIndex;
    int ret = [self.agoraKit setRemoteVideoStream:self.remoteUid type:layer];
    [LogUtil log:[NSString stringWithFormat:@"set remote layer:%ld, ret: %d", (long)layer, ret] level:LogLevelInfo];
}

- (void)setupSimulcast {
    AgoraSimulcastConfig *conf = [[AgoraSimulcastConfig alloc] init];
    
    if (self.layer1Switch.isOn) {
        conf.configs[AgoraStreamLayer1].dimensions = CGSizeMake(1280, 720);
        conf.configs[AgoraStreamLayer1].framerate = 30;
        conf.configs[AgoraStreamLayer1].enable = YES;
    } else {
        conf.configs[AgoraStreamLayer1].enable = NO;
    }
    
    if (self.layer2Switch.isOn) {
        conf.configs[AgoraStreamLayer2].dimensions = CGSizeMake(960, 540);
        conf.configs[AgoraStreamLayer2].framerate = 15;
        conf.configs[AgoraStreamLayer2].enable = YES;
    } else {
        conf.configs[AgoraStreamLayer2].enable = NO;
    }
    
    if (self.layer3Switch.isOn) {
        conf.configs[AgoraStreamLayer3].dimensions = CGSizeMake(640, 360);
        conf.configs[AgoraStreamLayer3].framerate = 15;
        conf.configs[AgoraStreamLayer3].enable = YES;
    } else {
        conf.configs[AgoraStreamLayer3].enable = NO;
    }
    
    if (self.layer4Switch.isOn) {
        conf.configs[AgoraStreamLayer4].dimensions = CGSizeMake(480, 270);
        conf.configs[AgoraStreamLayer4].framerate = 15;
        conf.configs[AgoraStreamLayer4].enable = YES;
    } else {
        conf.configs[AgoraStreamLayer4].enable = NO;
    }
    
    int ret = [self.agoraKit setSimulcastConfig:conf];
    [LogUtil log:[NSString stringWithFormat:@"setSimulcastConfig: %d", ret] level:LogLevelInfo];
}

#pragma mark - AgoraRtcEngineDelegate

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurError:(AgoraErrorCode)errorCode {
    [LogUtil log:[NSString stringWithFormat:@"Error %ld occur",(long)errorCode] level:LogLevelError];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    self.isJoined = YES;
    [LogUtil log:[NSString stringWithFormat:@"Join %@ with uid %lu elapsed %ldms", channel, (unsigned long)uid, (long)elapsed] level:LogLevelInfo];
    self.localView.uid = uid;
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    [LogUtil log:[NSString stringWithFormat:@"remote user join: %lu %ldms", (unsigned long)uid, (long)elapsed] level:LogLevelInfo];
    
    AgoraRtcVideoCanvas *videoCanvas = [[AgoraRtcVideoCanvas alloc] init];
    videoCanvas.uid = uid;
    videoCanvas.view = self.remoteView.videoView;
    videoCanvas.renderMode = AgoraVideoRenderModeHidden;
    [self.agoraKit setupRemoteVideo:videoCanvas];
    
    int ret = [self.agoraKit setRemoteVideoStream:uid type:AgoraVideoStreamTypeHigh];
    [LogUtil log:[NSString stringWithFormat:@"set remote layer, ret: %d", ret] level:LogLevelInfo];
    
    self.remoteUid = uid;
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    AgoraRtcVideoCanvas *videoCanvas = [[AgoraRtcVideoCanvas alloc] init];
    videoCanvas.uid = uid;
    videoCanvas.view = nil;
    [self.agoraKit setupRemoteVideo:videoCanvas];
    self.remoteUid = 0;
    [LogUtil log:[NSString stringWithFormat:@"remote user left: %lu", (unsigned long)uid] level:LogLevelInfo];
}

@end 
