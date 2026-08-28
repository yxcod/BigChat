# Baidu Map SDK initializes several Java classes from native code. R8 cannot
# discover those JNI lookups and would otherwise remove or rename the classes.
-keep class com.baidu.** { *; }
-keep interface com.baidu.** { *; }
-dontwarn com.baidu.**

# Baidu's Flutter utils decode method-channel payloads with anonymous Gson
# TypeToken subclasses. Their generic type lives in the Signature attribute;
# stripping it makes coordinate conversion fail only in release builds.
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,AnnotationDefault
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
