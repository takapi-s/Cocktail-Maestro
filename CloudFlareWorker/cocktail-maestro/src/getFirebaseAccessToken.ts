import { Env as HonoEnv } from "hono";

interface Env extends HonoEnv {
  FIREBASE_SERVICE_ACCOUNT: string;
}


export async function getFirebaseAccessToken(env: Env): Promise<string> {
    const jsonStr = atob(env.FIREBASE_SERVICE_ACCOUNT); // ← ここが Buffer の代わり
    const key = JSON.parse(jsonStr);
  
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600;
  
    const header = {
      alg: "RS256",
      typ: "JWT",
    };
  
    const payload = {
      iss: key.client_email,
      sub: key.client_email,
      aud: "https://oauth2.googleapis.com/token",
      scope: "https://www.googleapis.com/auth/datastore",
      iat,
      exp,
    };
  
    const base64url = (obj: object) =>
      btoa(JSON.stringify(obj))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/, "");
  
    const toUint8Array = (str: string): Uint8Array => {
      return new TextEncoder().encode(str);
    };
  
    const unsignedJWT = `${base64url(header)}.${base64url(payload)}`;
  
    const keyData = await crypto.subtle.importKey(
      "pkcs8",
      strToArrayBuffer(key.private_key),
      {
        name: "RSASSA-PKCS1-v1_5",
        hash: "SHA-256",
      },
      false,
      ["sign"]
    );
  
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      keyData,
      toUint8Array(unsignedJWT)
    );
  
    const signedJWT =
      unsignedJWT + "." + arrayBufferToBase64Url(signature);
  
    // Get Access Token
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: signedJWT,
      }),
    });
  
    interface TokenResponse {
      access_token: string;
      expires_in: number;
      token_type: string;
    }

    const tokenData: TokenResponse = await tokenResponse.json();
    return tokenData.access_token;
  }
  
  // Base64URL encode
  function arrayBufferToBase64Url(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = "";
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  
  // PEM to ArrayBuffer
  function strToArrayBuffer(pem: string): ArrayBuffer {
    const b64 = pem
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\n/g, "")
      .trim();
  
    const binary = atob(b64);
    const len = binary.length;
    const buffer = new ArrayBuffer(len);
    const view = new Uint8Array(buffer);
  
    for (let i = 0; i < len; i++) {
      view[i] = binary.charCodeAt(i);
    }
  
    return buffer;
  }
  