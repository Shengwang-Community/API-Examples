//
//  AgoraBeautyManager.m
//  APIExample-OC
//
//  Created by qinhui on 2025/5/29.
//

#import "AgoraBeautyManager.h"

@interface AgoraBeautyManager ()

@property (nonatomic, strong) id<AgoraVideoEffectObject> videoEffectObject;
@property (nonatomic, strong) AgoraFaceShapeBeautyOptions *faceshapeOption;
@property (nonatomic, strong) NSDictionary<NSString *, id> *styleParam;
@property (nonatomic, assign) BOOL bundleCopied;
@property (nonatomic, strong, readonly) NSString *beautyMaterialPath;
@property (nonatomic, strong, readonly) NSString *currentMaterialName;

@end

@implementation AgoraBeautyManager
- (instancetype)init {
    return [self initWithAgoraKit:nil];
}

- (instancetype)initWithAgoraKit:(nullable AgoraRtcEngineKit *)agoraKit {
    self = [super init];
    if (self) {
        _agoraKit = agoraKit;
        _faceshapeOption = [[AgoraFaceShapeBeautyOptions alloc] init];
        _styleParam = @{@"enable_mu": @(NO)};
        _bundleCopied = NO;
        [self initBeauty];
    }
    return self;
}

- (void)destroy {
    if (self.videoEffectObject) {
        NSInteger result = [self.agoraKit destroyVideoEffectObject:self.videoEffectObject];
        if (result == 0) {
            self.videoEffectObject = nil;
        }
    }
}

- (void)setLowLightEnhance:(BOOL)state {
    AgoraLowlightEnhanceOptions *option = [AgoraLowlightEnhanceOptions new];
    option.level = AgoraLowlightEnhanceLevelFast;
    option.mode = AgoraLowlightEnhanceModeAuto;
    [self.agoraKit setLowlightEnhanceOptions:state options:option];
}

- (void)setVideoDenoise:(BOOL)state {
    AgoraVideoDenoiserOptions *option = [AgoraVideoDenoiserOptions new];
    option.level = AgoraVideoDenoiserLevelHighQuality;
    option.mode = AgoraVideoDenoiserModeManual;
    [self.agoraKit setVideoDenoiserOptions:state options:option];
}

- (void)setColorEnhance:(BOOL)state strengthValue:(CGFloat)strengthValue skinProtectValue:(CGFloat)skinProtectValue {
    AgoraColorEnhanceOptions *option = [AgoraColorEnhanceOptions new];
    option.strengthLevel = strengthValue;
    option.skinProtectLevel = skinProtectValue;
    [self.agoraKit setColorEnhanceOptions:state options:option];
}

#pragma mark - Private Methods

- (void)initBeauty {
    [self.agoraKit enableExtensionWithVendor:@"agora_video_filters_clear_vision"
                                   extension:@"clear_vision"
                                     enabled:YES
                                  sourceType:AgoraMediaSourceTypePrimaryCamera];
    
    [self copyBeautyBundle];
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.beautyMaterialPath, self.currentMaterialName];
    self.videoEffectObject = [self.agoraKit createVideoEffectObjectWithBundlePath:path
                                                                        sourceType:AgoraMediaSourceTypePrimaryCamera];
}

- (void)copyBeautyBundle {
    if (self.bundleCopied) {
        return;
    }
    
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"beauty_material" ofType:@"bundle"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.beautyMaterialPath]) {
        [fileManager removeItemAtPath:self.beautyMaterialPath error:nil];
    }
    
    [fileManager copyItemAtPath:bundlePath toPath:self.beautyMaterialPath error:nil];
    self.bundleCopied = YES;
}

- (void)addEffect:(uint32_t)node {
    NSInteger ret = [self.videoEffectObject addOrUpdateVideoEffectWithNodeId:node templateName:@""] ?: -1;
    NSLog(@"addEffect ret: %ld", (long)ret);
}

- (void)removeEffect:(uint32_t)node {
    NSInteger ret = [self.videoEffectObject removeVideoEffectWithNodeId:node] ?: -1;
    NSLog(@"removeEffect ret: %ld", (long)ret);
}

