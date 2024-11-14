# Mantener recursos GLB si fuera necesario
-keepclassmembers class **.R$raw {
    public static final int *;
}
