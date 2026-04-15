/**
 * MMI3G Snake Game
 * 
 * Console-based Snake that runs on the J9 JVM.
 * Output goes through the GEM script console (stdout -> script.fifo).
 * 
 * The GEM console is text-only, approximately 40 columns x 15 rows
 * on the 800x480 display with the engineering font.
 * 
 * Controls: The game auto-advances. Direction changes come from
 * the GEM's script input mechanism (or auto-play in demo mode).
 * 
 * Compile: javac -source 1.4 -target 1.4 Snake.java
 * Run:     j9 -Xbootclasspath:/lsd/lsd.jxe -cp . Snake
 */
import java.util.Random;

public class Snake {
    // Game board size (fits GEM console)
    static final int WIDTH = 30;
    static final int HEIGHT = 12;
    
    // Direction constants
    static final int UP = 0, RIGHT = 1, DOWN = 2, LEFT = 3;
    
    // Game state
    static int[] snakeX = new int[WIDTH * HEIGHT];
    static int[] snakeY = new int[WIDTH * HEIGHT];
    static int snakeLen = 3;
    static int dir = RIGHT;
    static int foodX, foodY;
    static int score = 0;
    static boolean gameOver = false;
    static Random rand = new Random();
    
    // Board
    static char[][] board = new char[HEIGHT][WIDTH];
    
    public static void main(String[] args) {
        System.out.println("================================");
        System.out.println("   SNAKE - MMI3G Edition");
        System.out.println("   Score: eat food (*)");
        System.out.println("   Auto-play demo mode");
        System.out.println("================================");
        
        try { Thread.sleep(2000); } catch (Exception e) {}
        
        initGame();
        
        while (!gameOver) {
            // Simple AI: chase the food
            autoPlay();
            
            moveSnake();
            drawBoard();
            
            try { Thread.sleep(200); } catch (Exception e) {}
        }
        
        System.out.println("");
        System.out.println("  GAME OVER!");
        System.out.println("  Final Score: " + score);
        System.out.println("  Snake Length: " + snakeLen);
        System.out.println("");
    }
    
    static void initGame() {
        // Place snake in center
        for (int i = 0; i < snakeLen; i++) {
            snakeX[i] = WIDTH / 2 - i;
            snakeY[i] = HEIGHT / 2;
        }
        placeFood();
    }
    
    static void placeFood() {
        do {
            foodX = rand.nextInt(WIDTH - 2) + 1;
            foodY = rand.nextInt(HEIGHT - 2) + 1;
        } while (isSnake(foodX, foodY));
    }
    
    static boolean isSnake(int x, int y) {
        for (int i = 0; i < snakeLen; i++) {
            if (snakeX[i] == x && snakeY[i] == y) return true;
        }
        return false;
    }
    
    static void autoPlay() {
        // Simple AI: try to move toward food, avoid walls and self
        int headX = snakeX[0];
        int headY = snakeY[0];
        
        // Preferred directions toward food
        int prefH = (foodX > headX) ? RIGHT : (foodX < headX) ? LEFT : dir;
        int prefV = (foodY > headY) ? DOWN : (foodY < headY) ? UP : dir;
        
        // Try preferred horizontal, then vertical, then any safe direction
        int[] tryDirs;
        if (rand.nextInt(3) > 0) {
            tryDirs = new int[]{prefH, prefV, UP, RIGHT, DOWN, LEFT};
        } else {
            tryDirs = new int[]{prefV, prefH, UP, RIGHT, DOWN, LEFT};
        }
        
        for (int i = 0; i < tryDirs.length; i++) {
            int d = tryDirs[i];
            // Don't reverse
            if ((d + 2) % 4 == dir) continue;
            
            int nx = headX + (d == RIGHT ? 1 : d == LEFT ? -1 : 0);
            int ny = headY + (d == DOWN ? 1 : d == UP ? -1 : 0);
            
            if (nx > 0 && nx < WIDTH - 1 && ny > 0 && ny < HEIGHT - 1 && !isSnake(nx, ny)) {
                dir = d;
                return;
            }
        }
    }
    
    static void moveSnake() {
        // Calculate new head position
        int newX = snakeX[0] + (dir == RIGHT ? 1 : dir == LEFT ? -1 : 0);
        int newY = snakeY[0] + (dir == DOWN ? 1 : dir == UP ? -1 : 0);
        
        // Check wall collision
        if (newX <= 0 || newX >= WIDTH - 1 || newY <= 0 || newY >= HEIGHT - 1) {
            gameOver = true;
            return;
        }
        
        // Check self collision
        if (isSnake(newX, newY)) {
            gameOver = true;
            return;
        }
        
        // Check food
        boolean ate = (newX == foodX && newY == foodY);
        
        // Move body
        if (!ate) {
            // Shift body, drop tail
            for (int i = snakeLen - 1; i > 0; i--) {
                snakeX[i] = snakeX[i - 1];
                snakeY[i] = snakeY[i - 1];
            }
        } else {
            // Grow: shift body but keep tail
            for (int i = snakeLen; i > 0; i--) {
                snakeX[i] = snakeX[i - 1];
                snakeY[i] = snakeY[i - 1];
            }
            snakeLen++;
            score += 10;
            placeFood();
        }
        
        snakeX[0] = newX;
        snakeY[0] = newY;
    }
    
    static void drawBoard() {
        StringBuffer sb = new StringBuffer();
        
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                if (y == 0 || y == HEIGHT - 1) {
                    sb.append('-');
                } else if (x == 0 || x == WIDTH - 1) {
                    sb.append('|');
                } else if (x == snakeX[0] && y == snakeY[0]) {
                    sb.append('@');  // Head
                } else if (isSnake(x, y)) {
                    sb.append('o');  // Body
                } else if (x == foodX && y == foodY) {
                    sb.append('*');  // Food
                } else {
                    sb.append(' ');
                }
            }
            sb.append('\n');
        }
        sb.append(" Score: " + score + "  Length: " + snakeLen + "\n");
        
        System.out.print(sb.toString());
    }
}
