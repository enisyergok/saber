-dontwarn javax.lang.model.element.Modifier
# Libraries that extend java.util.Random guard setSeed with a flag set after super();
# keep them as written.
-keep class * extends java.util.Random { *; }