- (void)updateMaterialConfig:(uint32_t)node selection:(NSString *)selection {
    NSInteger ret = [self.videoEffectObject addOrUpdateVideoEffectWithNodeId:node templateName:selection] ?: -1;
    NSLog(@"updateMaterialConfig ret: %ld", (long)ret);
}

#pragma mark - Getters

- (NSString *)beautyMaterialPath {
    return [NSString stringWithFormat:@"%@/Documents/beauty_material.bundle", NSHomeDirectory()];
}

- (NSString *)currentMaterialName {
    return @"beauty_material_v2.0.0";
}

#pragma mark - Basic Beauty Properties

- (BOOL)basicBeautyEnable {
    return [self.videoEffectObject getVideoEffectBoolParamWithOption:@"beauty_effect_option" key:@"enable"] ?: NO;
}

- (void)setBasicBeautyEnable:(BOOL)basicBeautyEnable {
    if (basicBeautyEnable) {
        if (!self.beautyShapeStyle) {
            [self addEffect:AgoraVideoEffectNodeBeauty];
            [self.videoEffectObject setVideoEffectBoolParamWithOption:@"face_shape_beauty_option"
                                                                  key:@"enable"
                                                            boolValue:NO];
        }
    }
    
    [self.videoEffectObject setVideoEffectBoolParamWithOption:@"beauty_effect_option"
                                                          key:@"enable"
                                                    boolValue:basicBeautyEnable];
}

- (float)smoothness {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"beauty_effect_option" key:@"smoothness"] ?: 0.9f;
}

- (void)setSmoothness:(float)smoothness {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"beauty_effect_option"
                                                           key:@"smoothness"
                                                    floatValue:smoothness];
}

- (float)lightness {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"beauty_effect_option" key:@"lightness"] ?: 0.9f;
}

- (void)setLightness:(float)lightness {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"beauty_effect_option"
                                                           key:@"lightness"
                                                    floatValue:lightness];
}

- (float)redness {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"beauty_effect_option" key:@"redness"] ?: 1.0f;
}

- (void)setRedness:(float)redness {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"beauty_effect_option"
                                                           key:@"redness"
                                                    floatValue:redness];
}

- (float)sharpness {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"beauty_effect_option" key:@"sharpness"] ?: 1.0f;
}

- (void)setSharpness:(float)sharpness {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"beauty_effect_option"
                                                           key:@"sharpness"
                                                    floatValue:sharpness];
}

- (int32_t)contrast {
    return [self.videoEffectObject getVideoEffectIntParamWithOption:@"beauty_effect_option" key:@"contrast"] ?: 1;
}

- (void)setContrast:(int32_t)contrast {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectIntParamWithOption:@"beauty_effect_option"
                                                         key:@"contrast"
                                                    intValue:contrast];
}

- (float)contrastStrength {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"beauty_effect_option" key:@"contrast_strength"] ?: 1.0f;
}

- (void)setContrastStrength:(float)contrastStrength {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"beauty_effect_option"
                                                           key:@"contrast_strength"
                                                    floatValue:contrastStrength];
}

#pragma mark - Extension Beauty Properties

- (float)eyePouch {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"face_buffing_option" key:@"eye_pouch"] ?: 0.5f;
}

- (void)setEyePouch:(float)eyePouch {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"face_buffing_option"
                                                           key:@"eye_pouch"
                                                    floatValue:eyePouch];
}

- (float)brightenEye {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"face_buffing_option" key:@"brighten_eye"] ?: 0.9f;
}

- (void)setBrightenEye:(float)brightenEye {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"face_buffing_option"
                                                           key:@"brighten_eye"
                                                    floatValue:brightenEye];
}

- (float)nasolabialFold {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"face_buffing_option" key:@"nasolabial_fold"] ?: 0.7f;
}

- (void)setNasolabialFold:(float)nasolabialFold {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"face_buffing_option"
                                                           key:@"nasolabial_fold"
                                                    floatValue:nasolabialFold];
}

