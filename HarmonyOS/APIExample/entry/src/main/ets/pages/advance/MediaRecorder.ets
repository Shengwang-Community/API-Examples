import {
  AgoraMediaRecorder,
  ChannelMediaOptions,
  Constants,
  IMediaRecorderCallback,
  MediaRecorderConfiguration,
  RecorderInfo,
  RecorderStreamInfo,
  RtcEngine,
  RtcEngineConfig,
  VideoCanvas,
  VideoEncoderConfiguration
} from '@shengwang/rtc-full';
import { TitleBar } from '../../common/TitleBar';
import Logger from '../../util/Logger';
import ShowToast from '../../util/ShowToast';
import { AppID } from '../../common/KeyCenter';
import PermissionHelper from '../../util/PermissionHelper';
import { common } from '@kit.AbilityKit';
import { GlobalInfo } from '../Data';
import { TokenUtils } from '../../util/TokenUtils';

const TAG: string = 'MediaRecorder'

@Entry
@Component
struct MediaRecorder {
  private rtcEngine: RtcEngine | undefined = undefined;
  private localRecorder: AgoraMediaRecorder | undefined = undefined
  private remoteRecorder: AgoraMediaRecorder | undefined = undefined
  @State message: string = 'Hello World';
  @State channelName: string = ''
  @State isJoin: boolean = false
  @State localUid: number = 0
  @State remoteUid: number = 0
  @State localRecording: boolean = false
  @State remoteRecording: boolean = false

  aboutToAppear(): void {
    Logger.info(TAG, 'aboutToAppear')
    let config: RtcEngineConfig = new RtcEngineConfig();
    let context = getContext(this) as common.UIAbilityContext;
    config.mAppId = AppID;
    config.mEventHandler = {};
    config.mEventHandler.onUserJoined = (uid: number, collapse: number) => {
      Logger.info(TAG, "mEventHandler.onUserJoined: " + uid + " , " + collapse);
      if (this.remoteUid == 0) {
        this.remoteUid = uid
      }
    };
    config.mEventHandler.onUserOffline = (uid: number, reason: number) => {
      Logger.info(TAG, "mEventHandler.onUserOffline: " + uid + " , " + reason)
      if (this.remoteUid == uid) {
        this.stopRecorder(false)
        this.remoteUid = 0
      }
    };
    config.mEventHandler.onJoinChannelSuccess = (cid: string, uid: number, elapsed: number) => {
      Logger.info(TAG, "mEventHandler.onJoinChannelSuccess: " + uid);
      this.isJoin = true
      this.localUid = uid
    }
    config.mEventHandler.onLeaveChannel = () => {
      Logger.info(TAG, "mEventHandler.onLeaveChannel");
      this.stopRecorder(true)
      this.stopRecorder(false)
      this.isJoin = false
      this.localUid = 0
      this.remoteUid = 0
    }
    config.mEventHandler.onError = (err: number, message: string) => {
      Logger.info(TAG, "mEventHandler.onError: " + err + " message " + message);
      ShowToast.longToast("onError " + err + " : " + message)
    }
    config.mContext = context;
    Logger.info(TAG, "in thread create engine begin: ");
    this.rtcEngine = RtcEngine.create(config);

    let encoderConfig = new VideoEncoderConfiguration()
    encoderConfig.dimensions = GlobalInfo.settings.dimensions
    encoderConfig.frameRate = GlobalInfo.settings.frameRate
    encoderConfig.orientationMode = GlobalInfo.settings.orientationMode
    this.rtcEngine.setVideoEncoderConfiguration(encoderConfig)
    this.rtcEngine.enableVideo()
  }

  aboutToDisappear(): void {
    this.stopRecorder(true)
    this.stopRecorder(false)
    if (this.rtcEngine != undefined) {
      if (this.isJoin) {
        this.rtcEngine.stopPreview();
        this.rtcEngine.leaveChannel();
      }
      Logger.info(TAG, "destroy begin")
      RtcEngine.destroy().then(() => {
        Logger.info(TAG, "destroy done")
      });
      Logger.info(TAG, "destroy end")
      this.rtcEngine = undefined;
    }
  }

