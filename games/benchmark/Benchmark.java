public class Benchmark {
    public static void main(String[] args) {
        System.out.println("============================================");
        System.out.println("  MMI3G J9 JVM Benchmark");
        System.out.println("============================================");
        System.out.println("");
        
        // System info
        Runtime rt = Runtime.getRuntime();
        System.out.println("JVM Info:");
        System.out.println("  Free Memory:  " + (rt.freeMemory() / 1024) + " KB");
        System.out.println("  Total Memory: " + (rt.totalMemory() / 1024) + " KB");
        System.out.println("  Max Memory:   " + (rt.maxMemory() / 1024) + " KB");
        System.out.println("  Processors:   " + rt.availableProcessors());
        System.out.println("");
        
        // CPU benchmark — integer math
        System.out.println("CPU Benchmark:");
        long start = System.currentTimeMillis();
        long sum = 0;
        for (int i = 0; i < 1000000; i++) {
            sum += i * i;
        }
        long intTime = System.currentTimeMillis() - start;
        System.out.println("  Integer (1M ops):  " + intTime + " ms");
        
        // String operations
        start = System.currentTimeMillis();
        String s = "";
        for (int i = 0; i < 10000; i++) {
            s = "test" + i;
        }
        long strTime = System.currentTimeMillis() - start;
        System.out.println("  String (10K ops):  " + strTime + " ms");
        
        // Array operations
        start = System.currentTimeMillis();
        int[] arr = new int[100000];
        for (int i = 0; i < arr.length; i++) arr[i] = i;
        for (int i = 0; i < arr.length - 1; i++) arr[i] = arr[i] + arr[i+1];
        long arrTime = System.currentTimeMillis() - start;
        System.out.println("  Array (100K ops):  " + arrTime + " ms");
        
        // Memory after benchmark
        rt.gc();
        System.out.println("");
        System.out.println("Post-benchmark Memory:");
        System.out.println("  Free:  " + (rt.freeMemory() / 1024) + " KB");
        System.out.println("  Used:  " + ((rt.totalMemory() - rt.freeMemory()) / 1024) + " KB");
        
        System.out.println("");
        System.out.println("============================================");
        System.out.println("  Total: " + (intTime + strTime + arrTime) + " ms");
        System.out.println("  J9 is ALIVE on your MMI!");
        System.out.println("============================================");
    }
}
