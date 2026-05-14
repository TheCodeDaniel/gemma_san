# MediaPipe proto classes referenced by flutter_gemma's Java layer but not bundled
# in the release APK. R8 generates these rules in missing_rules.txt — applied here.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
