# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class fyi.imdaniel.smalltools.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Glance
-keep class androidx.glance.** { *; }
