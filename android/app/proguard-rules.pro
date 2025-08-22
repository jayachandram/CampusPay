# Razorpay SDK keep rules
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Keep annotations
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