  private startRecorder(local: boolean): void {
    let engine = this.rtcEngine
    let uid = local ? this.localUid : this.remoteUid
    if (engine == undefined || !this.isJoin || uid == 0) {
      return
    }

    this.stopRecorder(local)
    let info = new RecorderStreamInfo()
    info.uid = uid
    info.channelId = this.channelName
    let recorder = engine.createMediaRecorder(info)
    if (recorder == undefined) {
      ShowToast.longToast('createMediaRecorder failed')
      return
    }

    let observer: IMediaRecorderCallback = {
      onRecorderStateChanged: (channelId: string, userId: number, state: number, reason: number): void => {
        Logger.info(TAG, `onRecorderStateChanged channelId=${channelId}, uid=${userId}, state=${state}, reason=${reason}`)
        if (local ? this.localRecorder !== recorder : this.remoteRecorder !== recorder) {
          return
        }
        if (state == AgoraMediaRecorder.RECORDER_STATE_ERROR || state == AgoraMediaRecorder.RECORDER_STATE_STOP) {
          if (local) {
            this.localRecording = false
          } else {
            this.remoteRecording = false
          }
          if (state == AgoraMediaRecorder.RECORDER_STATE_ERROR) {
            ShowToast.longToast(`Recording failed: ${reason}`)
          }
        }
      },
      onRecorderInfoUpdated: (channelId: string, userId: number, recorderInfo: RecorderInfo): void => {
        Logger.info(TAG, `onRecorderInfoUpdated channelId=${channelId}, uid=${userId}, filename=${recorderInfo.fileName}, durationMs=${recorderInfo.durationMs}, fileSize=${recorderInfo.fileSize}`)
      }
    }
    let observerResult = recorder.setMediaRecorderObserver(observer)
    if (observerResult != Constants.ErrorCode.ERR_OK) {
      recorder.release()
      ShowToast.longToast(`setMediaRecorderObserver failed: ${observerResult}`)
      return
    }

    if (local) {
      this.localRecorder = recorder
      this.localRecording = true
    } else {
      this.remoteRecorder = recorder
      this.remoteRecording = true
    }
    let virtualPath = `${(getContext(this) as common.UIAbilityContext).filesDir}/media_recorder_${local ? 'local' : 'remote'}.mp4`
    let config = new MediaRecorderConfiguration(
      virtualPath,
      AgoraMediaRecorder.CONTAINER_MP4,
      AgoraMediaRecorder.STREAM_TYPE_BOTH,
      120000,
      0
    )
    let result = recorder.startRecording(config)
    if (result != Constants.ErrorCode.ERR_OK) {
      recorder.release()
      if (local) {
        this.localRecorder = undefined
        this.localRecording = false
      } else {
        this.remoteRecorder = undefined
        this.remoteRecording = false
      }
      ShowToast.longToast(`startRecording failed: ${result}`)
      return
    }
  }

  private stopRecorder(local: boolean, showPath: boolean = false): void {
    let recorder = local ? this.localRecorder : this.remoteRecorder
    if (recorder == undefined) {
      return
    }
    let wasRecording = local ? this.localRecording : this.remoteRecording
    let result = wasRecording ? recorder.stopRecording() : Constants.ErrorCode.ERR_OK
    recorder.release()
    if (local) {
      this.localRecorder = undefined
      this.localRecording = false
    } else {
      this.remoteRecorder = undefined
      this.remoteRecording = false
    }
    if (result != Constants.ErrorCode.ERR_OK) {
      ShowToast.longToast(`stopRecording failed: ${result}`)
      return
    }
    if (showPath && wasRecording) {
      let virtualPath = `${(getContext(this) as common.UIAbilityContext).filesDir}/media_recorder_${local ? 'local' : 'remote'}.mp4`
      AlertDialog.show({
        title: 'MediaFilePath',
        message: virtualPath,
        confirm: { value: $r('app.string.confirm'), backgroundColor: Color.White, action: () => {} },
        alignment: DialogAlignment.Center
      })
    }
  }

