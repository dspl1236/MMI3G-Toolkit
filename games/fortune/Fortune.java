import java.util.Random;

public class Fortune {
    static String[] fortunes = {
        "Your Audi knows more about you than you think.",
        "The check engine light brings wisdom, not fear.",
        "A journey of a thousand miles begins with 'recalculating'.",
        "Today is a good day to change your oil.",
        "The one who reads the owner's manual finds enlightenment.",
        "Patience — the navigation is still loading.",
        "Your parking karma is strong today.",
        "The road less traveled has no speed cameras.",
        "A clean car is a happy car. Wash me.",
        "Four rings, infinite possibilities.",
        "The turbo whispers: 'full boost ahead'.",
        "An engineer's touch lives in every line of code.",
        "QNX never crashes. It just meditates.",
        "The GEM reveals what Audi hides.",
        "He who hacks the MMI inherits the dashboard.",
        "SH4 at 792MHz — more power than Apollo 11.",
        "In the land of CAN bus, every message matters.",
        "Your FSC code is your destiny.",
        "The wifi chip sleeps, but dreams of packets.",
        "DOOM runs everywhere. Even here."
    };
    
    public static void main(String[] args) {
        Random rng = new Random(System.currentTimeMillis());
        int idx = rng.nextInt(fortunes.length);
        
        System.out.println("");
        System.out.println("  +-----------------------------------------+");
        System.out.println("  |         MMI3G Fortune Cookie             |");
        System.out.println("  +-----------------------------------------+");
        System.out.println("");
        System.out.println("    " + fortunes[idx]);
        System.out.println("");
        System.out.println("  +-----------------------------------------+");
        System.out.println("    Lucky numbers: " + 
            rng.nextInt(42) + " " + rng.nextInt(42) + " " + 
            rng.nextInt(42) + " " + rng.nextInt(42));
        System.out.println("  +-----------------------------------------+");
        System.out.println("");
    }
}
