#!/bin/bash
# 镜控手柄 APK 无 Gradle 构建（macOS, JDK 17+）
# 需求: ANDROID_SDK(含 build-tools/35.0.0 与 platforms/android-35), JDK 17+
set -e
BT=${BT:-$HOME/Library/Android/sdk/build-tools/35.0.0}
AJ=${AJ:-$HOME/Library/Android/sdk/platforms/android-35/android.jar}
cd "$(dirname "$0")"
rm -rf build && mkdir -p build
$BT/aapt2 compile --dir res -o build/res.zip
$BT/aapt2 link -o build/base.apk -I $AJ --manifest AndroidManifest.xml --java build build/res.zip
javac --release 17 -cp $AJ -d build build/com/yao/synpad/R.java app/src/com/yao/synpad/MainActivity.java
$BT/d8 --release --lib $AJ --min-api 26 --output build build/com/yao/synpad/*.class
(cd build && cp base.apk unsigned.apk && zip -q -j unsigned.apk classes.dex)
[ -f debug.keystore ] || keytool -genkeypair -keystore debug.keystore -alias androiddebugkey \
  -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" \
  -keyalg RSA -keysize 2048 -validity 10000
$BT/zipalign -f 4 build/unsigned.apk build/aligned.apk
$BT/apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android \
  --out build/synpad.apk build/aligned.apk
echo "=> build/synpad.apk"; $BT/apksigner verify build/synpad.apk
