# MediaPipe proto classes referenced by flutter_gemma's Java layer but not bundled
# in the release APK. R8 generates these rules in missing_rules.txt — applied here.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# AutoValue's @Memoized is a compile-time-only annotation referenced by
# com.google.mediapipe.framework.image.MPImageProperties.hashCode() but never
# present on the runtime classpath. Safe to ignore.
-dontwarn com.google.auto.value.extension.memoized.Memoized
