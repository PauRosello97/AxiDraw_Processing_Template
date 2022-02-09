  /*
  AxiTurtle
 
  An easy way to program AxiDraw and preview your drawing.
  Including turtle graphics commands!
 
  Based on EvilMadScientist's AxiGen example, hiding it's complexity,
  but providing an easy (turtle graphics) programming interface.
 
  Turtle graphics commands are based on "Laser Turtle":
  https://forresto.github.io/turtle-svg/
 
    The turtle starts in the upper left corner facing right.
    Angles: 0 is right, 1/4 is up, 1/2 is left, 3/4 is down
 
    // Pen commands
    penUp();               // Shortcut u()
    penDown();             // d()
    
    // Relative move
    moveForward(distance); // f()
    
    // Relative turns
    turnRight(angle);      // r()
    turnLeft(angle);       // l()
    
    // Absolute turns
    turnTo(angle);         // t()
    
    // Angles for turn commands are 0.0 to 1.0
    turnRight(0.25);        // Turn right 90º
    turnLeft(1/360.0);       // Turn left 1º
    
    // SVG move (pen not drawing) and line (drawing)
    // Relative
    moveBy(x, y); 
    lineBy(x, y);
    // Absolute
    moveTo(x, y); 
    lineTo(x, y);
    line(x1, y1, x2, y2);
 
  Based on AxiGen (Generative art example with AxiDraw)
  https://github.com/evil-mad/AxiDraw-Processing
 
  Based RoboPaint RT: 
  https://github.com/evil-mad/robopaint-rt
*/

void setup() {
  // Don't change the following 2 lines of code:
  size(800, 631, P2D); // moved from AxiGen1 file. size() must be used in setup().
  setupAxiGen(); // call original setup() function in AxiGen1 file.
  
  //axiRect(100, 100, 200, 200);
  //axiRect(150, 150, 200, 200);
  for(int i=0; i<10; i++){
    for(int j = 0; j<10; j++){
      //axiPoint(300+ i*10, 300 + j*10);
    }
  }
  axiPoint(200, 200);

  moveTo(0, 0);
}

void axiRect(float x, float y, float w, float h){
  moveTo(x, y);
  lineTo(x+w, y);
  lineTo(x+w, y+h);
  lineTo(x, y+h);
  lineTo(x, y);
}

void axiPoint(float x, float y){
  moveTo(x, y);
  penDown();
  penUp();
}

void axiLine(float x1, float y1, float x2, float y2){
  moveTo(x1, y1);
  lineTo(x2, y2);
}

void draw() {
  //Don't change the following line of code:
  background(255);
  drawAxiGen(); // call original draw() function in AxiGen1 file.
  
}