- (float)whitenTeeth {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"face_buffing_option" key:@"whiten_teeth"] ?: 0.7f;
}

- (void)setWhitenTeeth:(float)whitenTeeth {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"face_buffing_option"
                                                           key:@"whiten_teeth"
                                                    floatValue:whitenTeeth];
}

#pragma mark - Beauty Shape Properties

- (BOOL)beautyShapeEnable {
    return [self.videoEffectObject getVideoEffectBoolParamWithOption:@"face_shape_beauty_option" key:@"enable"] ?: NO;
}

- (void)setBeautyShapeEnable:(BOOL)beautyShapeEnable {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectBoolParamWithOption:@"face_shape_beauty_option"
                                                          key:@"enable"
                                                    boolValue:beautyShapeEnable];
}

- (NSString *)beautyShapeStyle {
    return nil;
}

- (void)setBeautyShapeStyle:(NSString *)beautyShapeStyle {
    if (!self.videoEffectObject) return;
    
    if (beautyShapeStyle) {
        [self updateMaterialConfig:AgoraVideoEffectNodeBeauty selection:beautyShapeStyle];
    } else {
        [self removeEffect:AgoraVideoEffectNodeBeauty];
    }
}

- (int32_t)beautyShapeStrength {
    return [self.videoEffectObject getVideoEffectIntParamWithOption:@"face_shape_beauty_option" key:@"intensity"] ?: 50;
}

- (void)setBeautyShapeStrength:(int32_t)beautyShapeStrength {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectIntParamWithOption:@"face_shape_beauty_option"
                                                         key:@"intensity"
                                                    intValue:beautyShapeStrength];
}

#pragma mark - Makeup Properties

- (BOOL)makeUpEnable {
    return [self.videoEffectObject getVideoEffectBoolParamWithOption:@"makeup_options" key:@"enable_mu"] ?: NO;
}

- (void)setMakeUpEnable:(BOOL)makeUpEnable {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectBoolParamWithOption:@"makeup_options"
                                                          key:@"enable_mu"
                                                    boolValue:makeUpEnable];
}

- (NSString *)beautyMakeupStyle {
    return nil;
}

- (void)setBeautyMakeupStyle:(NSString *)beautyMakeupStyle {
    if (!self.videoEffectObject) return;
    
    if (beautyMakeupStyle) {
        [self updateMaterialConfig:AgoraVideoEffectNodeStyleMakeup selection:beautyMakeupStyle];
    } else {
        [self removeEffect:AgoraVideoEffectNodeStyleMakeup];
    }
}

- (float)beautyMakeupStrength {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"style_makeup_option" key:@"styleIntensity"] ?: 0.95f;
}

- (void)setBeautyMakeupStrength:(float)beautyMakeupStrength {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"style_makeup_option"
                                                           key:@"styleIntensity"
                                                    floatValue:beautyMakeupStrength];
}

#pragma mark - Filter Properties

- (BOOL)filterEnable {
    return [self.videoEffectObject getVideoEffectBoolParamWithOption:@"filter_effect_option" key:@"enable"] ?: NO;
}

- (void)setFilterEnable:(BOOL)filterEnable {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectBoolParamWithOption:@"filter_effect_option"
                                                          key:@"enable"
                                                    boolValue:filterEnable];
}

- (NSString *)beautyFilter {
    return nil;
}

- (void)setBeautyFilter:(NSString *)beautyFilter {
    if (!self.videoEffectObject) return;
    
    if (beautyFilter) {
        [self updateMaterialConfig:AgoraVideoEffectNodeFilter selection:beautyFilter];
    } else {
        [self removeEffect:AgoraVideoEffectNodeFilter];
    }
}

- (float)filterStrength {
    return [self.videoEffectObject getVideoEffectFloatParamWithOption:@"filter_effect_option" key:@"strength"] ?: 0.5f;
}

- (void)setFilterStrength:(float)filterStrength {
    if (!self.videoEffectObject) return;
    [self.videoEffectObject setVideoEffectFloatParamWithOption:@"filter_effect_option"
                                                           key:@"strength"
                                                    floatValue:filterStrength];
}

@end