  build() {
    Column() {
      TitleBar({
        title: $r('app.string.item_mediarecorder'),
        showBack: true
      })

      Column() {
        Row() {

          if (this.localUid != 0) {
            Stack() {
              XComponent({
                id: 'preview_local',
                type: XComponentType.SURFACE,
                libraryname: Constants.AGORA_LIB_NAME,
              }).onLoad(() => {
                let localCanvas = new VideoCanvas("preview_local");
                localCanvas.uid = this.localUid;
                localCanvas.renderMode = VideoCanvas.RENDER_MODE_HIDDEN;
                localCanvas.mirrorMode = 0;
                this.rtcEngine?.setupLocalVideo(localCanvas);
              })

              Button(this.localRecording ? $r('app.string.stop_recording') : $r('app.string.start_recording'))
                .onClick(() => {
                  if (this.localRecording) {
                    this.stopRecorder(true, true)
                  } else {
                    this.startRecorder(true)
                  }
                })
                .margin({ right: 12, bottom: 12 })
            }.width('50%')
            .alignContent(Alignment.BottomEnd)
          }

          if (this.remoteUid != 0) {
            Stack() {
              XComponent({
                id: 'preview_remote',
                type: XComponentType.SURFACE,
                libraryname: Constants.AGORA_LIB_NAME,
              }).onLoad(() => {
                let localCanvas = new VideoCanvas("preview_remote");
                localCanvas.uid = this.remoteUid;
                localCanvas.renderMode = VideoCanvas.RENDER_MODE_HIDDEN;
                localCanvas.mirrorMode = 0;
                this.rtcEngine?.setupRemoteVideo(localCanvas);
              })
              Button(this.remoteRecording ? $r('app.string.stop_recording') : $r('app.string.start_recording'))
                .onClick(() => {
                  if (this.remoteRecording) {
                    this.stopRecorder(false, true)
                  } else {
                    this.startRecorder(false)
                  }
                })
                .margin({ right: 12, bottom: 12 })
            }.width('50%')
            .alignContent(Alignment.BottomEnd)
          }
        }
        .align(Alignment.TopStart)
        .height("50%")
        .width('100%')
      }
      .align(Alignment.TopStart)
      .layoutWeight(1)

      Row() {
        TextInput({ placeholder: $r('app.string.text_input_channel_name') })
          .id("input_channel_name")
          .enabled(!this.isJoin)
          .enableKeyboardOnFocus(false)
          .onChange((value: string) => {
            this.channelName = value
          })
          .layoutWeight(1)
          .margin({ right: 6 })

        Button(this.isJoin ? $r('app.string.leave') : $r('app.string.join'))
          .id('button_to_join')
          .onClick(async () => {
            focusControl.requestFocus("button_to_join")
            if (this.isJoin) {
              this.stopRecorder(true)
              this.stopRecorder(false)
              this.rtcEngine?.stopPreview()
              this.rtcEngine?.leaveChannel()
            } else {
              if (this.channelName == "") {
                ShowToast.shortToast("The channel name is empty!")
                return
              }
              if (!(await PermissionHelper.checkPermissions(
                getContext(this) as common.UIAbilityContext,
                ['ohos.permission.MICROPHONE', 'ohos.permission.CAMERA']
              ))) {
                ShowToast.shortToast("Permission leak!")
                return
              }

              let mediaOption: ChannelMediaOptions = new ChannelMediaOptions();
              mediaOption.publishCameraTrack = true;
              mediaOption.publishMicrophoneTrack = true;
              mediaOption.autoSubscribeVideo = true;
              mediaOption.autoSubscribeAudio = true;
              mediaOption.channelProfile = Constants.ChannelProfile.LIVE_BROADCASTING;
              mediaOption.clientRoleType = Constants.ClientRole.BROADCASTER;

              let token = await TokenUtils.genRtcToken(this.channelName, "")
              let ret = this.rtcEngine?.joinChannelWithOptions(token, this.channelName, 0, mediaOption)
              if (ret != Constants.ErrorCode.ERR_OK) {
                ShowToast.longToast("joinChannelWithOptions error " + ret + " : " +
                RtcEngine.getErrorDescription(ret))
                return
              }

              this.rtcEngine?.startPreview()
            }
          })
      }
      .padding({
        left: 12,
        right: 12,
        top: 6,
        bottom: 6
      })
    }
    .backgroundColor($r('app.color.background_shallow_grey'))
  }
}
