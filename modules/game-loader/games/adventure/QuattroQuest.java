/**
 * MMI3G Text Adventure - "The Quattro Quest"
 * 
 * An Audi-themed text adventure game for the GEM console.
 * Perfect for the MMI because text adventures only need
 * text output (stdout) and the game auto-advances through
 * choices since we can't easily read input from GEM.
 * 
 * This runs as a demo/story mode. A full version could
 * use GEM script buttons for choices.
 * 
 * Compile: javac -source 1.4 -target 1.4 QuattroQuest.java
 */
public class QuattroQuest {
    
    static int fuel = 100;
    static int boost = 0;
    static int distance = 0;
    static int score = 0;
    static String car = "Audi A6 3.0T";
    
    public static void main(String[] args) {
        intro();
        sleep(3000);
        
        chapter1();
        chapter2();
        chapter3();
        
        ending();
    }
    
    static void intro() {
        cls();
        println("========================================");
        println("       THE QUATTRO QUEST");
        println("     An MMI3G Text Adventure");
        println("========================================");
        println("");
        println("Your " + car + " sits in the");
        println("driveway, supercharger whining softly");
        println("at idle. The MMI screen glows green —");
        println("someone has activated the Engineering");
        println("Menu. A message appears:");
        println("");
        println("  'HIDDEN ROUTE UNLOCKED'");
        println("  'DESTINATION: THE NURBURGRING'");
        println("");
        println("Do you accept the challenge?");
        println("(Of course you do. You have Quattro.)");
    }
    
    static void chapter1() {
        cls();
        println("========================================");
        println("  CHAPTER 1: The Autobahn");
        println("========================================");
        println("");
        println("You merge onto the A3 heading south.");
        println("The speed limit signs end.");
        println("The supercharger spools up.");
        println("");
        sleep(2000);
        
        println("Your " + car + " surges forward.");
        println("The MMI shows GPS speed climbing...");
        println("");
        
        for (int speed = 120; speed <= 250; speed += 10) {
            fuel -= 2;
            distance += 5;
            boost = (speed > 180) ? (speed - 180) / 10 : 0;
            
            StringBuffer bar = new StringBuffer("[");
            int bars = speed / 25;
            for (int i = 0; i < 10; i++) {
                bar.append(i < bars ? '#' : ' ');
            }
            bar.append("] " + speed + " km/h");
            if (boost > 0) bar.append("  BOOST: " + boost + " PSI");
            println("  " + bar.toString());
            sleep(300);
        }
        
        println("");
        println("A blue BMW appears in your mirror.");
        println("It flashes its lights.");
        println("You move right. It passes.");
        println("Then you pass it back. Naturally.");
        score += 100;
        println("");
        println("  +100 points (Quattro supremacy)");
        sleep(2000);
    }
    
    static void chapter2() {
        cls();
        println("========================================");
        println("  CHAPTER 2: The Twisty Bits");
        println("========================================");
        println("");
        println("You exit the Autobahn onto B258.");
        println("The road winds through the Eifel.");
        println("Fog rolls across the pavement.");
        println("");
        sleep(2000);
        
        String[] turns = {
            "Sharp left bend — Quattro grips!",
            "Downhill hairpin — brakes hold firm",
            "S-curve through forest — smooth",
            "Wet cobblestone village — no drama",
            "Steep uphill — supercharger pulls",
            "Blind crest — committed!",
            "Roundabout — wrong exit, recalculating...",
            "Narrow bridge — mirrors folded just in time"
        };
        
        for (int i = 0; i < turns.length; i++) {
            fuel -= 3;
            distance += 2;
            score += 25;
            println("  [Turn " + (i+1) + "] " + turns[i]);
            sleep(800);
        }
        
        println("");
        println("  Distance: " + distance + " km");
        println("  Fuel: " + fuel + "%");
        println("  Score: " + score);
        sleep(2000);
    }
    
    static void chapter3() {
        cls();
        println("========================================");
        println("  CHAPTER 3: The Ring");
        println("========================================");
        println("");
        println("The Nurburgring toll gate appears.");
        println("You pay the tourist fee.");
        println("The barrier lifts.");
        println("");
        sleep(2000);
        println("20.832 km of legend ahead of you.");
        println("");
        
        String[] sections = {
            "T1  Nordkehre        | easy    | 80 km/h",
            "T2  Hatzenbach       | medium  | 140 km/h",
            "T3  Flugplatz        | JUMP!   | 180 km/h",
            "T4  Schwedenkreuz    | flat out| 220 km/h",
            "T5  Adenauer Forst   | tight   | 90 km/h",
            "T6  Karussell        | banked! | 100 km/h",
            "T7  Brunnchen        | fast    | 200 km/h",
            "T8  Pflanzgarten     | JUMP!   | 190 km/h",
            "T9  Schwalbenschwanz | tricky  | 110 km/h",
            "T10 Galgenkopf       | final   | 160 km/h"
        };
        
        for (int i = 0; i < sections.length; i++) {
            fuel -= 5;
            score += 50;
            println("  " + sections[i]);
            
            // Random events
            if (i == 2 || i == 7) {
                println("    >>> ALL FOUR WHEELS AIRBORNE <<<");
                score += 100;
            }
            if (i == 5) {
                println("    >>> PERFECT KARUSSELL LINE <<<");
                score += 200;
            }
            
            sleep(600);
        }
        
        println("");
        println("  LAP COMPLETE!");
        score += 500;
    }
    
    static void ending() {
        cls();
        println("========================================");
        println("  THE QUATTRO QUEST - COMPLETE!");
        println("========================================");
        println("");
        println("  Car:      " + car);
        println("  Distance: " + distance + " km");
        println("  Fuel:     " + fuel + "%");
        println("  Score:    " + score + " points");
        println("");
        
        String rank;
        if (score > 2000) rank = "QUATTRO MASTER";
        else if (score > 1500) rank = "Ring Veteran";
        else if (score > 1000) rank = "Sunday Driver";
        else rank = "Tourist";
        
        println("  Rank:     " + rank);
        println("");
        println("  Your MMI screen returns to normal.");
        println("  But the Ring will call you back.");
        println("  It always does.");
        println("");
        println("========================================");
        println("  github.com/dspl1236/MMI3G-Toolkit");
        println("========================================");
    }
    
    static void println(String s) {
        System.out.println(s);
    }
    
    static void cls() {
        // GEM console doesn't support ANSI clear
        // Just print blank lines to push old content up
        for (int i = 0; i < 3; i++) println("");
    }
    
    static void sleep(int ms) {
        try { Thread.sleep(ms); } catch (Exception e) {}
    }
}
