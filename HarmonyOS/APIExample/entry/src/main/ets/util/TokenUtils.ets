import { rcp } from '@kit.RemoteCommunicationKit';
import { AppCertificate, AppID } from '../common/KeyCenter';
import { JSON, util } from '@kit.ArkTS';
import Logger from './Logger';

const TokenServerUrl: string = 'https://service.agora.io/toolbox-global/v1/token/generate'

export class TokenUtils {
  static async genRtcToken(channelName: string, uid: string, appId: string = AppID): Promise<string> {
    if (AppCertificate.length > 0) {
      Logger.error('App Certificate must stay on your token server')
      return ''
    }
    if (TokenServerUrl.length == 0) {
      return ''
    }
    try {
      const session = rcp.createSession({
        headers: { 'Content-Type': 'application/json' }
      });
      let body = JSON.stringify({
        "appId": appId,
        "channelName": channelName,
        "uid": uid,
        "expireSeconds": 900
      })
      let response = await session.post(TokenServerUrl, body)
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Logger.error(`Token server returned ${response.statusCode}`)
        return ''
      }
      let decoder = util.TextDecoder.create('utf-8');
      let stringData = decoder.decodeWithStream(new Uint8Array(response.body));
      let respParsed = JSON.parse(stringData) as GenRtcTokenResp
      return respParsed.token ?? respParsed.data?.token ?? ''
    } catch (e) {
      Logger.error(`Response err: Code is ${e.code}, message is ${JSON.stringify(e)}`);
    }
    return ''
  }
}

export interface GenRtcTokenData {
  token: string | undefined,
}

export interface GenRtcTokenResp {
  token?: string,
  data?: GenRtcTokenData
}
