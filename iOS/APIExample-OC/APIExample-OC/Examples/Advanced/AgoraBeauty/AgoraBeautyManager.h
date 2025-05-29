//
//  AgoraBeautyManager.h
//  APIExample-OC
//
//  Created by qinhui on 2025/5/29.
//

#import <Foundation/Foundation.h>
#import <AgoraRtcKit/AgoraRtcKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AgoraBeautyManager : NSObject
@property (nonatomic, weak, nullable) AgoraRtcEngineKit *agoraKit;

@property (nonatomic, assign) BOOL basicBeautyEnable;
@property (nonatomic, assign) float smoothness;
@property (nonatomic, assign) float lightness;
@property (nonatomic, assign) float redness;
@property (nonatomic, assign) float sharpness;
@property (nonatomic, assign) int32_t contrast;
@property (nonatomic, assign) float contrastStrength;

@property (nonatomic, assign) float eyePouch;
@property (nonatomic, assign) float brightenEye;
@property (nonatomic, assign) float nasolabialFold;
@property (nonatomic, assign) float whitenTeeth;

@property (nonatomic, assign) BOOL beautyShapeEnable;
@property (nonatomic, strong, nullable) NSString *beautyShapeStyle;
@property (nonatomic, assign) int32_t beautyShapeStrength;

@property (nonatomic, assign) BOOL makeUpEnable;
@property (nonatomic, strong, nullable) NSString *beautyMakeupStyle;
@property (nonatomic, assign) float beautyMakeupStrength;
@property (nonatomic, assign) int32_t facialStyle;
@property (nonatomic, assign) float facialStrength;
@property (nonatomic, assign) int32_t wocanStyle;
@property (nonatomic, assign) float wocanStrength;

@property (nonatomic, assign) int32_t browStyle;
@property (nonatomic, assign) int32_t browColor;
@property (nonatomic, assign) float browStrength;

@property (nonatomic, assign) int32_t lashStyle;
@property (nonatomic, assign) int32_t lashColor;
@property (nonatomic, assign) float lashStrength;

@property (nonatomic, assign) int32_t shadowStyle;
@property (nonatomic, assign) float shadowStrength;

@property (nonatomic, assign) int32_t pupilStyle;
@property (nonatomic, assign) float pupilStrength;

@property (nonatomic, assign) int32_t blushStyle;
@property (nonatomic, assign) int32_t blushColor;
@property (nonatomic, assign) float blushStrength;

@property (nonatomic, assign) int32_t lipStyle;
@property (nonatomic, assign) int32_t lipColor;
@property (nonatomic, assign) float lipStrength;

@property (nonatomic, assign) BOOL filterEnable;
@property (nonatomic, strong, nullable) NSString *beautyFilter;
@property (nonatomic, assign) float filterStrength;


- (instancetype)initWithAgoraKit:(nullable AgoraRtcEngineKit *)agoraKit;
- (void)destroy;
- (void)setLowLightEnhance:(BOOL)state;
- (void)setVideoDenoise:(BOOL)state;
- (void)setColorEnhance:(BOOL)state strengthValue:(CGFloat)strengthValue skinProtectValue:(CGFloat)skinProtectValue;

@end

NS_ASSUME_NONNULL_END
